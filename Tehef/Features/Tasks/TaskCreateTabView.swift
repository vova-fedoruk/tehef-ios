import SwiftUI

struct TaskCreateTabView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                if appModel.isAuthenticated {
                    TaskCreateView()
                } else {
                    VStack(spacing: 0) {
                        TehefAppHeader(title: "Post")
                        VStack(spacing: 16) {
                            Text("Sign in to post a task")
                                .font(.headline)
                                .foregroundStyle(TehefTheme.foreground)
                            Text("Browse tasks freely, then sign in when you are ready to post work.")
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TehefTheme.mutedForeground)

                            Button("Sign in") {
                                appModel.openAuth()
                            }
                            .buttonStyle(GlassPrimaryButtonStyle())
                        }
                        .glassCard(cornerRadius: 24)
                        .padding(20)
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
}
