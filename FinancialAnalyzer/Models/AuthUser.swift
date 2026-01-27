import Foundation

struct AuthUser: Codable, Equatable {
    let id: String
    let email: String?
    let displayName: String?
    let emailVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case emailVerified
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
    let isNewUser: Bool
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
}
