import SwiftUI

enum TehefMediaURL {
    static func resolve(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }

        if trimmed.hasPrefix("//") {
            return URL(string: "https:\(trimmed)")
        }

        let base = APIEnvironment.baseURL
        if trimmed.hasPrefix("/") {
            return URL(string: trimmed, relativeTo: base)?.absoluteURL
        }

        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }
}

struct TehefRemoteImage: View {
    let urlString: String?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = TehefTheme.radiusMedium
    var showsBorder = true

    var body: some View {
        Group {
            if let url = TehefMediaURL.resolve(urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        remoteImage(image)
                    case .failure:
                        placeholder
                    default:
                        ProgressView()
                            .tint(TehefTheme.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
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
    }

    @ViewBuilder
    private func remoteImage(_ image: Image) -> some View {
        switch contentMode {
        case .fit:
            image
                .resizable()
                .scaledToFit()
        case .fill:
            image
                .resizable()
                .scaledToFill()
        @unknown default:
            image
                .resizable()
                .scaledToFill()
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
}
