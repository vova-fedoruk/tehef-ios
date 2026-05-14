import SwiftUI

struct AuthFlowView: View {
    @State private var mode: AuthMode = .login

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                Group {
                    switch mode {
                    case .login:
                        LoginView(switchToSignUp: { mode = .signUp })
                    case .signUp:
                        SignUpView(switchToLogin: { mode = .login })
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private enum AuthMode {
    case login
    case signUp
}

struct LoginView: View {
    @Environment(AppModel.self) private var appModel
    let switchToSignUp: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Welcome back")
                    .font(.largeTitle.weight(.bold))
                Text("Sign in to manage tasks, chat, and your profile.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .glassCard(cornerRadius: 24)

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(isSubmitting ? "Signing in..." : "Sign in") {
                    Task { await submit() }
                }
                .buttonStyle(GlassPrimaryButtonStyle())
                .disabled(isSubmitting || email.isEmpty || password.isEmpty)
            }
            .glassCard(cornerRadius: 24)

            Button("Create an account") {
                switchToSignUp()
            }
            .buttonStyle(GlassSecondaryButtonStyle())
        }
        .frame(maxHeight: .infinity, alignment: .center)
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
                        .font(.largeTitle.weight(.bold))
                    Text("Join tehef as a client or provider.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .glassCard(cornerRadius: 24)

                VStack(spacing: 14) {
                    TextField("First name", text: $firstName)
                        .textContentType(.givenName)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    TextField("Last name", text: $lastName)
                        .textContentType(.familyName)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    TextField("Phone (optional)", text: $phone)
                        .keyboardType(.phonePad)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    Picker("Role", selection: $role) {
                        Text("Client").tag("client")
                        Text("Provider").tag("provider")
                    }
                    .pickerStyle(.segmented)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
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
