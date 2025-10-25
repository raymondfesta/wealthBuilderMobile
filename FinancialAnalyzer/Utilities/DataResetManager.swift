import Foundation
import SwiftUI

/// Centralized manager for resetting all app data during testing
/// Used for both manual reset (Demo tab button) and automatic reset (launch argument)
class DataResetManager {

    /// Reset all application data including Keychain, UserDefaults, ViewModel state, and optionally backend
    /// - Parameters:
    ///   - viewModel: The FinancialViewModel instance to reset
    ///   - includeBackend: Whether to also reset backend tokens (requires backend to be running)
    ///   - shouldExit: Whether to exit the app after reset (true for manual reset, false for launch-time reset)
    static func resetAll(
        viewModel: FinancialViewModel,
        includeBackend: Bool = true,
        shouldExit: Bool = false
    ) async {
        print("🗑️ [Reset] ===== STARTING COMPLETE DATA WIPE =====")

        // 1. Clear Backend (if requested and available)
        if includeBackend {
            await resetBackend()
        }

        // 2. Clear Keychain (all access tokens)
        clearKeychain()

        // 3. Clear UserDefaults (all cached data)
        clearUserDefaults()

        // 4. Reset ViewModel state
        await resetViewModelState(viewModel)

        // 5. Cancel any pending notifications
        await cancelNotifications()

        // Final log
        print("✅ [Reset] ===== DATA WIPE COMPLETE =====")

        if shouldExit {
            print("✅ [Reset] App will now exit. Please relaunch manually to see fresh state.")

            // Small delay to ensure logs are printed
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Force app termination for clean restart
            exit(0)
        } else {
            print("✅ [Reset] App will continue with fresh state.")
        }
    }

    /// Reset remaining data (Keychain, backend, ViewModel, notifications) without UserDefaults
    /// Used when UserDefaults was already cleared synchronously in AppDelegate
    /// - Parameter viewModel: The FinancialViewModel instance to reset
    static func resetRemainingData(viewModel: FinancialViewModel) async {
        print("🗑️ [Reset] ===== CLEARING REMAINING DATA =====")

        // 1. Clear Backend tokens
        await resetBackend()

        // 2. Clear Keychain (all access tokens)
        clearKeychain()

        // 3. Reset ViewModel state
        await resetViewModelState(viewModel)

        // 4. Cancel any pending notifications
        await cancelNotifications()

        print("✅ [Reset] ===== REMAINING DATA CLEARED =====")
    }

    // MARK: - Private Reset Methods

    /// Reset backend tokens via API endpoint
    private static func resetBackend() async {
        print("🗑️ [Reset] Attempting to clear backend tokens...")

        guard let url = URL(string: "http://192.168.1.8:3000/api/dev/reset-all") else {
            print("⚠️ [Reset] Invalid backend URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 3 // Quick timeout

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let cleared = json["cleared"] as? Int {
                print("🗑️ [Reset] ✅ Backend tokens cleared (\(cleared) items removed)")
            } else {
                print("⚠️ [Reset] Backend reset returned unexpected response")
            }
        } catch {
            print("⚠️ [Reset] Backend not available (this is OK if testing iOS only)")
            print("⚠️ [Reset] Backend error: \(error.localizedDescription)")
        }
    }

    /// Clear all Keychain access tokens
    private static func clearKeychain() {
        do {
            let allKeys = try KeychainService.shared.allKeys()
            print("🗑️ [Reset] Found \(allKeys.count) Keychain item(s) to delete")

            for key in allKeys {
                do {
                    try KeychainService.shared.delete(for: key)
                    print("🗑️ [Reset] ✅ Deleted Keychain item: \(key)")
                } catch {
                    print("🗑️ [Reset] ⚠️ Failed to delete Keychain item '\(key)': \(error)")
                }
            }
            print("🗑️ [Reset] Keychain cleared (\(allKeys.count) items removed)")
        } catch {
            print("🗑️ [Reset] ⚠️ Error listing Keychain keys: \(error)")
        }
    }

    /// Clear all cached data from UserDefaults
    private static func clearUserDefaults() {
        print("🗑️ [Reset] Clearing UserDefaults cache...")

        let keysToRemove = [
            "cached_accounts",
            "cached_transactions",
            "cached_summary",
            "cached_budgets",
            "cached_goals",
            "cached_allocation_buckets",
            "hasSeenWelcome",
            "hasCompletedOnboarding"
        ]

        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
            print("🗑️ [Reset] ✅ Removed UserDefaults key: \(key)")
        }
        UserDefaults.standard.synchronize()
        print("🗑️ [Reset] UserDefaults cleared (\(keysToRemove.count) keys removed)")
    }

    /// Reset ViewModel to clean state
    private static func resetViewModelState(_ viewModel: FinancialViewModel) async {
        print("🗑️ [Reset] Resetting ViewModel state...")

        await MainActor.run {
            viewModel.accounts.removeAll()
            viewModel.transactions.removeAll()
            viewModel.budgetManager.budgets.removeAll()
            viewModel.budgetManager.goals.removeAll()
            viewModel.budgetManager.allocationBuckets.removeAll()
            viewModel.summary = nil
            viewModel.currentAlert = nil
            viewModel.isShowingGuidance = false
            viewModel.error = nil
        }

        print("🗑️ [Reset] ViewModel state cleared")
    }

    /// Cancel all pending notifications
    private static func cancelNotifications() async {
        print("🗑️ [Reset] Canceling all pending notifications...")
        await MainActor.run {
            NotificationService.shared.cancelAllNotifications()
        }
        print("🗑️ [Reset] All notifications canceled")
    }
}
