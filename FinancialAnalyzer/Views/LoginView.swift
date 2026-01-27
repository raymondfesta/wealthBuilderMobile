import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

                    // Logo
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Capium")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Your financial companion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .padding(.horizontal, 32)

                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.secondary.opacity(0.3))
                    }
                    .padding(.horizontal, 32)

                    // Email/Password form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("Display Name", text: $displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocapitalization(.words)
                        }

                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(isSignUp ? .newPassword : .password)

                        if isSignUp {
                            Text("Password must be at least 8 characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await handleEmailAuth() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isFormValid || isLoading)

                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var isFormValid: Bool {
        let emailValid = email.contains("@") && email.contains(".")
        let passwordValid = password.count >= 8
        return emailValid && passwordValid
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                switch result {
                case .success(let authorization):
                    try await authService.signInWithApple(authorization: authorization)
                case .failure(let error):
                    if case ASAuthorizationError.canceled = error {
                        // User cancelled, don't show error
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }

    private func handleEmailAuth() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authService.register(
                    email: email,
                    password: password,
                    displayName: displayName.isEmpty ? nil : displayName
                )
            } else {
                try await authService.login(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    LoginView(authService: AuthService.shared)
}
