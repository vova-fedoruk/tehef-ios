import SwiftUI

struct ProfileSecurityView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        TehefScreenContainer(title: "Security") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Change your password")
                        .font(.subheadline)
                        .foregroundStyle(TehefTheme.mutedForeground)

                    TehefTextField(title: "Current password", text: $currentPassword)
                    SecureField("New password", text: $newPassword)
                        .tehefField()
                    SecureField("Confirm new password", text: $confirmPassword)
                        .tehefField()

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(isError ? TehefTheme.destructive : TehefTheme.accent)
                    }

                    Button(isSubmitting ? "Saving..." : "Update password") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(isSubmitting || !canSubmit)
                }
                .glassCard(cornerRadius: 24)
                .padding(20)
            }
        }
    }

    private var canSubmit: Bool {
        !currentPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private func submit() async {
        guard newPassword == confirmPassword else {
            message = "New passwords do not match."
            isError = true
            return
        }

        isSubmitting = true
        message = nil
        defer { isSubmitting = false }

        do {
            try await appModel.apiClient.sendVoid(
                APIRequest(
                    path: "api/auth/change-password",
                    method: .post,
                    body: ChangePasswordRequest(
                        currentPassword: currentPassword,
                        newPassword: newPassword
                    ),
                    requiresAuth: true,
                    cachePolicy: .networkOnly
                )
            )
            message = "Password updated."
            isError = false
            currentPassword = ""
            newPassword = ""
            confirmPassword = ""
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}
