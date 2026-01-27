import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isSignUp = false
    @State private var showForm = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xxxl) {
                Spacer().frame(height: DesignTokens.Spacing.xxxl)

                // Logo
                Image("stacked_square 1")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 208, height: 214)

                // Headline + Description
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    Group {
                        Text("Your\n")
                            .foregroundColor(DesignTokens.Colors.textEmphasis)
                        + Text("Personal Finances. ")
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .bold()
                        + Text("Intelligently ")
                            .foregroundColor(DesignTokens.Colors.textEmphasis)
                        + Text("Automated.")
                            .foregroundColor(DesignTokens.Colors.accentPrimary)
                            .bold()
                    }
                    .font(.largeTitle)

                    Text("Connect once and get a personalized plan based on your recent financial history. Capium automatically analyzes your health and recommends real-time adjustments, like a money manager you control.")
                        .font(.body)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Buttons / Form
                VStack(spacing: DesignTokens.Spacing.lg) {
                    if !showForm {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .cornerRadius(DesignTokens.CornerRadius.sm)

                        // Create account button
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp = true
                                showForm = true
                                errorMessage = nil
                            }
                        } label: {
                            Text("Create account")
                                .font(.body)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                        .background(DesignTokens.Colors.accentPrimary)
                        .cornerRadius(DesignTokens.CornerRadius.pill)

                        // Sign in with email link
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSignUp = false
                                showForm = true
                                errorMessage = nil
                            }
                        } label: {
                            Text("Sign in with email")
                                .font(.body)
                                .foregroundColor(DesignTokens.Colors.stableBlue)
                        }
                        .frame(height: 50)
                    } else {
                        // Email/Password form
                        formContent
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .primaryBackgroundGradient()
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
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
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
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
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .background(DesignTokens.Colors.accentPrimary)
            .cornerRadius(DesignTokens.CornerRadius.pill)
            .disabled(!isFormValid || isLoading)
            .opacity(isFormValid && !isLoading ? 1 : 0.5)

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSignUp.toggle()
                    errorMessage = nil
                }
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.stableBlue)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showForm = false
                    errorMessage = nil
                }
            } label: {
                Text("Back")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
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
