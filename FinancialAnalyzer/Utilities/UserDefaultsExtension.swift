import Foundation

extension UserDefaults {
    /// Environment-aware UserDefaults that separates dev and production data
    static var app: UserDefaults {
        #if DEBUG
        // Use a separate suite for development builds
        // This prevents dev data from interfering with production builds
        return UserDefaults(suiteName: "com.financialanalyzer.dev") ?? .standard
        #else
        return .standard
        #endif
    }

    /// Convenience method to clear all app-specific data
    /// Use this in development to quickly reset the app state
    static func clearAppData() {
        #if DEBUG
        if let suiteName = "com.financialanalyzer.dev" {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        #endif

        // Also clear standard UserDefaults keys used by the app
        let appKeys = [
            "hasSeenWelcome",
            "cached_accounts",
            "cached_transactions",
            "cached_summary",
            "cached_budgets",
            "cached_goals",
            "cached_allocation_buckets"
        ]

        for key in appKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - Migration Helper

extension UserDefaults {
    /// Get the current app version for data migration purposes
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Get the last app version that was run
    static var lastAppVersion: String? {
        get { app.string(forKey: "lastAppVersion") }
        set { app.set(newValue, forKey: "lastAppVersion") }
    }

    /// Check if this is a fresh install (no previous version recorded)
    static var isFreshInstall: Bool {
        lastAppVersion == nil
    }

    /// Check if the app was updated since last run
    static var wasAppUpdated: Bool {
        guard let lastVersion = lastAppVersion else { return false }
        return lastVersion != appVersion
    }
}
