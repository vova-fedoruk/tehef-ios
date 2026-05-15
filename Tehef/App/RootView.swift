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
        .onOpenURL { url in
            Task {
                await appModel.handleOAuthRedirect(url)
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
            ZStack {
                Image("TehefFavicon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                ProgressView()
                    .tint(TehefTheme.primary)
                    .offset(y: 52)
            }
            .padding(32)
            .glassCard(cornerRadius: 24)
            .padding(.horizontal, 28)
        }
    }
}
