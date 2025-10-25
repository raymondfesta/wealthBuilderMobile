import SwiftUI
import UserNotifications

@main
struct FinancialAnalyzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showWelcome) {
                    WelcomePageView(isPresented: $showWelcome)
                }
                .onAppear {
                    if !hasSeenWelcome {
                        showWelcome = true
                        hasSeenWelcome = true
                    }
                }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel: FinancialViewModel
    @StateObject private var navigationCoordinator = NotificationNavigationCoordinator()
    @State private var hasPerformedLaunchReset = false

    init() {
        _viewModel = StateObject(wrappedValue: FinancialViewModel())
    }

    /// Check if user has completed onboarding (finished building their financial plan)
    private var isOnboardingComplete: Bool {
        viewModel.userJourneyState == .planCreated
    }

    var body: some View {
        ZStack {
            if isOnboardingComplete {
                // Show full app with bottom navigation after onboarding
                TabView {
                    DashboardView(viewModel: viewModel)
                        .tabItem {
                            Label("Dashboard", systemImage: "chart.pie.fill")
                        }

                    if !viewModel.transactions.isEmpty {
                        TransactionsListView(transactions: viewModel.transactions)
                            .tabItem {
                                Label("Transactions", systemImage: "list.bullet")
                            }
                    }

                    if !viewModel.accounts.isEmpty {
                        AccountsView(viewModel: viewModel)
                            .tabItem {
                                Label("Accounts", systemImage: "building.columns.fill")
                            }
                    }

                    // Demo tab for testing proactive guidance
                    ProactiveGuidanceDemoView(viewModel: viewModel)
                        .tabItem {
                            Label("Demo", systemImage: "testtube.2")
                        }

                    // Temporarily commented out - re-enable after verifying target membership
                    // #if DEBUG
                    // // Debug tab for development only
                    // DebugView(viewModel: viewModel)
                    //     .tabItem {
                    //         Label("Debug", systemImage: "wrench.and.screwdriver.fill")
                    //     }
                    // #endif
                }
            } else {
                // Show only dashboard during onboarding (no bottom navigation)
                DashboardView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.isShowingGuidance) {
            if let alert = viewModel.currentAlert {
                ProactiveGuidanceView(alert: alert) { action in
                    viewModel.handleGuidanceAction(action)
                }
            }
        }
        .task {
            // Connect coordinator to view model
            await MainActor.run {
                viewModel.navigationCoordinator = navigationCoordinator
                navigationCoordinator.setViewModel(viewModel)
            }

            // Check for launch argument to auto-reset data
            // Note: UserDefaults was already cleared in AppDelegate before UI loaded
            if !hasPerformedLaunchReset {
                hasPerformedLaunchReset = true

                if ProcessInfo.processInfo.arguments.contains("-ResetDataOnLaunch") {
                    print("🔄 [Launch] Continuing automatic reset (UserDefaults already cleared)...")
                    print("🔄 [Launch] Clearing Keychain, backend tokens, ViewModel state, and notifications...")

                    // Clear remaining data (Keychain, backend, ViewModel, notifications)
                    // UserDefaults was already cleared in AppDelegate
                    await DataResetManager.resetRemainingData(viewModel: viewModel)

                    print("🔄 [Launch] Automatic reset complete, app ready with fresh data")
                }
            }
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // CRITICAL: Check for auto-reset BEFORE any UI is created
        // This ensures @AppStorage properties read the cleared values
        if ProcessInfo.processInfo.arguments.contains("-ResetDataOnLaunch") {
            print("🔄 [AppDelegate] Detected -ResetDataOnLaunch argument")
            print("🔄 [AppDelegate] Clearing UserDefaults synchronously before UI loads...")

            // Clear UserDefaults immediately (synchronous)
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
            }
            UserDefaults.standard.synchronize()

            print("🔄 [AppDelegate] UserDefaults cleared (\(keysToRemove.count) keys)")
            print("🔄 [AppDelegate] Keychain and backend will be cleared after app launch")
        }

        // Register notification delegate
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Register notification actions
        NotificationService.shared.registerNotificationActions()

        // Request notification permission
        Task {
            try? await NotificationService.shared.requestAuthorization()
        }

        return true
    }
}
