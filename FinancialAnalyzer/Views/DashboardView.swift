import SwiftUI

/// Post-onboarding dashboard view
/// Shows financial overview after user has completed their financial plan
struct DashboardView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedBucket: BucketCategory?
    @State private var showAddBudgetSheet = false
    @State private var showProfileSheet = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        planActiveView
                    }
                    .padding(DesignTokens.Spacing.md)
                }
                .primaryBackgroundGradient()
                .navigationTitle("Financial Overview")
                .toolbar {
                    // Add account button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            Task {
                                await viewModel.connectBankAccount(from: nil)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }

                    // Profile button
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showProfileSheet = true
                        } label: {
                            Image(systemName: "person.circle")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refreshAllData()
                }
                .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                    Button("OK") {
                        viewModel.error = nil
                    }
                } message: {
                    if let error = viewModel.error {
                        Text(error.localizedDescription)
                    }
                }
                .sheet(isPresented: $showAddBudgetSheet) {
                    AddBudgetSheet(budgetManager: viewModel.budgetManager)
                }
                .sheet(isPresented: $showProfileSheet) {
                    ProfileView(authService: AuthService.shared)
                }
            }

            // Loading overlay
            LoadingOverlay(
                currentStep: viewModel.loadingStep,
                isVisible: viewModel.showLoadingOverlay
            )

            // Success banner
            SuccessBanner(
                message: viewModel.successMessage,
                isVisible: viewModel.showSuccessBanner
            )
        }
    }

    // MARK: - Plan Active View

    private var planActiveView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Allocation Buckets Section
            if !viewModel.budgetManager.allocationBuckets.isEmpty {
                allocationBucketsSection
            }

            // Header
            headerSection

            // Financial Buckets
            if let summary = viewModel.summary {
                bucketsGrid(summary: summary)
            }

            // Budget Status
            budgetStatusSection

            // Recent Transactions
            recentTransactionsSection

            // Refresh Button
            refreshButton
        }
    }

    // MARK: - Allocation Buckets Section

    private var allocationBucketsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Your Financial Plan")
                .headlineStyle(color: .white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                        AllocationBucketSummaryCard(
                            bucket: bucket,
                            budgetManager: viewModel.budgetManager
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xxs)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Your Financial Summary")
                .headlineStyle(color: .white)

            if let summary = viewModel.summary {
                Text("Analysis of \(summary.totalTransactions) transactions over \(summary.monthsAnalyzed) months")
                    .captionStyle()

                Text("Last updated: \(summary.lastUpdated, style: .relative) ago")
                    .captionStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketsGrid(summary: AnalysisSnapshot) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: DesignTokens.Spacing.md) {
            ForEach(BucketCategory.allCases, id: \.self) { bucket in
                NavigationLink {
                    CategoryDetailView(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        summary: summary,
                        accounts: viewModel.accounts,
                        viewModel: viewModel
                    )
                } label: {
                    BucketCard(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        isSelected: selectedBucket == bucket,
                        needsValidationCount: viewModel.needsValidationCount(for: bucket)
                    )
                }
            }
        }
    }

    private var budgetStatusSection: some View {
        Group {
            if !viewModel.budgetManager.budgets.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Budget Status")
                            .headlineStyle(color: .white)

                        Spacer()

                        Text("\(viewModel.budgetManager.budgets.count) budgets")
                            .captionStyle()

                        Button {
                            showAddBudgetSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }

                    // Budget cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(viewModel.budgetManager.budgets.prefix(6)) { budget in
                                BudgetStatusCard(budget: budget)
                            }
                        }
                    }

                    // Warning if approaching limits
                    let warningBudgets = viewModel.budgetManager.budgets.filter {
                        $0.status == .warning || $0.status == .exceeded
                    }
                    if !warningBudgets.isEmpty {
                        HStack(spacing: DesignTokens.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(DesignTokens.Colors.opportunityOrange)
                                .font(.caption)
                            Text("\(warningBudgets.count) budget\(warningBudgets.count == 1 ? "" : "s") need attention")
                                .captionStyle()
                        }
                    }
                }
            } else if !viewModel.transactions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Budget Status")
                            .headlineStyle(color: .white)
                        Spacer()
                    }

                    SecondaryButton(title: "Generate Budgets from Transactions") {
                        viewModel.budgetManager.generateBudgets(from: viewModel.transactions)
                    }
                }
            }
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Recent Transactions")
                .headlineStyle(color: .white)

            ForEach(viewModel.recentTransactions(limit: 5), id: \.id) { transaction in
                TransactionRow(transaction: transaction)
            }

            if !viewModel.transactions.isEmpty {
                NavigationLink {
                    TransactionsListView(transactions: viewModel.transactions)
                } label: {
                    Text("View All Transactions")
                        .subheadlineStyle(color: DesignTokens.Colors.accentPrimary)
                }
            }
        }
    }

    private var refreshButton: some View {
        SecondaryButton(title: viewModel.isLoading ? "Refreshing..." : "Refresh Data", isDisabled: viewModel.isLoading) {
            Task {
                await viewModel.refreshAllData()
            }
        }
    }

    // MARK: - Helper Functions

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}
