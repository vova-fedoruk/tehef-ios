import SwiftUI

struct AuthFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: AuthMode

    init(startsInSignUp: Bool = false) {
        _mode = State(initialValue: startsInSignUp ? .signUp : .login)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                Group {
                    switch mode {
                    case .login:
                        LoginView(
                            switchToSignUp: { mode = .signUp },
                            switchToForgotPassword: { mode = .forgotPassword }
                        )
                    case .signUp:
                        SignUpView(switchToLogin: { mode = .login })
                    case .forgotPassword:
                        ForgotPasswordView(switchToLogin: { mode = .login })
                    }
                }
                .padding(.horizontal, 20)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: appModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
}

private enum AuthMode {
    case login
    case signUp
    case forgotPassword
}

struct LoginView: View {
    @Environment(AppModel.self) private var appModel
    let switchToSignUp: () -> Void
    let switchToForgotPassword: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Welcome back")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(TehefTheme.foreground)
                    Text("Sign in to apply, chat, and manage your profile.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
                .glassCard(cornerRadius: 24)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tehefField()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .tehefField()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(isSubmitting ? "Signing in..." : "Sign in") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(isSubmitting || email.isEmpty || password.isEmpty)

                    Button("Forgot password?") {
                        switchToForgotPassword()
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }
                .glassCard(cornerRadius: 24)

                Button("Create an account") {
                    switchToSignUp()
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .padding(.vertical, 24)
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await appModel.sessionStore.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SignUpView: View {
    @Environment(AppModel.self) private var appModel
    let switchToLogin: () -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var role = "client"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Create account")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(TehefTheme.foreground)
                    Text("Join tehef as a client or provider.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
                .glassCard(cornerRadius: 24)

                VStack(spacing: 14) {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .tehefField()

                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .tehefField()

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tehefField()

                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                        .tehefField()

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .tehefField()

                    Picker("Role", selection: $role) {
                        Text("Client").tag("client")
                        Text("Provider").tag("provider")
                    }
                    .pickerStyle(.segmented)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(isSubmitting ? "Creating account..." : "Create account") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(isSubmitting || !canSubmit)
                }
                .glassCard(cornerRadius: 24)

                Button("Already have an account? Sign in") {
                    switchToLogin()
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .padding(.vertical, 24)
        }
    }

    private var canSubmit: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let request = SignUpRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: role,
            phone: phone.isEmpty ? nil : phone
        )

        do {
            try await appModel.sessionStore.signUp(request: request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var appModel
    let switchToLogin: () -> Void

    @State private var email = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Reset password")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(TehefTheme.foreground)
                    Text("Enter your email and we will send reset instructions if an account exists.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(TehefTheme.mutedForeground)
                }
                .glassCard(cornerRadius: 24)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .tehefField()

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let successMessage {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(TehefTheme.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(isSubmitting ? "Sending..." : "Send reset link") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(isSubmitting || email.isEmpty)
                }
                .glassCard(cornerRadius: 24)

                Button("Back to sign in") {
                    switchToLogin()
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .padding(.vertical, 24)
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await appModel.apiClient.send(
                APIRequest(
                    path: "api/auth/request-password-reset",
                    method: .post,
                    body: ForgotPasswordRequest(email: email)
                ),
                responseType: PasswordResetResponse.self
            )
            successMessage = response.message ?? "If an account exists, password reset instructions have been sent."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
