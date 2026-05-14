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

struct TehefAudioMessageView: View {
    let urlString: String
    let isMine: Bool

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.headline)
                Text("Voice message")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isMine ? .white : TehefTheme.foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func togglePlayback() {
        guard let url = TehefMediaURL.resolve(urlString) else { return }
        if player == nil {
            player = AVPlayer(url: url)
        }
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.play()
            isPlaying = true
        }
    }
}
