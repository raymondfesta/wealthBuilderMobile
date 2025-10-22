import SwiftUI

/// Detail view for viewing and managing a specific allocation bucket
struct AllocationBucketDetailView: View {
    @ObservedObject var bucket: AllocationBucket
    @ObservedObject var budgetManager: BudgetManager
    @Environment(\.dismiss) var dismiss

    @State private var showEditAllocationSheet = false
    @State private var showAddBudgetSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero summary card
                heroSection

                // AI Insight card
                insightSection

                // Emergency fund specifics (conditional)
                if bucket.type == .emergencyFund {
                    emergencyFundSection
                }

                // Linked budgets section
                linkedBudgetsSection

                // Quick actions
                actionsSection

                Spacer().frame(height: 20)
            }
            .padding()
        }
        .navigationTitle(bucket.displayName)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditAllocationSheet) {
            EditAllocationSheet(bucket: bucket, budgetManager: budgetManager)
        }
        .sheet(isPresented: $showAddBudgetSheet) {
            AddBudgetSheet(budgetManager: budgetManager)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Icon and bucket name
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: bucket.color).opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: bucket.icon)
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: bucket.color))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bucket.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(formatCurrency(bucket.allocatedAmount)) allocated (\(Int(bucket.percentageOfIncome))%)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            // Usage progress
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Usage")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(usagePercentage))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(usageColor)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(usageColor)
                            .frame(width: geometry.size.width * min(usagePercentage / 100, 1.0))
                    }
                }
                .frame(height: 12)

                // Spent vs remaining
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Spent")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(totalSpent))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatCurrency(totalRemaining))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(totalRemaining >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bucket.displayName), \(formatCurrency(bucket.allocatedAmount)), \(Int(usagePercentage))% used")
    }

    // MARK: - AI Insight Section

    private var insightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("AI Insight")
                    .font(.headline)
            }

            Text(bucket.explanation)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Emergency Fund Section

    private var emergencyFundSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cross.case.fill")
                    .foregroundColor(.red)
                Text("Emergency Fund Progress")
                    .font(.headline)
            }

            if let targetAmount = bucket.targetAmount {
                VStack(spacing: 16) {
                    // Target amount
                    HStack {
                        Text("Target Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(targetAmount))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    // Current savings (from linked goal if available)
                    let currentSavings = emergencyFundGoal?.currentAmount ?? 0
                    HStack {
                        Text("Current Savings")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatCurrency(currentSavings))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }

                    // Progress bar
                    let progress = targetAmount > 0 ? min(currentSavings / targetAmount, 1.0) : 0
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(progressGradient(for: progress))
                                    .frame(width: geometry.size.width * progress)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let monthsToTarget = bucket.monthsToTarget {
                                Text("\(monthsToTarget) months to target")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Status indicator
                    if progress >= 1.0 {
                        statusBadge(
                            text: "Goal Reached!",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                    } else if progress >= 0.5 {
                        statusBadge(
                            text: "On Track",
                            icon: "arrow.up.circle.fill",
                            color: .blue
                        )
                    } else {
                        statusBadge(
                            text: "Keep Going",
                            icon: "arrow.right.circle.fill",
                            color: .orange
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Linked Budgets Section

    private var linkedBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(linkedBudgets.isEmpty ? "Budget Categories" : "Categories in this bucket")
                    .font(.headline)
                Spacer()
                if !linkedBudgets.isEmpty {
                    Text("\(linkedBudgets.count) categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if linkedBudgets.isEmpty {
                emptyBudgetsState
            } else {
                ForEach(linkedBudgets) { budget in
                    LinkedBudgetCard(budget: budget, bucketColor: bucket.color)
                }
            }

            // Add budget button
            if !bucket.linkedBudgetCategories.isEmpty {
                Button {
                    showAddBudgetSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Budget Category")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(Color(hex: bucket.color))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: bucket.color).opacity(0.1))
                    .cornerRadius(12)
                }
                .accessibilityLabel("Add new budget category")
            }
        }
    }

    private var emptyBudgetsState: some View {
        VStack(spacing: 12) {
            Image(systemName: virtualBucketIcon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text(emptyBudgetsMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Edit allocation button
            Button {
                showEditAllocationSheet = true
            } label: {
                AllocationActionButton(
                    title: "Edit Allocation",
                    icon: "slider.horizontal.3",
                    color: Color(hex: bucket.color)
                )
            }
            .accessibilityLabel("Edit allocation amount")

            // View transactions button (disabled for virtual buckets)
            if !linkedBudgets.isEmpty {
                NavigationLink {
                    // In a real implementation, this would navigate to TransactionsListView
                    // filtered by this bucket's categories
                    Text("Transactions view coming soon")
                        .navigationTitle("Transactions")
                } label: {
                    AllocationActionButton(
                        title: "View Transaction History",
                        icon: "list.bullet.rectangle",
                        color: .blue
                    )
                }
                .accessibilityLabel("View transaction history")
            }

            // Emergency fund contribute button
            if bucket.type == .emergencyFund {
                Button {
                    // Would open contribute sheet
                } label: {
                    AllocationActionButton(
                        title: "Contribute Now",
                        icon: "plus.circle.fill",
                        color: .green
                    )
                }
                .accessibilityLabel("Contribute to emergency fund")
            }

            // Investments learn more button
            if bucket.type == .investments {
                Button {
                    // Would open learn more sheet or webview
                } label: {
                    AllocationActionButton(
                        title: "Learn More About Investing",
                        icon: "book.fill",
                        color: .purple
                    )
                }
                .accessibilityLabel("Learn more about investing")
            }
        }
    }

    // MARK: - Computed Properties

    private var linkedBudgets: [Budget] {
        guard !bucket.linkedBudgetCategories.isEmpty else { return [] }

        let currentMonth = Date().startOfMonth
        return budgetManager.budgets.filter { budget in
            budget.month == currentMonth &&
            bucket.linkedBudgetCategories.contains(budget.categoryName)
        }
    }

    private var totalSpent: Double {
        linkedBudgets.reduce(0) { $0 + $1.currentSpent }
    }

    private var totalRemaining: Double {
        bucket.allocatedAmount - totalSpent
    }

    private var usagePercentage: Double {
        guard bucket.allocatedAmount > 0 else { return 0 }
        return (totalSpent / bucket.allocatedAmount) * 100
    }

    private var usageColor: Color {
        if usagePercentage >= 100 { return .red }
        if usagePercentage >= 90 { return .orange }
        if usagePercentage >= 75 { return .yellow }
        return .green
    }

    private var emergencyFundGoal: Goal? {
        budgetManager.goals.first { $0.goalType == .emergencyFund && $0.isActive }
    }

    private var virtualBucketIcon: String {
        switch bucket.type {
        case .emergencyFund:
            return "banknote"
        case .investments:
            return "chart.line.uptrend.xyaxis"
        default:
            return "folder"
        }
    }

    private var emptyBudgetsMessage: String {
        switch bucket.type {
        case .emergencyFund:
            return "This is a virtual bucket for emergency savings. Track your progress toward your 6-month safety net above."
        case .investments:
            return "This allocation is for long-term wealth building. Consider setting up automatic transfers to investment accounts."
        default:
            return "No budgets are currently linked to this allocation bucket."
        }
    }

    // MARK: - Helper Methods

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func progressGradient(for progress: Double) -> LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if progress >= 0.5 {
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange, Color.orange.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func statusBadge(text: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundColor(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Linked Budget Card Component

struct LinkedBudgetCard: View {
    let budget: Budget
    let bucketColor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: category name and status badge
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: categoryIcon)
                        .foregroundColor(Color(hex: bucketColor))

                    Text(budget.categoryName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

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

            // Amount display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
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
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geometry.size.width * min(budget.percentUsed / 100, 1.0))
                }
            }
            .frame(height: 6)

            // Remaining amount
            Text("\(formatCurrency(budget.remaining)) remaining")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(budget.categoryName), spent \(formatCurrency(budget.currentSpent)) of \(formatCurrency(budget.monthlyLimit))")
    }

    private var statusColor: Color {
        switch budget.status {
        case .onTrack: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .exceeded: return .red
        }
    }

    private var categoryIcon: String {
        // Map category names to icons
        switch budget.categoryName.lowercased() {
        case let name where name.contains("groceries") || name.contains("food"):
            return "cart.fill"
        case let name where name.contains("rent") || name.contains("housing"):
            return "house.fill"
        case let name where name.contains("utilities"):
            return "bolt.fill"
        case let name where name.contains("transport"):
            return "car.fill"
        case let name where name.contains("insurance"):
            return "shield.fill"
        case let name where name.contains("healthcare") || name.contains("health"):
            return "cross.fill"
        case let name where name.contains("entertainment"):
            return "tv.fill"
        case let name where name.contains("dining") || name.contains("restaurant"):
            return "fork.knife"
        case let name where name.contains("shopping"):
            return "bag.fill"
        case let name where name.contains("travel"):
            return "airplane"
        default:
            return "dollarsign.circle.fill"
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Allocation Action Button Component

struct AllocationActionButton: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .fontWeight(.medium)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
        .foregroundColor(color)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Edit Allocation Sheet

struct EditAllocationSheet: View {
    @ObservedObject var bucket: AllocationBucket
    @ObservedObject var budgetManager: BudgetManager
    @Environment(\.dismiss) var dismiss

    @State private var editedAmount: Double

    init(bucket: AllocationBucket, budgetManager: BudgetManager) {
        self.bucket = bucket
        self.budgetManager = budgetManager
        self._editedAmount = State(initialValue: bucket.allocatedAmount)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Current allocation display
                VStack(spacing: 8) {
                    Text("Current Allocation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(editedAmount))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: bucket.color))

                    Text("\(Int(percentageOfIncome))% of monthly income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adjust Amount")
                        .font(.headline)

                    Slider(
                        value: $editedAmount,
                        in: 0...totalMonthlyIncome,
                        step: 50
                    )
                    .tint(Color(hex: bucket.color))
                }
                .padding()

                Spacer()

                // Save button
                Button {
                    saveChanges()
                } label: {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Edit Allocation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var totalMonthlyIncome: Double {
        // Calculate total from all buckets
        budgetManager.allocationBuckets.reduce(0) { $0 + $1.allocatedAmount }
    }

    private var percentageOfIncome: Double {
        guard totalMonthlyIncome > 0 else { return 0 }
        return (editedAmount / totalMonthlyIncome) * 100
    }

    private func saveChanges() {
        bucket.updateAllocation(amount: editedAmount, percentage: percentageOfIncome)
        dismiss()
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Essential Spending") {
    NavigationStack {
        AllocationBucketDetailView(
            bucket: AllocationBucket(
                type: .essentialSpending,
                allocatedAmount: 3200,
                percentageOfIncome: 64,
                linkedCategories: ["Groceries", "Rent", "Utilities", "Transportation", "Insurance"],
                explanation: "Your essential expenses cover rent, groceries, utilities, and transportation. These are your must-have expenses."
            ),
            budgetManager: {
                let manager = BudgetManager()
                manager.budgets = [
                    Budget(categoryName: "Groceries", monthlyLimit: 400, currentSpent: 320),
                    Budget(categoryName: "Rent", monthlyLimit: 1500, currentSpent: 1500),
                    Budget(categoryName: "Utilities", monthlyLimit: 200, currentSpent: 150),
                    Budget(categoryName: "Transportation", monthlyLimit: 300, currentSpent: 180),
                    Budget(categoryName: "Insurance", monthlyLimit: 250, currentSpent: 250)
                ]
                return manager
            }()
        )
    }
}

#Preview("Emergency Fund") {
    NavigationStack {
        AllocationBucketDetailView(
            bucket: AllocationBucket(
                type: .emergencyFund,
                allocatedAmount: 500,
                percentageOfIncome: 10,
                linkedCategories: [],
                explanation: "Building an emergency fund is crucial for financial security. Aim for 6 months of essential expenses.",
                targetAmount: 19200,
                monthsToTarget: 38
            ),
            budgetManager: {
                let manager = BudgetManager()
                manager.goals = [
                    Goal(
                        name: "Emergency Fund",
                        targetAmount: 19200,
                        currentAmount: 10000,
                        goalType: .emergencyFund,
                        priority: .high
                    )
                ]
                return manager
            }()
        )
    }
}
