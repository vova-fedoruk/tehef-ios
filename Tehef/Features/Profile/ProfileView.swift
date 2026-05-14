import SwiftUI

private enum ProfileRoute: Hashable {
    case editProfile
    case createTask
}

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                VStack(spacing: 0) {
                    TehefAppHeader(title: "Profile")
                    ScrollView {
                        VStack(spacing: 16) {
                            if let user = appModel.sessionStore.user {
                                VStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 72))
                                        .foregroundStyle(TehefTheme.primary)
                                    Text(user.displayName)
                                        .font(.system(.title2, design: .rounded, weight: .bold))
                                        .foregroundStyle(TehefTheme.foreground)
                                    Text(user.email)
                                        .foregroundStyle(TehefTheme.mutedForeground)
                                    TehefBadge(text: user.role.capitalized, tint: TehefTheme.accent)
                                }
                                .frame(maxWidth: .infinity)
                                .glassCard(cornerRadius: 24)

                                if let location = user.location, !location.displayLabel.isEmpty {
                                    GlassSection(title: "Location", icon: "mappin.and.ellipse") {
                                        Text(location.displayLabel)
                                    }
                                }

                                if let bio = user.bio, !bio.isEmpty {
                                    GlassSection(title: "Bio", icon: "text.quote") {
                                        Text(bio)
                                    }
                                }

                                VStack(spacing: 10) {
                                    NavigationLink(value: TaskHubKind.mine) {
                                        TehefMenuRow(
                                            title: "My tasks",
                                            subtitle: "Tasks you posted and manage.",
                                            systemImage: "tray.full.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: TaskHubKind.applied) {
                                        TehefMenuRow(
                                            title: "Applied tasks",
                                            subtitle: "Tasks where you submitted a proposal.",
                                            systemImage: "paperplane.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: TaskHubKind.liked) {
                                        TehefMenuRow(
                                            title: "Liked tasks",
                                            subtitle: "Tasks you saved for later.",
                                            systemImage: "heart.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: ProfileRoute.createTask) {
                                        TehefMenuRow(
                                            title: "Post a task",
                                            subtitle: "Create a new request for providers.",
                                            systemImage: "plus.circle.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    NavigationLink(value: ProfileRoute.editProfile) {
                                        TehefMenuRow(
                                            title: "Edit profile",
                                            subtitle: "Update your contact details and bio.",
                                            systemImage: "pencil.circle.fill"
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button("Sign out") {
                                    appModel.sessionStore.logout()
                                }
                                .buttonStyle(GlassSecondaryButtonStyle())
                            } else {
                                VStack(spacing: 16) {
                                    Text("Sign in to manage your account")
                                        .font(.headline)
                                        .foregroundStyle(TehefTheme.foreground)
                                    Text("You can browse tasks without an account. Sign in when you want to apply, chat, or post work.")
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(TehefTheme.mutedForeground)

                                    Button("Sign in") {
                                        appModel.openAuth()
                                    }
                                    .buttonStyle(GlassPrimaryButtonStyle())

                                    Button("Create account") {
                                        appModel.openAuth(signUp: true)
                                    }
                                    .buttonStyle(GlassSecondaryButtonStyle())
                                }
                                .glassCard(cornerRadius: 24)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: TaskHubKind.self) { kind in
                TaskHubView(kind: kind)
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .editProfile:
                    ProfileEditView()
                case .createTask:
                    TaskCreateView()
                }
            }
        }
    }
}
