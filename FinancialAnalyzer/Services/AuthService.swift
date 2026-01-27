import Foundation
import AuthenticationServices

enum AuthError: LocalizedError {
    case invalidCredential
    case networkError(String)
    case serverError(String)
    case tokenExpired
    case notAuthenticated
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid credentials"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        case .tokenExpired:
            return "Session expired. Please sign in again."
        case .notAuthenticated:
            return "Not authenticated"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentUser: AuthUser?
    @Published var error: AuthError?

    private let tokenStorage = SecureTokenStorage.shared
    private let baseURL: String

    private init() {
        #if DEBUG
        // Use your Mac's local IP for simulator
        self.baseURL = "http://192.168.1.8:3000"
        #else
        self.baseURL = "https://api.yourapp.com"
        #endif

        Task {
            await checkExistingAuth()
        }
    }

    // MARK: - Public Auth Methods

    func signInWithApple(authorization: ASAuthorization) async throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }

        let authorizationCode = credential.authorizationCode
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        let body: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode,
            "fullName": [
                "givenName": credential.fullName?.givenName ?? "",
                "familyName": credential.fullName?.familyName ?? ""
            ],
            "email": credential.email ?? ""
        ]

        let response: AuthResponse = try await postAuth(endpoint: "/auth/apple", body: body)
        handleAuthResponse(response)
        print("✅ [AuthService] Apple Sign In successful: \(response.user.id)")
    }

    func register(email: String, password: String, displayName: String?) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "displayName": displayName ?? ""
        ]

        let response: AuthResponse = try await postAuth(endpoint: "/auth/register", body: body)
        handleAuthResponse(response)
        print("✅ [AuthService] Registration successful: \(response.user.id)")
    }

    func login(email: String, password: String) async throws {
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]

        let response: AuthResponse = try await postAuth(endpoint: "/auth/login", body: body)
        handleAuthResponse(response)
        print("✅ [AuthService] Login successful: \(response.user.id)")
    }

    func logout() async {
        // Try to revoke session on server
        if let refreshToken = tokenStorage.refreshToken,
           let accessToken = tokenStorage.accessToken {
            do {
                try await postAuthWithHeader(
                    endpoint: "/auth/logout",
                    body: ["refreshToken": refreshToken],
                    accessToken: accessToken
                )
            } catch {
                print("⚠️ [AuthService] Server logout failed: \(error)")
            }
        }

        // Clear local state
        tokenStorage.clearAll()
        currentUser = nil
        authState = .unauthenticated
        print("✅ [AuthService] Logged out")
    }

    func refreshTokenIfNeeded() async throws {
        guard let refreshToken = tokenStorage.refreshToken else {
            throw AuthError.notAuthenticated
        }

        let body: [String: Any] = ["refreshToken": refreshToken]
        let response: TokenRefreshResponse = try await postAuth(endpoint: "/auth/refresh", body: body)

        tokenStorage.saveAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
        print("✅ [AuthService] Token refreshed")
    }

    // MARK: - Token Access for API Calls

    var accessToken: String? {
        tokenStorage.accessToken
    }

    var userId: String? {
        tokenStorage.userId
    }

    // MARK: - Private Methods

    private func checkExistingAuth() async {
        guard tokenStorage.isAuthenticated else {
            authState = .unauthenticated
            return
        }

        do {
            try await refreshTokenIfNeeded()

            // Restore user from storage
            if let userId = tokenStorage.userId {
                currentUser = AuthUser(
                    id: userId,
                    email: tokenStorage.userEmail,
                    displayName: tokenStorage.userDisplayName,
                    emailVerified: true
                )
            }

            authState = .authenticated
            print("✅ [AuthService] Existing auth restored")
        } catch {
            print("⚠️ [AuthService] Token refresh failed, logging out: \(error)")
            tokenStorage.clearAll()
            authState = .unauthenticated
        }
    }

    private func handleAuthResponse(_ response: AuthResponse) {
        tokenStorage.saveAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken
        )
        tokenStorage.saveUser(response.user)
        currentUser = response.user
        authState = .authenticated
    }

    // MARK: - Network Helpers

    private func postAuth<T: Decodable>(endpoint: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AuthError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw AuthError.tokenExpired
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw AuthError.serverError(errorResponse.error)
            }
            throw AuthError.serverError("Request failed with status \(httpResponse.statusCode)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    private func postAuthWithHeader(endpoint: String, body: [String: Any], accessToken: String) async throws {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw AuthError.networkError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode < 400 else {
            throw AuthError.serverError("Logout request failed")
        }
    }
}

private struct ErrorResponse: Decodable {
    let error: String
}
