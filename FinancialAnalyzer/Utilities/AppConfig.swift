import Foundation

enum AppConfig {
    // MARK: - Environment Configuration

    /// Set this to switch between local development and production
    private static let environment: Environment = .localhost

    enum Environment {
        case local          // Local Mac (wifi network)
        case localhost      // iOS Simulator only
        case development    // Railway deployment
    }

    // MARK: - Base URL

    static var baseURL: String {
        switch environment {
        case .local:
            // Update this IP when your Mac's address changes
            // Get current IP: ipconfig getifaddr en0
            return "http://192.168.1.8:3000"

        case .localhost:
            // Simulator only - won't work on physical device
            return "http://localhost:3000"

        case .development:
            // Railway deployment URL
            // Update this after Railway deployment
            return "https://your-app.up.railway.app"
        }
    }

    // MARK: - Environment Info

    static var environmentName: String {
        switch environment {
        case .local: return "Local Network"
        case .localhost: return "Localhost"
        case .development: return "Railway (Development)"
        }
    }

    static var isProduction: Bool {
        environment == .development
    }
}
