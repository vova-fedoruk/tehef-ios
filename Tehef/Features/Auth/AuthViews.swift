import SwiftUI
import AuthenticationServices

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
    @State private var isGoogleSubmitting = false
    @State private var errorMessage: String?
    @State private var googleCoordinator = GoogleOAuthCoordinator()
    @State private var turnstileToken: String?
    @State private var turnstileResetID = UUID()

    private var turnstileEnabled: Bool { TurnstileField.isEnabled }
    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && (!turnstileEnabled || turnstileToken != nil)
    }

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

                    TurnstileField(token: $turnstileToken, resetID: $turnstileResetID)

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
                    .disabled(isSubmitting || !canSubmit)

                    Button("Forgot password?") {
                        switchToForgotPassword()
                    }
                    .buttonStyle(GlassSecondaryButtonStyle())
                }
                .glassCard(cornerRadius: 24)

                Button(isGoogleSubmitting ? "Connecting…" : "Continue with Google") {
                    Task { await signInWithGoogle() }
                }
                .buttonStyle(GlassSecondaryButtonStyle())
                .disabled(isGoogleSubmitting || isSubmitting)

                Button("Create an account") {
                    switchToSignUp()
                }
                .buttonStyle(GlassSecondaryButtonStyle())
            }
            .padding(.vertical, 24)
        }
    }

    private func submit() async {
        if turnstileEnabled && turnstileToken == nil {
            errorMessage = "Complete the security check before continuing."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await appModel.sessionStore.login(
                email: email,
                password: password,
                turnstileToken: turnstileToken
            )
        } catch {
            errorMessage = AuthFormErrors.message(for: error)
            TurnstileField.reset(token: &turnstileToken, resetID: &turnstileResetID)
        }
    }

    private func signInWithGoogle() async {
        isGoogleSubmitting = true
        errorMessage = nil
        defer { isGoogleSubmitting = false }

        do {
            let code = try await googleCoordinator.start(baseURL: APIEnvironment.baseURL)
            try await appModel.sessionStore.completeOAuthExchange(code: code)
        } catch let authError as ASWebAuthenticationSessionError where authError.code == .canceledLogin {
            // User dismissed the browser
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
    @State private var isGoogleSubmitting = false
    @State private var errorMessage: String?
    @State private var googleCoordinator = GoogleOAuthCoordinator()
    @State private var turnstileToken: String?
    @State private var turnstileResetID = UUID()

    private var turnstileEnabled: Bool { TurnstileField.isEnabled }

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

                    TurnstileField(token: $turnstileToken, resetID: $turnstileResetID)

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
                    .disabled(isSubmitting || !canSubmitWithTurnstile)
                }
                .glassCard(cornerRadius: 24)

                Button(isGoogleSubmitting ? "Connecting…" : "Continue with Google") {
                    Task { await signUpWithGoogle() }
                }
                .buttonStyle(GlassSecondaryButtonStyle())
                .disabled(isGoogleSubmitting || isSubmitting)

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

    private var canSubmitWithTurnstile: Bool {
        canSubmit && (!turnstileEnabled || turnstileToken != nil)
    }

    private func submit() async {
        if turnstileEnabled && turnstileToken == nil {
            errorMessage = "Complete the security check before continuing."
            return
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let request = SignUpRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            role: role,
            phone: phone.isEmpty ? nil : phone,
            turnstileToken: turnstileToken
        )

        do {
            try await appModel.sessionStore.signUp(request: request)
        } catch {
            errorMessage = AuthFormErrors.message(for: error)
            TurnstileField.reset(token: &turnstileToken, resetID: &turnstileResetID)
        }
    }

    private func signUpWithGoogle() async {
        isGoogleSubmitting = true
        errorMessage = nil
        defer { isGoogleSubmitting = false }

        do {
            let code = try await googleCoordinator.start(baseURL: APIEnvironment.baseURL)
            try await appModel.sessionStore.completeOAuthExchange(code: code)
        } catch let authError as ASWebAuthenticationSessionError where authError.code == .canceledLogin {
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
    @State private var turnstileToken: String?
    @State private var turnstileResetID = UUID()

    private var turnstileEnabled: Bool { TurnstileField.isEnabled }
    private var canSubmit: Bool {
        !email.isEmpty && (!turnstileEnabled || turnstileToken != nil)
    }

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

                    TurnstileField(token: $turnstileToken, resetID: $turnstileResetID)

                    Button(isSubmitting ? "Sending..." : "Send reset link") {
                        Task { await submit() }
                    }
                    .buttonStyle(GlassPrimaryButtonStyle())
                    .disabled(isSubmitting || !canSubmit)
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
        if turnstileEnabled && turnstileToken == nil {
            errorMessage = "Complete the security check before continuing."
            return
        }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }

        do {
            let response = try await appModel.apiClient.send(
                APIRequest(
                    path: "api/auth/request-password-reset",
                    method: .post,
                    body: ForgotPasswordRequest(email: email, turnstileToken: turnstileToken)
                ),
                responseType: PasswordResetResponse.self
            )
            successMessage = response.message ?? "If an account exists, password reset instructions have been sent."
        } catch {
            errorMessage = AuthFormErrors.message(for: error)
            TurnstileField.reset(token: &turnstileToken, resetID: &turnstileResetID)
        }
    }
}

private enum AuthFormErrors {
    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        return error.localizedDescription
    }
}
