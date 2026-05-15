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
        TehefCachedRemoteImage(
            urlString: urlString,
            contentMode: contentMode,
            cornerRadius: cornerRadius,
            showsBorder: showsBorder
        )
    }
}
