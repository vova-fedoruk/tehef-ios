import AVFoundation
import AVKit
import SwiftUI

struct TehefVideoMessageView: View {
    let urlString: String

    var body: some View {
        Group {
            if let url = TehefMediaURL.resolve(urlString) {
                VideoPlayer(player: AVPlayer(url: url))
            } else {
                TehefTheme.muted
                    .overlay {
                        Image(systemName: "video.slash")
                            .foregroundStyle(TehefTheme.mutedForeground)
                    }
            }
        }
        .frame(maxWidth: 260, maxHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@MainActor
@Observable
final class TehefVoiceMessagePlayerModel {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?

    let urlString: String
    var isPlaying = false
    var isPreparing = false
    var isReady = false
    var duration: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var fileSizeLabel = ""
    var playbackRate: Float = 1
    var waveform: [CGFloat] = []
    var errorMessage: String?

    init(urlString: String) {
        self.urlString = urlString
        waveform = Self.makeWaveform(seed: urlString, count: 28)
    }

    func prepare() async {
        guard player == nil else { return }
        guard let url = TehefMediaURL.resolve(urlString) else {
            errorMessage = "Voice message is unavailable."
            return
        }

        isPreparing = true
        errorMessage = nil
        defer { isPreparing = false }

        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        if !playable {
            errorMessage = "This voice message format is not supported on iOS."
            return
        }

        if let loadedDuration = try? await asset.load(.duration) {
            duration = max(loadedDuration.seconds, 0)
            isReady = loadedDuration.seconds.isFinite && loadedDuration.seconds > 0
        }

        await loadFileSize(for: url)

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = false
        player.volume = 1
        self.playerItem = item
        self.player = player

        statusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard let self else { return }
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    self.isReady = true
                    if self.duration <= 0, item.duration.seconds.isFinite, item.duration.seconds > 0 {
                        self.duration = item.duration.seconds
                    }
                case .failed:
                    self.errorMessage = item.error?.localizedDescription ?? "Could not load voice message."
                    self.isReady = false
                default:
                    break
                }
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = max(time.seconds, 0)
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.isPlaying = false
                self.currentTime = 0
                self.player?.seek(to: .zero)
            }
        }

        await waitUntilReady(timeout: 8)
    }

    func togglePlayback() async {
        if player == nil {
            await prepare()
            guard player != nil else { return }
        }

        guard let player else { return }

        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }

        Self.stopOthers(except: self)
        activatePlaybackSession()

        if !isReady {
            await waitUntilReady(timeout: 4)
        }

        guard isReady else {
            errorMessage = errorMessage ?? "Voice message is still loading."
            return
        }

        if duration <= 0, let itemDuration = player.currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }

        player.play()
        player.rate = playbackRate
        isPlaying = player.rate > 0
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func cycleSpeed() {
        switch playbackRate {
        case 1: playbackRate = 1.5
        case 1.5: playbackRate = 2
        default: playbackRate = 1
        }
        if isPlaying {
            player?.rate = playbackRate
        }
    }

    func seek(to progress: CGFloat) {
        guard duration > 0 else { return }
        let time = duration * Double(progress)
        currentTime = time
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func cleanup() {
        pause()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObserver?.invalidate()
        player = nil
        playerItem = nil
        if Self.activePlayer === self {
            Self.activePlayer = nil
        }
    }

    private func waitUntilReady(timeout: TimeInterval) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isReady || errorMessage != nil {
                return
            }
            if playerItem?.status == .failed {
                errorMessage = playerItem?.error?.localizedDescription ?? "Could not load voice message."
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
    }

    private func activatePlaybackSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static weak var activePlayer: TehefVoiceMessagePlayerModel?

    private static func stopOthers(except current: TehefVoiceMessagePlayerModel) {
        if let activePlayer, activePlayer !== current {
            activePlayer.pause()
        }
        activePlayer = current
    }

    private func loadFileSize(for url: URL) async {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              let length = http.value(forHTTPHeaderField: "Content-Length"),
              let bytes = Int64(length) else {
            return
        }
        fileSizeLabel = Self.formatFileSize(bytes)
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }

    private static func makeWaveform(seed: String, count: Int) -> [CGFloat] {
        var hash = seed.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
        return (0..<count).map { index in
            hash = (hash &* 33) &+ index
            let value = abs(hash % 100)
            return CGFloat(0.22 + Double(value) / 100 * 0.72)
        }
    }
}

struct TehefAudioMessageView: View {
    let messageID: Int
    let urlString: String
    let isMine: Bool

    @State private var model: TehefVoiceMessagePlayerModel?

    var body: some View {
        Group {
            if let model {
                TehefVoiceMessageBubble(model: model, isMine: isMine)
            } else {
                TehefVoiceMessageBubblePlaceholder(isMine: isMine)
            }
        }
        .task(id: messageID) {
            let playerModel = TehefVoiceMessagePlayerModel(urlString: urlString)
            model = playerModel
            await playerModel.prepare()
        }
        .onDisappear {
            model?.pause()
        }
    }
}

private struct TehefVoiceMessageBubblePlaceholder: View {
    let isMine: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isMine ? Color.white.opacity(0.25) : TehefTheme.accent.opacity(0.15))
                .frame(width: 42, height: 42)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isMine ? Color.white.opacity(0.18) : TehefTheme.muted)
                .frame(height: 28)
        }
        .frame(minWidth: 220, maxWidth: 280)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bubbleColor: Color {
        isMine ? TehefTheme.accent.opacity(0.92) : Color(red: 0.93, green: 0.96, blue: 0.98)
    }
}

private struct TehefVoiceMessageBubble: View {
    @Bindable var model: TehefVoiceMessagePlayerModel
    let isMine: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                Task { await model.togglePlayback() }
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isMine ? TehefTheme.accent : .white)
                    .frame(width: 42, height: 42)
                    .background(
                        isMine ? Color.white : TehefTheme.accent,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .disabled(model.isPreparing)

            VStack(alignment: .leading, spacing: 6) {
                TehefVoiceWaveform(
                    samples: model.waveform,
                    progress: progress,
                    isMine: isMine,
                    onSeek: model.seek(to:)
                )
                .frame(height: 28)

                HStack(spacing: 8) {
                    Text(metadataLabel)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(isMine ? Color.white.opacity(0.86) : TehefTheme.mutedForeground)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button(action: model.cycleSpeed) {
                        Text(speedLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isMine ? .white : TehefTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                isMine ? Color.white.opacity(0.18) : TehefTheme.accent.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 220, maxWidth: 280)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

        if let errorMessage = model.errorMessage {
            Text(errorMessage)
                .font(.caption2)
                .foregroundStyle(TehefTheme.destructive)
                .padding(.top, 4)
        }
    }

    private var bubbleColor: Color {
        isMine ? TehefTheme.accent.opacity(0.92) : Color(red: 0.93, green: 0.96, blue: 0.98)
    }

    private var progress: CGFloat {
        guard model.duration > 0 else { return 0 }
        return CGFloat(min(max(model.currentTime / model.duration, 0), 1))
    }

    private var metadataLabel: String {
        if model.isPreparing {
            return "Loading..."
        }
        let duration = formattedDuration(model.duration > 0 ? model.duration : model.currentTime)
        if model.fileSizeLabel.isEmpty {
            return duration
        }
        return "\(duration), \(model.fileSizeLabel)"
    }

    private var speedLabel: String {
        switch model.playbackRate {
        case 1.5: return "1.5x"
        case 2: return "2x"
        default: return "1x"
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct TehefVoiceWaveform: View {
    let samples: [CGFloat]
    let progress: CGFloat
    let isMine: Bool
    let onSeek: (CGFloat) -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                    let barProgress = CGFloat(index + 1) / CGFloat(max(samples.count, 1))
                    Capsule()
                        .fill(barColor(for: barProgress))
                        .frame(
                            width: max((geometry.size.width - CGFloat(samples.count - 1) * 2) / CGFloat(samples.count), 2),
                            height: max(4, geometry.size.height * sample)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        let fraction = min(max(value.location.x / max(geometry.size.width, 1), 0), 1)
                        onSeek(fraction)
                    }
            )
            .onTapGesture {
                onSeek(progress)
            }
        }
    }

    private func barColor(for barProgress: CGFloat) -> Color {
        let played = barProgress <= progress
        if isMine {
            return played ? Color.white : Color.white.opacity(0.35)
        }
        return played ? TehefTheme.accent : Color(red: 0.77, green: 0.80, blue: 0.84)
    }
}
