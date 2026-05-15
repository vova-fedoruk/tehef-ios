import SwiftUI
import UIKit

@MainActor
final class TehefImageCache {
    static let shared = TehefImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private let session: URLSession

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("TehefImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 200
        memory.totalCostLimit = 64 * 1024 * 1024
        session = TehefURLSessionFactory.makeShared()
    }

    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)
        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }

        let fileURL = fileURL(forKey: key)
        if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString, cost: data.count)
            return image
        }

        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: key as NSString, cost: data.count)
            try? data.write(to: fileURL, options: .atomic)
            return image
        } catch {
            return nil
        }
    }

    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func cacheKey(for url: URL) -> String {
        url.absoluteString
    }

    private func fileURL(forKey key: String) -> URL {
        let hash = key.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-") ?? UUID().uuidString
        return directory.appendingPathComponent(hash)
    }
}

struct TehefCachedRemoteImage: View {
    let urlString: String?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = TehefTheme.radiusMedium
    var showsBorder = true

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                styled(Image(uiImage: image))
            } else if urlString != nil {
                ProgressView()
                    .tint(TehefTheme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .overlay {
            if showsBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TehefTheme.border.opacity(0.45), lineWidth: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: urlString) {
            await load()
        }
    }

    @ViewBuilder
    private func styled(_ image: Image) -> some View {
        switch contentMode {
        case .fit:
            image.resizable().scaledToFit()
        case .fill:
            image.resizable().scaledToFill()
        @unknown default:
            image.resizable().scaledToFill()
        }
    }

    private var placeholder: some View {
        TehefTheme.muted
            .overlay {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(TehefTheme.mutedForeground)
            }
    }

    private func load() async {
        guard let url = TehefMediaURL.resolve(urlString) else {
            image = nil
            return
        }
        image = await TehefImageCache.shared.image(for: url)
    }
}
