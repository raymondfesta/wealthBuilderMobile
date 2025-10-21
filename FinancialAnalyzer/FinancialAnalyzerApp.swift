import SwiftUI
import UserNotifications

@main
struct FinancialAnalyzerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                        hasCompletedOnboarding = true
                    }
                }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel: FinancialViewModel
    @StateObject private var navigationCoordinator = NotificationNavigationCoordinator()

    init() {
        _viewModel = StateObject(wrappedValue: FinancialViewModel())
    }

    var body: some View {
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
