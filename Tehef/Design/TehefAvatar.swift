import SwiftUI

struct TehefAvatarView: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let urlString, TehefMediaURL.resolve(urlString) != nil {
                TehefRemoteImage(
                    urlString: urlString,
                    cornerRadius: size / 2,
                    showsBorder: false
                )
            } else {
                Circle()
                    .fill(TehefTheme.primary.opacity(0.12))
                    .overlay {
                        Text(initials)
                            .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                            .foregroundStyle(TehefTheme.primary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(TehefTheme.border.opacity(0.55), lineWidth: 1)
        }
    }

    private var initials: String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        if parts.isEmpty {
            return "?"
        }
        return String(parts).uppercased()
    }
}
