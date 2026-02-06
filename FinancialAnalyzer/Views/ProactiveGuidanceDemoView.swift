import SwiftUI

/// Demo view to test the Proactive Guidance feature end-to-end
struct ProactiveGuidanceDemoView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var purchaseAmount: String = "87.43"
    @State private var merchantName: String = "Target"
    @State private var category: String = "Shopping"
    @State private var showNotificationTest = false
    @State private var showClearDataConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Current State
                Section("Current Financial State") {
                    if let summary = viewModel.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("To Allocate")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(summary.disposableIncome))
                                    .fontWeight(.bold)
                            }

                            HStack {
                                Text("Avg Monthly Income")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(summary.avgMonthlyIncome))
                            }

                            HStack {
                                Text("Avg Monthly Expenses")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(formatCurrency(summary.avgMonthlyExpenses))
                            }
                        }
                    } else {
                        Text("No financial data available")
                            .foregroundColor(.secondary)
                        Text("Connect your bank account first")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Section 2: Budgets
                Section("Active Budgets") {
                    if viewModel.budgetManager.budgets.isEmpty {
                        Button("Generate Budgets from Transactions") {
                            viewModel.budgetManager.generateBudgets(from: viewModel.transactions)
                        }
                        .disabled(viewModel.transactions.isEmpty)
                    } else {
                        ForEach(viewModel.budgetManager.budgets.prefix(5)) { budget in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(budget.categoryName)
                                        .font(.subheadline)
                                    Text("\(formatCurrency(budget.currentSpent)) / \(formatCurrency(budget.monthlyLimit))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(budget.status.rawValue)
                                    .font(.caption)
                                    .padding(4)
                                    .background(statusColor(budget.status).opacity(0.2))
                                    .foregroundColor(statusColor(budget.status))
                                    .cornerRadius(4)
                            }
                        }

                        if viewModel.budgetManager.budgets.count > 5 {
                            Text("+ \(viewModel.budgetManager.budgets.count - 5) more budgets")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Section 3: Goals
                Section("Financial Goals") {
                    if viewModel.budgetManager.goals.isEmpty {
                        Button("Create Emergency Fund Goal") {
                            createTestGoal()
                        }
                    } else {
                        ForEach(viewModel.budgetManager.goals) { goal in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(goal.name)
                                        .font(.subheadline)
                                    Text(goal.progressMessage())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(goal.currentAmount))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }

                // Section 4: Test Purchase
                Section("Test Purchase Alert") {
                    TextField("Amount", text: $purchaseAmount)
                        .keyboardType(.decimalPad)

                    TextField("Merchant", text: $merchantName)

                    TextField("Category", text: $category)

                    Button(action: testPurchaseAlert) {
                        Label("Evaluate Purchase", systemImage: "cart.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(purchaseAmount.isEmpty || merchantName.isEmpty)
                }

                // Section 5: Notification Tests
                Section("Test Notifications") {
                    Button(action: testPurchaseNotification) {
                        Label("Test Purchase Notification", systemImage: "bell.badge.fill")
                    }

                    Button(action: testSavingsNotification) {
                        Label("Test Savings Notification", systemImage: "sparkles")
                    }

                    Button(action: testCashFlowNotification) {
                        Label("Test Cash Flow Warning", systemImage: "bolt.fill")
                    }

                    Button(action: testGoalMilestone) {
                        Label("Test Goal Milestone", systemImage: "trophy.fill")
                    }
                }

                // Section 6: Quick Actions
                Section("Quick Actions") {
                    Button("Reset All Budgets") {
                        viewModel.budgetManager.budgets.removeAll()
                    }
                    .foregroundColor(.orange)

                    Button("Delete All Goals") {
                        viewModel.budgetManager.goals.removeAll()
                    }
                    .foregroundColor(.orange)

                    Button("View Pending Notifications") {
                        showNotificationTest = true
                    }
                }

                // Section 7: Developer Tools
                Section("Developer Tools") {
                    Button("Reset Onboarding Experience") {
                        UserDefaults.standard.set(false, forKey: "hasSeenWelcome")
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    }
                    .foregroundColor(.red)

                    Text("Tap to reset the welcome and onboarding screens. Close and reopen the app to see them again.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    Button(action: {
                        showClearDataConfirmation = true
                    }) {
                        Label("Clear All Data & Restart", systemImage: "trash.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Text("⚠️ This will delete ALL data (Keychain tokens, cached accounts, transactions, budgets, goals) and restart the app. Use this to test a completely fresh install.")
                        .font(.caption)
                        .foregroundColor(.red)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Pro Tip: Automatic Reset", systemImage: "lightbulb.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        Text("Enable '-ResetDataOnLaunch' in Xcode scheme settings to automatically clear all data on every build. No more manual reset steps!")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Xcode → Product → Scheme → Edit Scheme → Arguments → Check '-ResetDataOnLaunch'")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // Section 8: Instructions
                Section("How to Test") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Connect your bank account (Dashboard → +)")
                        Text("2. Wait for transactions to load")
                        Text("3. Tap 'Generate Budgets from Transactions'")
                        Text("4. Enter a purchase amount and tap 'Evaluate Purchase'")
                        Text("5. Test notifications (they appear in 5 seconds)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Proactive Guidance Demo")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNotificationTest) {
                NotificationTestView()
            }
            .alert("Clear All Data?", isPresented: $showClearDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear & Restart", role: .destructive) {
                    clearAllDataAndRestart()
                }
            } message: {
                Text("This will permanently delete:\n• All Keychain tokens\n• Cached accounts & transactions\n• All budgets and goals\n• Onboarding state\n\nThe app will exit and you'll need to relaunch it manually. Are you sure?")
            }
        }
    }

    // MARK: - Actions

    /// Completely wipes all app data and restarts for testing purposes
    /// Uses DataResetManager for centralized reset logic
    private func clearAllDataAndRestart() {
        Task {
            await DataResetManager.resetAll(
                viewModel: viewModel,
                includeBackend: true,
                shouldExit: true
            )
        }
    }

    private func testPurchaseAlert() {
        guard let amount = Double(purchaseAmount) else { return }
        viewModel.evaluatePurchase(
            amount: amount,
            merchantName: merchantName,
            category: category
        )
    }

    private func testPurchaseNotification() {
        Task {
            try? await NotificationService.shared.schedulePurchaseAlert(
                amount: 87.43,
                merchantName: "Target",
                budgetRemaining: 112,
                category: "Shopping",
                triggerInSeconds: 5
            )
        }
    }

    private func testSavingsNotification() {
        Task {
            try? await NotificationService.shared.scheduleSavingsOpportunityAlert(
                surplusAmount: 200,
                recommendedGoal: "Emergency Fund",
                triggerInSeconds: 5
            )
        }
    }

    private func testCashFlowNotification() {
        Task {
            try? await NotificationService.shared.scheduleCashFlowWarning(
                currentBalance: 847,
                upcomingExpenses: 326,
                daysAhead: 7,
                triggerInSeconds: 5
            )
        }
    }

    private func testGoalMilestone() {
        Task {
            try? await NotificationService.shared.scheduleGoalMilestone(
                goalName: "Emergency Fund",
                percentComplete: 75,
                triggerInSeconds: 5
            )
        }
    }

    private func createTestGoal() {
        viewModel.budgetManager.createGoal(
            name: "Emergency Fund",
            targetAmount: 5000,
            targetDate: nil,
            goalType: .emergencyFund,
            priority: .high
        )
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func statusColor(_ status: BudgetStatus) -> Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

// MARK: - Notification Test View

struct NotificationTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pendingNotifications: [UNNotificationRequest] = []

    var body: some View {
        NavigationStack {
            List {
                if pendingNotifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Pending Notifications")
                            .font(.headline)
                        Text("Schedule a test notification first")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(pendingNotifications, id: \.identifier) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.content.title)
                                .font(.headline)
                            Text(notification.content.body)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let trigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
                                Text("Triggers in: \(Int(trigger.timeInterval))s")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Pending Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadPendingNotifications()
            }
        }
    }

    private func loadPendingNotifications() async {
        pendingNotifications = await NotificationService.shared.getPendingNotifications()
    }
}

// MARK: - Preview

#Preview {
    ProactiveGuidanceDemoView(viewModel: FinancialViewModel())
}
