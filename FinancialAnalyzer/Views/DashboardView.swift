import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedBucket: BucketCategory?
    @State private var showAddBudgetSheet = false
    @State private var showConnectedAccountsSheet = false
    @State private var showHealthSetupFlow = false

    // Drill-down sheet states for AnalysisCompleteView
    @State private var showIncomeSheet = false
    @State private var showExpensesSheet = false
    @State private var showDebtMinimumsSheet = false
    @State private var showEmergencyFundSheet = false
    @State private var showDebtSheet = false
    @State private var showInvestmentsSheet = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Show different content based on user journey state
                    switch viewModel.userJourneyState {
                    case .noAccountsConnected:
                        emptyStateView

                    case .accountsConnected:
                        accountsConnectedView

                    case .analysisComplete:
                        analysisCompleteView

                    case .allocationPlanning:
                        AllocationPlannerView(viewModel: viewModel)

                    case .planCreated:
                        planActiveView
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .id(viewModel.userJourneyState) // Reset scroll position when state changes
            .primaryBackgroundGradient()
            .navigationTitle(navigationTitle)
            .toolbar {
                // Health Report Button (only in planCreated state)
                if viewModel.userJourneyState == .planCreated {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            // Mark as viewed
                            UserDefaults.standard.set(true, forKey: "has_viewed_health_report")
                            viewModel.showHealthReport = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .imageScale(.large)
                                    .foregroundColor(DesignTokens.Colors.accentSecondary)

                                // "New" badge (red dot)
                                if !UserDefaults.standard.bool(forKey: "has_viewed_health_report") {
                                    Circle()
                                        .fill(DesignTokens.Colors.opportunityOrange)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 6, y: -6)
                                }
                            }
                        }
                        .accessibilityLabel("Financial Health Report")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only show + button if we have accounts but not during allocation planning
                    if viewModel.userJourneyState != .noAccountsConnected && viewModel.userJourneyState != .allocationPlanning {
                        Button {
                            Task {
                                await viewModel.connectBankAccount(from: nil)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(DesignTokens.Colors.accentPrimary)
                        }
                    }
                }
            }
            .refreshable {
                // Only allow refresh if we have accounts
                if viewModel.userJourneyState != .noAccountsConnected {
                    await viewModel.refreshAllData()
                }
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
            .sheet(isPresented: $viewModel.showHealthReport) {
                NavigationStack {
                    FinancialHealthReportView(
                        healthMetrics: viewModel.healthMetrics,
                        onSetupHealthReport: {
                            // Close health report, open setup flow
                            viewModel.showHealthReport = false
                            showHealthSetupFlow = true
                        },
                        onDismiss: {
                            viewModel.showHealthReport = false
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                viewModel.showHealthReport = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showHealthSetupFlow) {
                HealthReportSetupFlow(viewModel: viewModel)
                    .onDisappear {
                        // After setup completes, automatically show the health report
                        if viewModel.healthMetrics != nil {
                            viewModel.showHealthReport = true
                        }
                    }
            }
            // Drill-down sheets for AnalysisCompleteView
            .sheet(isPresented: $showIncomeSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    IncomeDetailSheet(
                        transactions: viewModel.transactions,
                        monthlyAverage: snapshot.monthlyFlow.income
                    )
                }
            }
            .sheet(isPresented: $showExpensesSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    ExpenseDetailSheet(
                        transactions: viewModel.transactions,
                        monthlyAverage: snapshot.monthlyFlow.essentialExpenses,
                        expenseBreakdown: snapshot.monthlyFlow.expenseBreakdown,
                        onValidateTransaction: { _ in }
                    )
                }
            }
            .sheet(isPresented: $showDebtMinimumsSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    DebtMinimumsDetailSheet(
                        accounts: viewModel.accounts,
                        monthlyMinimums: snapshot.monthlyFlow.debtMinimums
                    )
                }
            }
            .sheet(isPresented: $showEmergencyFundSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    EmergencyFundDetailSheet(
                        accounts: viewModel.accounts,
                        totalCash: snapshot.position.emergencyCash,
                        monthsCovered: snapshot.position.emergencyCash / max(snapshot.monthlyFlow.essentialExpenses, 1)
                    )
                }
            }
            .sheet(isPresented: $showDebtSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    DebtMinimumsDetailSheet(
                        accounts: viewModel.accounts,
                        monthlyMinimums: snapshot.monthlyFlow.debtMinimums
                    )
                }
            }
            .sheet(isPresented: $showInvestmentsSheet) {
                if let snapshot = viewModel.analysisSnapshot {
                    InvestmentDetailSheet(
                        accounts: viewModel.accounts,
                        totalInvested: snapshot.position.investmentBalances,
                        monthlyContributions: snapshot.position.monthlyInvestmentContributions
                    )
                }
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

    // MARK: - Computed Properties

    private var navigationTitle: String {
        switch viewModel.userJourneyState {
        case .noAccountsConnected:
            return "Welcome"
        case .accountsConnected:
            return "Accounts Connected"
        case .analysisComplete:
            return "" // AnalysisCompleteView has its own header
        case .allocationPlanning:
            return "Plan Your Budget"
        case .planCreated:
            return "Financial Overview"
        }
    }

    // MARK: - State-Specific Views

    /// Empty state when no accounts are connected
    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(DesignTokens.Colors.stableBlue)

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(viewModel.userJourneyState.title)
                    .displayStyle()

                Text(viewModel.userJourneyState.description)
                    .bodyStyle()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.xxl)
            }

            PrimaryButton(title: viewModel.userJourneyState.nextActionTitle) {
                Task {
                    await viewModel.connectBankAccount(from: nil)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.xxl)
            .padding(.top, DesignTokens.Spacing.xl)

            Spacer()
        }
    }

    /// View shown after accounts are connected but before analysis
    private var accountsConnectedView: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()

            // Success message
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DesignTokens.Colors.progressGreen)

                Text("Accounts Connected!")
                    .displayStyle()

                Text("You've connected \(viewModel.accounts.count) account\(viewModel.accounts.count == 1 ? "" : "s")")
                    .bodyStyle()

                // View Connected Accounts button
                TextButton(title: "View Connected Accounts", color: DesignTokens.Colors.accentSecondary) {
                    showConnectedAccountsSheet = true
                }
                .padding(.top, DesignTokens.Spacing.xs)
            }

            Spacer()

            // Next step section
            VStack(spacing: DesignTokens.Spacing.lg) {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("Ready for the next step?")
                        .headlineStyle()

                    Text("We'll analyze your transactions and identify spending patterns")
                        .subheadlineStyle()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.xxl)
                }

                // Action buttons
                VStack(spacing: DesignTokens.Spacing.sm) {
                    // Primary CTA - Analyze Transactions
                    PrimaryButton(title: "Analyze My Transactions") {
                        Task {
                            await viewModel.analyzeMyFinances()
                        }
                    }

                    // Secondary CTA - Connect Another Account
                    SecondaryButton(title: "Connect Another Account") {
                        Task {
                            await viewModel.connectBankAccount(from: nil)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xxl)
            }
            .padding(.bottom, DesignTokens.Spacing.xxl)
        }
        .sheet(isPresented: $showConnectedAccountsSheet) {
            ConnectedAccountsSheet(viewModel: viewModel)
        }
    }

    /// View shown after analysis is complete but before plan is created
    @ViewBuilder
    private var analysisCompleteView: some View {
        if let snapshot = viewModel.analysisSnapshot {
            AnalysisCompleteView(
                snapshot: snapshot,
                onSeePlan: {
                    Task {
                        await viewModel.createMyPlan()
                    }
                },
                onDrillDown: { drillDownType in
                    // Handle drill-down navigation
                    handleDrillDown(drillDownType)
                }
            )
        } else {
            // Fallback if snapshot not available
            VStack(spacing: DesignTokens.Spacing.xl) {
                ProgressView()
                    .tint(DesignTokens.Colors.accentPrimary)
                Text("Loading analysis...")
                    .subheadlineStyle()
            }
        }
    }

    /// Handles drill-down navigation from AnalysisCompleteView
    private func handleDrillDown(_ type: AnalysisCompleteView.DrillDownType) {
        switch type {
        case .income:
            showIncomeSheet = true
        case .expenses:
            showExpensesSheet = true
        case .debtMinimums:
            showDebtMinimumsSheet = true
        case .emergencyFund:
            showEmergencyFundSheet = true
        case .debt:
            showDebtSheet = true
        case .investments:
            showInvestmentsSheet = true
        }
    }

    /// Full dashboard view shown when plan is created (existing functionality)
    private var planActiveView: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Financial Health Section (if available)
            if let healthMetrics = viewModel.healthMetrics {
                FinancialHealthDashboardSection(
                    healthMetrics: healthMetrics,
                    previousMetrics: viewModel.previousHealthMetrics,
                    onViewFullReport: {
                        viewModel.showHealthReport = true
                    }
                )
            }

            // Allocation Buckets Section (if available)
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

    /// Displays allocation buckets as horizontal scrolling cards
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
                    .onAppear {
                        print("🎨 [DashboardView] Rendering budget section with \(viewModel.budgetManager.budgets.count) budgets")
                        for (index, budget) in viewModel.budgetManager.budgets.enumerated() {
                            print("🎨 [DashboardView]   Budget \(index + 1): \(budget.categoryName) - $\(String(format: "%.2f", budget.monthlyLimit))")
                        }
                    }

                    // Budget cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ForEach(viewModel.budgetManager.budgets.prefix(6)) { budget in
                                BudgetStatusCard(budget: budget)
                                    .onAppear {
                                        print("🎨 [DashboardView] Rendering budget card: \(budget.categoryName)")
                                    }
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
                // Show generate budgets button if we have transactions but no budgets
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

// MARK: - Bucket Card

struct BucketCard: View {
    let category: BucketCategory
    let amount: Double
    let isSelected: Bool
    var needsValidationCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(category.designColor)

                Spacer()

                // Validation badge
                if needsValidationCount > 0 {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.Colors.opportunityOrange)
                            .frame(width: 24, height: 24)

                        Text("\(needsValidationCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }

            Text(category.rawValue)
                .captionStyle()
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(formattedAmount)
                .titleValueStyle()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 120)
        .primaryCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(isSelected ? category.designColor : Color.clear, lineWidth: 2)
        )
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Transaction Row

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(transaction.name)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)

                if let merchantName = transaction.merchantName {
                    Text(merchantName)
                        .captionStyle()
                }

                Text(transaction.date, style: .date)
                    .captionStyle()
            }

            Spacer()

            Text(formattedAmount)
                .subheadlineStyle(color: transaction.amount < 0 ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.textPrimary)
        }
        .padding(DesignTokens.Spacing.md)
        .primaryCardStyle()
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        let value = transaction.amount < 0 ? abs(transaction.amount) : transaction.amount
        let sign = transaction.amount < 0 ? "+" : "-"
        return sign + (formatter.string(from: NSNumber(value: value)) ?? "$0.00")
    }
}

// MARK: - Budget Status Card

struct BudgetStatusCard: View {
    let budget: Budget

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            // Category name and badges
            HStack {
                Text(budget.categoryName)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Auto-generated badge
                if budget.isAutoGenerated {
                    Text("AUTO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(DesignTokens.Colors.stableBlue.opacity(0.2))
                        .foregroundColor(DesignTokens.Colors.stableBlue)
                        .cornerRadius(4)
                }

                // Status badge
                Text(budget.status.rawValue.uppercased())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }

            // Spending progress
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                HStack {
                    Text(formatCurrency(budget.currentSpent))
                        .titleValueStyle()

                    Text("of \(formatCurrency(budget.monthlyLimit))")
                        .captionStyle()
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignTokens.Colors.borderMedium)

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * min(percentUsed / 100, 1.0))
                    }
                }
                .frame(height: 6)

                // Remaining amount
                Text("\(formatCurrency(budget.remaining)) remaining")
                    .captionStyle()
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(width: 200)
        .primaryCardStyle()
    }

    private var percentUsed: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        return (budget.currentSpent / budget.monthlyLimit) * 100
    }

    private var statusColor: Color {
        switch budget.status {
        case .onTrack: return DesignTokens.Colors.progressGreen
        case .caution: return DesignTokens.Colors.accentPrimary
        case .warning: return DesignTokens.Colors.opportunityOrange
        case .exceeded: return Color(red: 255/255, green: 59/255, blue: 48/255)  // System red
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Allocation Bucket Summary Card

/// Compact read-only card for displaying allocation bucket on dashboard
struct AllocationBucketSummaryCard: View {
    let bucket: AllocationBucket
    let budgetManager: BudgetManager

    var body: some View {
        NavigationLink(destination: AllocationBucketDetailView(
            bucket: bucket,
            budgetManager: budgetManager
        )) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // Icon
                HStack {
                    Image(systemName: bucket.icon)
                        .font(.title3)
                        .foregroundColor(Color(hex: bucket.color))
                    Spacer()
                }

                // Name
                Text(bucket.displayName)
                    .captionStyle()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Amount
                Text(formatCurrency(bucket.allocatedAmount))
                    .titleValueStyle()
                    .lineLimit(1)

                // Percentage
                Text("\(Int(bucket.percentageOfIncome))% of income")
                    .captionStyle()
            }
            .padding(DesignTokens.Spacing.md)
            .primaryCardStyle()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(bucket.displayName), \(formatCurrency(bucket.allocatedAmount)), \(Int(bucket.percentageOfIncome))% of income")
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
