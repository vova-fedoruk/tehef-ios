import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isBootstrapping = true

    var body: some View {
        Group {
            if isBootstrapping {
                LaunchView()
            } else if appModel.isAuthenticated {
                MainTabView()
            } else {
                AuthFlowView()
            }
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
                    .foregroundStyle(TehefTheme.accent)
                Text("tehef")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                ProgressView()
            }
            .padding(32)
            .glassCard(cornerRadius: 28)
            .padding(.horizontal, 28)
        }
    }
}
