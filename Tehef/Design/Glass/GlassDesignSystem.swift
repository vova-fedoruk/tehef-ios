import SwiftUI

enum TehefTheme {
    static let primary = Color(red: 1.0, green: 0.353, blue: 0.314)
    static let primaryForeground = Color.white
    static let secondary = Color(red: 0.278, green: 0.290, blue: 0.318)
    static let foreground = Color(red: 0.278, green: 0.290, blue: 0.318)
    static let muted = Color(red: 0.988, green: 0.965, blue: 0.961)
    static let mutedForeground = Color(red: 0.420, green: 0.431, blue: 0.451)
    static let accent = Color(red: 0.161, green: 0.753, blue: 0.847)
    static let accentSoft = Color(red: 0.161, green: 0.753, blue: 0.847).opacity(0.12)
    static let background = Color.white
    static let card = Color.white
    static let border = Color(red: 0.867, green: 0.871, blue: 0.886)
    static let destructive = Color(red: 0.820, green: 0.200, blue: 0.200)

    static let radiusLarge: CGFloat = 16
    static let radiusMedium: CGFloat = 12
    static let radiusSmall: CGFloat = 8
}

struct GlassBackdrop: View {
    var body: some View {
        TehefTheme.background
            .overlay {
                RadialGradient(
                    colors: [TehefTheme.primary.opacity(0.10), .clear],
                    center: UnitPoint(x: 0.2, y: 0.0),
                    startRadius: 20,
                    endRadius: 520
                )
            }
            .overlay {
                RadialGradient(
                    colors: [TehefTheme.primary.opacity(0.08), .clear],
                    center: UnitPoint(x: 1.0, y: 0.2),
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .overlay {
                LinearGradient(
                    colors: [TehefTheme.background, TehefTheme.muted.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = TehefTheme.radiusLarge
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(TehefTheme.card.opacity(0.82), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(TehefTheme.border.opacity(0.55), lineWidth: 1)
            }
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func tehefHeadline() -> some View {
        font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(TehefTheme.foreground)
    }

    func tehefBody() -> some View {
        font(.body)
            .foregroundStyle(TehefTheme.foreground)
    }

    func tehefMuted() -> some View {
        foregroundStyle(TehefTheme.mutedForeground)
    }

    func glassCard(cornerRadius: CGFloat = TehefTheme.radiusLarge, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func glassCapsule() -> some View {
        glassEffect(.regular.interactive(), in: .capsule)
    }

    func tehefField() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(TehefTheme.background.opacity(0.72), in: RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TehefTheme.radiusMedium, style: .continuous)
                    .stroke(TehefTheme.border, lineWidth: 1)
            }
    }
}

struct GlassSection<Content: View>: View {
    let title: String
    var icon: String?
    var iconColor: Color = TehefTheme.primary
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                }
                Text(title)
                    .tehefHeadline()
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TehefTheme.mutedForeground)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TehefTheme.background.opacity(0.72), in: Capsule())
        .overlay {
            Capsule()
                .stroke(TehefTheme.border, lineWidth: 1)
        }
        .glassEffect(.regular, in: .capsule)
    }
}

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(TehefTheme.primaryForeground)
            .background(TehefTheme.primary.opacity(configuration.isPressed ? 0.9 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(TehefTheme.foreground)
            .background(TehefTheme.background.opacity(0.72), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(TehefTheme.border.opacity(0.8), lineWidth: 1)
            }
            .glassEffect(.regular.interactive(), in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct TehefBadge: View {
    let text: String
    var tint: Color = TehefTheme.accent

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: Capsule())
    }
}
