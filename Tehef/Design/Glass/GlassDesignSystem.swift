import SwiftUI

enum TehefTheme {
    static let accent = Color(red: 0.10, green: 0.52, blue: 0.98)
    static let secondaryAccent = Color(red: 0.20, green: 0.78, blue: 0.72)
    static let backgroundTop = Color(red: 0.93, green: 0.96, blue: 1.0)
    static let backgroundBottom = Color(red: 0.86, green: 0.92, blue: 0.99)
}

struct GlassBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [TehefTheme.backgroundTop, TehefTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [TehefTheme.accent.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .overlay {
            RadialGradient(
                colors: [TehefTheme.secondaryAccent.opacity(0.14), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func glassCapsule() -> some View {
        glassEffect(.regular.interactive(), in: .capsule)
    }
}

struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
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
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
    }
}

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(TehefTheme.accent.gradient, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct GlassSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(.regular.interactive(), in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
