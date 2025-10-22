import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedBucket: BucketCategory?
    @State private var showAddBudgetSheet = false

    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                VStack(spacing: 20) {
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
                .padding()
            }
            .id(viewModel.userJourneyState) // Reset scroll position when state changes
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Only show + button if we have accounts but not during allocation planning
                    if viewModel.userJourneyState != .noAccountsConnected && viewModel.userJourneyState != .allocationPlanning {
                        Button {
                            Task {
                                await viewModel.connectBankAccount(from: nil)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
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
            return "Analysis Report"
        case .allocationPlanning:
            return "Plan Your Budget"
        case .planCreated:
            return "Financial Overview"
        }
    }

    // MARK: - State-Specific Views

    /// Empty state when no accounts are connected
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.pie.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text(viewModel.userJourneyState.title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(viewModel.userJourneyState.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task {
                    await viewModel.connectBankAccount(from: nil)
                }
            } label: {
                Label(viewModel.userJourneyState.nextActionTitle, systemImage: "building.columns.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)

            Spacer()
        }
    }

    /// View shown after accounts are connected but before analysis
    private var accountsConnectedView: some View {
        VStack(spacing: 24) {
            // Success message
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)

                Text("Accounts Connected!")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("You've connected \(viewModel.accounts.count) account\(viewModel.accounts.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            // Show connected accounts
            VStack(alignment: .leading, spacing: 16) {
                Text("Connected Accounts")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(viewModel.accounts, id: \.id) { account in
                    HStack {
                        Image(systemName: "building.columns.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text((account.mask ?? "").isEmpty ? account.id : "**** \(account.mask ?? "")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(formatCurrency(account.currentBalance ?? 0))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }

            Spacer()

            // Next step CTA
            VStack(spacing: 12) {
                Text("Ready for the next step?")
                    .font(.headline)

                Text("We'll analyze your transactions and identify spending patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    Task {
                        await viewModel.analyzeMyFinances()
                    }
                } label: {
                    Label("Analyze My Transactions", systemImage: "chart.bar.doc.horizontal.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
    }

    /// View shown after analysis is complete but before plan is created
    private var analysisCompleteView: some View {
        VStack(spacing: 24) {
            // Analysis summary header
            VStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Analysis Complete!")
                    .font(.title2)
                    .fontWeight(.bold)

                if let summary = viewModel.summary {
                    Text("Analyzed \(summary.totalTransactions) transactions over \(summary.monthsAnalyzed) months")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 40)

            // Show financial buckets if summary exists
            if let summary = viewModel.summary {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Spending Breakdown")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(BucketCategory.allCases, id: \.self) { bucket in
                            NavigationLink {
                                CategoryDetailView(
                                    category: bucket,
                                    amount: summary.bucketValue(for: bucket),
                                    summary: summary,
                                    transactions: viewModel.transactions,
                                    accounts: viewModel.accounts
                                )
                            } label: {
                                BucketCard(
                                    category: bucket,
                                    amount: summary.bucketValue(for: bucket),
                                    isSelected: false
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Next step CTA
            VStack(spacing: 12) {
                Text("Ready to create your plan?")
                    .font(.headline)

                Text("We'll generate personalized budgets based on your spending patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    Task {
                        await viewModel.createMyPlan()
                    }
                } label: {
                    Label("Create My Financial Plan", systemImage: "sparkles")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
            }
            .padding(.bottom, 24)
        }
    }

    /// Full dashboard view shown when plan is created (existing functionality)
    private var planActiveView: some View {
        VStack(spacing: 20) {
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Financial Plan")
                .font(.title2)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                        AllocationBucketSummaryCard(
                            bucket: bucket,
                            budgetManager: viewModel.budgetManager
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Financial Summary")
                .font(.title2)
                .fontWeight(.bold)

            if let summary = viewModel.summary {
                Text("Analysis of \(summary.totalTransactions) transactions over \(summary.monthsAnalyzed) months")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Last updated: \(summary.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bucketsGrid(summary: FinancialSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(BucketCategory.allCases, id: \.self) { bucket in
                NavigationLink {
                    CategoryDetailView(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        summary: summary,
                        transactions: viewModel.transactions,
                        accounts: viewModel.accounts
                    )
                } label: {
                    BucketCard(
                        category: bucket,
                        amount: summary.bucketValue(for: bucket),
                        isSelected: selectedBucket == bucket
                    )
                }
            }
        }
    }

    private var budgetStatusSection: some View {
        Group {
            if !viewModel.budgetManager.budgets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Budget Status")
                            .font(.headline)

                        Spacer()

                        Text("\(viewModel.budgetManager.budgets.count) budgets")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            showAddBudgetSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .onAppear {
                        print("🎨 [DashboardView] Rendering budget section with \(viewModel.budgetManager.budgets.count) budgets")
                        for (index, budget) in viewModel.budgetManager.budgets.enumerated() {
                            print("🎨 [DashboardView]   Budget \(index + 1): \(budget.categoryName) - $\(String(format: "%.2f", budget.monthlyLimit))")
                        }
                    }

                    // Budget cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.budgetManager.budgets.prefix(6)) { budget in
                                BudgetStatusCard(budget: budget)
                                    .onAppear {
                                        print("🎨 [DashboardView] Rendering budget card: \(budget.categoryName)")
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Warning if approaching limits
                    let warningBudgets = viewModel.budgetManager.budgets.filter {
                        $0.status == .warning || $0.status == .exceeded
                    }
                    if !warningBudgets.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(warningBudgets.count) budget\(warningBudgets.count == 1 ? "" : "s") need attention")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            } else if !viewModel.transactions.isEmpty {
                // Show generate budgets button if we have transactions but no budgets
                VStack(spacing: 12) {
                    HStack {
                        Text("Budget Status")
                            .font(.headline)
                        Spacer()
                    }

                    Button {
                        viewModel.budgetManager.generateBudgets(from: viewModel.transactions)
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Generate Budgets from Transactions")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(.headline)
                .padding(.horizontal)

            ForEach(viewModel.recentTransactions(limit: 5), id: \.id) { transaction in
                TransactionRow(transaction: transaction)
            }

            if !viewModel.transactions.isEmpty {
                NavigationLink {
                    TransactionsListView(transactions: viewModel.transactions)
                } label: {
                    Text("View All Transactions")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }

    private var refreshButton: some View {
        Button {
            Task {
                await viewModel.refreshAllData()
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
            } else {
                Label("Refresh Data", systemImage: "arrow.clockwise")
            }
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isLoading)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.iconName)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            Text(category.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(formattedAmount)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? color : Color.clear, lineWidth: 2)
        )
    }

    private var color: Color {
        switch category.color {
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "mint": return .mint
        case "purple": return .purple
        default: return .gray
        }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let merchantName = transaction.merchantName {
                    Text(merchantName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(transaction.date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(formattedAmount)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.amount < 0 ? .green : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
        VStack(alignment: .leading, spacing: 8) {
            // Category name and badges
            HStack {
                Text(budget.categoryName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Spacer()

                // Auto-generated badge
                if budget.isAutoGenerated {
                    Text("AUTO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(formatCurrency(budget.currentSpent))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("of \(formatCurrency(budget.monthlyLimit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * min(percentUsed / 100, 1.0))
                    }
                }
                .frame(height: 6)

                // Remaining amount
                Text("\(formatCurrency(budget.remaining)) remaining")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var percentUsed: Double {
        guard budget.monthlyLimit > 0 else { return 0 }
        return (budget.currentSpent / budget.monthlyLimit) * 100
    }

    private var statusColor: Color {
        switch budget.status {
        case .onTrack: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .exceeded: return .red
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
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                HStack {
                    Image(systemName: bucket.icon)
                        .font(.title3)
                        .foregroundColor(Color(hex: bucket.color))
                    Spacer()
                }

                // Name
                Text(bucket.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                // Amount
                Text(formatCurrency(bucket.allocatedAmount))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // Percentage
                Text("\(Int(bucket.percentageOfIncome))% of income")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
