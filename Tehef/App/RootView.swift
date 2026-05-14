import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isBootstrapping = true

    var body: some View {
        Group {
            if isBootstrapping {
                LaunchView()
            } else {
                MainTabView()
            }
        }
        .sheet(isPresented: Binding(
            get: { appModel.showAuthSheet },
            set: { appModel.showAuthSheet = $0 }
        )) {
            AuthFlowView(startsInSignUp: appModel.authStartsInSignUp)
        }
        .task {
            await appModel.sessionStore.bootstrap()
            isBootstrapping = false
        }
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(TehefTheme.primary)
                Text("tehef")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(TehefTheme.foreground)
                ProgressView()
                    .tint(TehefTheme.primary)
            }
            .padding(32)
            .glassCard(cornerRadius: 24)
            .padding(.horizontal, 28)
        }
    }
}
