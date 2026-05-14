import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        if let user = appModel.sessionStore.user {
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 72))
                                    .foregroundStyle(TehefTheme.accent)
                                Text(user.displayName)
                                    .font(.title2.weight(.bold))
                                Text(user.email)
                                    .foregroundStyle(.secondary)
                                Text(user.role.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .glassCapsule()
                            }
                            .frame(maxWidth: .infinity)
                            .glassCard(cornerRadius: 24)

                            if let location = user.location, !location.isEmpty {
                                GlassSection(title: "Location") {
                                    Text(location)
                                }
                            }

                            if let bio = user.bio, !bio.isEmpty {
                                GlassSection(title: "Bio") {
                                    Text(bio)
                                }
                            }

                            Button("Sign out") {
                                appModel.sessionStore.logout()
                            }
                            .buttonStyle(GlassSecondaryButtonStyle())
                        } else {
                            VStack(spacing: 12) {
                                Text("Sign in to view your profile")
                                    .font(.headline)
                                Text("Your account details, settings, and verification status will appear here.")
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                            }
                            .glassCard(cornerRadius: 24)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
        }
    }
}
