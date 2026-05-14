import SwiftUI

enum TaskStatusStyle {
    static func label(for status: String) -> String {
        switch status {
        case "open": return "Open"
        case "assigned": return "Assigned"
        case "in_progress": return "In progress"
        case "pending_completion": return "Pending completion"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "disputed": return "Disputed"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    static func tint(for status: String) -> Color {
        switch status {
        case "open", "assigned":
            return TehefTheme.accent
        case "in_progress":
            return .orange
        case "pending_completion":
            return .purple
        case "completed":
            return TehefTheme.secondary
        case "cancelled", "disputed":
            return TehefTheme.primary
        default:
            return TehefTheme.mutedForeground
        }
    }
}

struct TaskStatusBadge: View {
    let status: String

    var body: some View {
        TehefBadge(text: TaskStatusStyle.label(for: status), tint: TaskStatusStyle.tint(for: status))
    }
}

struct TehefScreenContainer<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 0) {
                TehefAppHeader(title: title)
                content
            }
        }
        .navigationBarHidden(true)
    }
}

struct TehefFormSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .tehefHeadline()
            content
        }
        .glassCard()
    }
}

struct TehefTextField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TehefTheme.foreground)
            if axis == .vertical {
                TextField(title, text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .tehefField()
            } else {
                TextField(title, text: $text)
                    .tehefField()
            }
        }
    }
}

struct TehefMenuRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    init(title: String, subtitle: String? = nil, systemImage: String) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TehefTheme.primary)
                .frame(width: 36, height: 36)
                .background(TehefTheme.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(TehefTheme.foreground)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TehefTheme.mutedForeground)
        }
        .padding(14)
        .background(TehefTheme.card.opacity(0.82), in: RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous)
                .stroke(TehefTheme.border.opacity(0.55), lineWidth: 1)
        }
    }
}
