import SwiftUI

struct DebugView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var keychainItemIds: [String] = []
    @State private var debugInfo: String = ""
    @State private var backendStatus: BackendStatus = .unknown
    @State private var isResetting: Bool = false
    @State private var showResetConfirmation: Bool = false

    enum BackendStatus {
        case unknown, connected, disconnected

        var color: Color {
            switch self {
            case .unknown: return .gray
            case .connected: return .green
            case .disconnected: return .red
            }
        }

        var text: String {
            switch self {
            case .unknown: return "Unknown"
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Backend Status Section
                Section("Backend Connection") {
                    HStack {
                        Circle()
                            .fill(backendStatus.color)
                            .frame(width: 12, height: 12)
                        Text(backendStatus.text)
                        Spacer()
                        Button("Check") {
                            Task {
                                await checkBackendStatus()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // Quick Stats Section
                Section("Current State") {
                    LabeledContent("Accounts", value: "\(viewModel.accounts.count)")
                    LabeledContent("Transactions", value: "\(viewModel.transactions.count)")
                    LabeledContent("Budgets", value: "\(viewModel.budgetManager.budgets.count)")
                    LabeledContent("Goals", value: "\(viewModel.budgetManager.goals.count)")
                    LabeledContent("Keychain Items", value: "\(keychainItemIds.count)")
                    LabeledContent("User Journey", value: viewModel.userJourneyState.title)
                }

                // Keychain Items
                Section("Keychain Items") {
                    if !keychainItemIds.isEmpty {
                        ForEach(keychainItemIds, id: \.self) { itemId in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(itemId)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Tap to delete")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                deleteKeychainItem(itemId)
                            }
                        }
                    } else {
                        Text("No items in Keychain")
                            .foregroundColor(.secondary)
                    }
                }

                // User Journey Actions
                Section("User Journey Simulation") {
                    Button {
                        simulateFreshUser()
                    } label: {
                        Label("Simulate Fresh User", systemImage: "person.badge.plus")
                    }

                    Button {
                        resetToOnboarding()
                    } label: {
                        Label("Reset to Onboarding", systemImage: "arrow.counterclockwise")
                    }
                }

                // Data Management Actions
                Section("Data Management") {
                    Button {
                        Task {
                            await viewModel.refreshData()
                            checkKeychain()
                        }
                    } label: {
                        Label("Force Refresh Data", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        Label("Clear Cache Only", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        clearKeychain()
                    } label: {
                        Label("Clear Keychain Only", systemImage: "key.slash")
                    }

                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Full Reset (iOS + Backend)", systemImage: "exclamationmark.triangle.fill")
                    }
                    .disabled(isResetting)
                }

                // Debug Info
                Section("Debug Log") {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Debug Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await refreshAll()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("Full Reset", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset Everything", role: .destructive) {
                    Task {
                        await performFullReset()
                    }
                }
            } message: {
                Text("This will clear all iOS data AND backend tokens. You'll start fresh as a new user. This cannot be undone.")
            }
        }
        .task {
            await refreshAll()
        }
    }

    // MARK: - Actions

    private func refreshAll() async {
        checkKeychain()
        await checkBackendStatus()
    }

    private func checkKeychain() {
        do {
            keychainItemIds = try KeychainService.shared.allKeys()
            updateDebugInfo()
        } catch {
            debugInfo = "❌ Error checking Keychain: \(error.localizedDescription)"
        }
    }

    private func updateDebugInfo() {
        var info = "✅ Last updated: \(Date().formatted(date: .omitted, time: .standard))\n\n"
        info += "📊 Data Summary:\n"
        info += "  • Keychain items: \(keychainItemIds.count)\n"
        info += "  • Accounts: \(viewModel.accounts.count)\n"
        info += "  • Transactions: \(viewModel.transactions.count)\n"
        info += "  • Budgets: \(viewModel.budgetManager.budgets.count)\n"
        info += "  • Goals: \(viewModel.budgetManager.goals.count)\n\n"

        // Check cache
        let cacheKeys = ["cached_accounts", "cached_transactions", "cached_summary",
                         "cached_budgets", "cached_goals", "cached_allocation_buckets"]
        var cachedItems: [String] = []
        for key in cacheKeys {
            if UserDefaults.standard.data(forKey: key) != nil {
                cachedItems.append(key.replacingOccurrences(of: "cached_", with: ""))
            }
        }

        if !cachedItems.isEmpty {
            info += "💾 Cached: \(cachedItems.joined(separator: ", "))\n"
        } else {
            info += "💾 Cache: Empty\n"
        }

        debugInfo = info
    }

    private func checkBackendStatus() async {
        do {
            let baseURL = AppConfig.baseURL
            guard let url = URL(string: "\(baseURL)/health") else {
                backendStatus = .disconnected
                return
            }

            let (_, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                backendStatus = .connected
            } else {
                backendStatus = .disconnected
            }
        } catch {
            backendStatus = .disconnected
        }
        updateDebugInfo()
    }

    private func clearCache() {
        let cacheKeys = [
            "cached_accounts",
            "cached_transactions",
            "cached_summary",
            "cached_budgets",
            "cached_goals",
            "cached_allocation_buckets"
        ]

        for key in cacheKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }

        debugInfo = "✅ Cache cleared (\(cacheKeys.count) keys)\n" + debugInfo
        checkKeychain()
    }

    private func clearKeychain() {
        do {
            let itemIds = try KeychainService.shared.allKeys()
            for itemId in itemIds {
                try? KeychainService.shared.delete(for: itemId)
            }
            debugInfo = "✅ Keychain cleared: \(itemIds.count) items removed\n" + debugInfo
            checkKeychain()
        } catch {
            debugInfo = "❌ Error clearing Keychain: \(error.localizedDescription)\n" + debugInfo
        }
    }

    private func deleteKeychainItem(_ itemId: String) {
        do {
            try KeychainService.shared.delete(for: itemId)
            debugInfo = "✅ Deleted keychain item: \(itemId)\n" + debugInfo
            checkKeychain()
        } catch {
            debugInfo = "❌ Error deleting item: \(error.localizedDescription)\n" + debugInfo
        }
    }

    private func simulateFreshUser() {
        // Clear all data
        clearCache()
        clearKeychain()

        // Reset ViewModel state
        viewModel.accounts = []
        viewModel.transactions = []
        viewModel.summary = nil
        viewModel.budgetManager.budgets = []
        viewModel.budgetManager.goals = []
        viewModel.budgetManager.allocationBuckets = []
        viewModel.userJourneyState = .noAccountsConnected

        // Clear UserDefaults flags
        UserDefaults.standard.removeObject(forKey: "hasSeenWelcome")

        debugInfo = "✅ Simulated fresh user - all data cleared\n" + debugInfo
        checkKeychain()
    }

    private func resetToOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
        debugInfo = "✅ Reset to onboarding - restart app to see welcome screen\n" + debugInfo
    }

    private func performFullReset() async {
        isResetting = true
        debugInfo = "🔄 Performing full reset...\n"

        // 1. Clear iOS data
        clearCache()
        clearKeychain()

        // 2. Clear backend tokens
        await clearBackendTokens()

        // 3. Reset ViewModel
        viewModel.accounts = []
        viewModel.transactions = []
        viewModel.summary = nil
        viewModel.budgetManager.budgets = []
        viewModel.budgetManager.goals = []
        viewModel.budgetManager.allocationBuckets = []
        viewModel.userJourneyState = .noAccountsConnected

        // 4. Reset UserDefaults flags
        UserDefaults.standard.removeObject(forKey: "hasSeenWelcome")

        debugInfo = "✅ FULL RESET COMPLETE\n" +
                   "• iOS cache cleared\n" +
                   "• Keychain cleared\n" +
                   "• Backend tokens cleared\n" +
                   "• Ready for fresh start\n\n" + debugInfo

        isResetting = false
        await checkBackendStatus()
        checkKeychain()
    }

    private func clearBackendTokens() async {
        do {
            let baseURL = AppConfig.baseURL
            guard let url = URL(string: "\(baseURL)/api/dev/reset-all") else {
                debugInfo += "❌ Invalid backend URL\n"
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                debugInfo += "✅ Backend tokens cleared\n"
            } else {
                debugInfo += "⚠️ Backend reset may have failed\n"
            }
        } catch {
            debugInfo += "❌ Failed to clear backend: \(error.localizedDescription)\n"
        }
    }
}
