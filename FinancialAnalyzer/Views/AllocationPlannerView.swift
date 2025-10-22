import SwiftUI

/// Main view for reviewing and customizing allocation recommendations
struct AllocationPlannerView: View {
    @ObservedObject var viewModel: FinancialViewModel

    @State private var editedBuckets: [String: Double] = [:] // bucketId -> amount
    @State private var originalAmounts: [String: Double] = [:] // bucketId -> original suggested amount
    @State private var showingValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var showingIncomeExplanation: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section
                        headerSection

                        // Allocation bucket cards
                        bucketsSection

                        // Validation bar
                        validationBar

                        // Spacer for bottom button
                        Spacer().frame(height: 100)
                    }
                    .padding()
                }

                // Sticky bottom button
                VStack {
                    Spacer()
                    createPlanButton
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .navigationTitle("Build Your Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Return to analysis complete state
                        viewModel.userJourneyState = .analysisComplete
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Close allocation planner")
                }
            }
            .alert("Allocation Error", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) {
                    showingValidationError = false
                }
            } message: {
                Text(validationMessage)
            }
            .sheet(isPresented: $showingIncomeExplanation) {
                incomeExplanationSheet
            }
            .onAppear {
                initializeEditedBuckets()
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Monthly income display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Income")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(monthlyIncome))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Info icon
                Button {
                    showingIncomeExplanation = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Income information")
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundColor(.blue)
                    Text("Customize Your Allocations")
                        .font(.headline)
                }

                Text("Adjust the sliders below to allocate your monthly income across 4 financial priorities. Your total must equal 100% of your income.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var bucketsSection: some View {
        VStack(spacing: 20) {
            ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                AllocationBucketCard(
                    bucket: bucket,
                    monthlyIncome: monthlyIncome,
                    editedAmount: bindingForBucket(bucket),
                    originalAmount: originalAmounts[bucket.id] ?? bucket.allocatedAmount,
                    essentialSpendingAmount: essentialSpendingAmount,
                    onAmountChanged: { newAmount in
                        handleAmountChanged(bucketId: bucket.id, newAmount: newAmount)
                    },
                    onReset: {
                        resetBucket(bucketId: bucket.id)
                    }
                )
            }
        }
    }

    private var validationBar: some View {
        VStack(spacing: 12) {
            // Total display
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Allocated")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(totalAllocated))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(isValid ? .green : .orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Percentage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Text("\(Int(allocationPercentage))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(isValid ? .green : .orange)

                        Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title2)
                            .foregroundColor(isValid ? .green : .orange)
                    }
                }
            }
            .padding()
            .background(isValid ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isValid ? Color.green : Color.orange, lineWidth: 2)
            )

            // Validation message
            if !isValid {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)

                    Text(validationErrorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private var createPlanButton: some View {
        Button {
            if isValid {
                createPlan()
            } else {
                showValidationError()
            }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create My Financial Plan")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isValid ? Color.blue : Color.gray)
            .cornerRadius(16)
            .shadow(color: isValid ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isValid || viewModel.isLoading)
        .accessibilityLabel("Create financial plan")
        .accessibilityHint(isValid ? "Creates your personalized financial plan" : "Total allocation must equal 100% of income")
    }

    // MARK: - Computed Properties

    private var monthlyIncome: Double {
        guard let summary = viewModel.summary else { return 0 }
        return summary.avgMonthlyIncome
    }

    private var essentialSpendingAmount: Double? {
        guard let essentialBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .essentialSpending }) else {
            return nil
        }
        return editedBuckets[essentialBucket.id] ?? essentialBucket.allocatedAmount
    }

    private var totalAllocated: Double {
        var total = 0.0
        for bucket in viewModel.budgetManager.allocationBuckets {
            if let edited = editedBuckets[bucket.id] {
                total += edited
            } else {
                total += bucket.allocatedAmount
            }
        }
        return total
    }

    private var allocationPercentage: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (totalAllocated / monthlyIncome) * 100
    }

    private var isValid: Bool {
        // Allow 0.1% margin of error for strict 100% enforcement
        let percentDiff = abs(allocationPercentage - 100.0)
        return percentDiff < 0.1
    }

    private var validationErrorMessage: String {
        let difference = totalAllocated - monthlyIncome
        if difference > 0 {
            return "You're over by \(formatCurrency(difference)). Reduce allocations to match your income."
        } else if difference < 0 {
            return "You have \(formatCurrency(abs(difference))) unallocated. Distribute it across your priorities."
        } else {
            return ""
        }
    }

    private var incomeExplanationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How We Calculate Your Monthly Income")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Understanding where this number comes from")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Main explanation
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Income")
                                    .font(.headline)

                                Text(formatCurrency(monthlyIncome))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)

                        // Calculation explanation
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Calculation Method")
                                .font(.headline)

                            if let summary = viewModel.summary {
                                Text("Your monthly income of \(formatCurrency(monthlyIncome)) is calculated as the average of positive transactions (deposits, paychecks, transfers in) over the past \(summary.monthsAnalyzed) months based on \(summary.totalTransactions) transactions analyzed.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Breakdown box
                            VStack(alignment: .leading, spacing: 8) {
                                Text("What's Included:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                Label("Paycheck deposits", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label("Direct deposits", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label("Bank transfers (incoming)", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label("Other positive transactions", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }

                        // Analysis period
                        if let summary = viewModel.summary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Analysis Period")
                                    .font(.headline)

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Months Analyzed")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(summary.monthsAnalyzed)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Total Transactions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(summary.totalTransactions)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Monthly Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingIncomeExplanation = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helper Methods

    private func initializeEditedBuckets() {
        // Initialize with current bucket amounts
        editedBuckets.removeAll()
        originalAmounts.removeAll()
        for bucket in viewModel.budgetManager.allocationBuckets {
            editedBuckets[bucket.id] = bucket.allocatedAmount
            originalAmounts[bucket.id] = bucket.allocatedAmount
        }
    }

    private func bindingForBucket(_ bucket: AllocationBucket) -> Binding<Double> {
        Binding(
            get: {
                editedBuckets[bucket.id] ?? bucket.allocatedAmount
            },
            set: { newValue in
                editedBuckets[bucket.id] = newValue
            }
        )
    }

    private func handleAmountChanged(bucketId: String, newAmount: Double) {
        // Get the bucket that was changed
        guard let changedBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.id == bucketId }) else {
            return
        }

        // Get the old amount
        let oldAmount = editedBuckets[bucketId] ?? changedBucket.allocatedAmount

        // Calculate the delta (how much the user added or removed)
        let delta = newAmount - oldAmount

        print("💰 [AllocationPlanner] Bucket '\(changedBucket.displayName)' changed: \(formatCurrency(oldAmount)) → \(formatCurrency(newAmount)) (delta: \(formatCurrency(delta)))")

        // Update the changed bucket
        editedBuckets[bucketId] = newAmount

        // If delta is zero, no rebalancing needed
        guard abs(delta) > 0.01 else {
            print("   ↳ No rebalancing needed (delta too small)")
            return
        }

        // Get all other modifiable buckets (exclude the changed bucket and Essential Spending)
        let otherModifiableBuckets = viewModel.budgetManager.allocationBuckets.filter { bucket in
            bucket.id != bucketId && bucket.isModifiable
        }

        guard !otherModifiableBuckets.isEmpty else {
            // No other buckets to adjust
            print("   ↳ No other modifiable buckets to adjust")
            return
        }

        print("   ↳ Adjusting \(otherModifiableBuckets.count) other bucket(s):")

        // Calculate total of other modifiable buckets
        var totalOtherBuckets = 0.0
        for bucket in otherModifiableBuckets {
            totalOtherBuckets += editedBuckets[bucket.id] ?? bucket.allocatedAmount
        }

        // If total is zero, distribute delta equally
        if totalOtherBuckets < 0.01 {
            let distributionPerBucket = -delta / Double(otherModifiableBuckets.count)
            for bucket in otherModifiableBuckets {
                let newValue = max(0, distributionPerBucket)
                print("      • \(bucket.displayName): \(formatCurrency(editedBuckets[bucket.id] ?? bucket.allocatedAmount)) → \(formatCurrency(newValue))")
                editedBuckets[bucket.id] = newValue
            }
        } else {
            // Distribute the delta proportionally based on current percentages
            for bucket in otherModifiableBuckets {
                let currentAmount = editedBuckets[bucket.id] ?? bucket.allocatedAmount
                let proportion = currentAmount / totalOtherBuckets
                let adjustment = -delta * proportion
                let newValue = max(0, currentAmount + adjustment)
                print("      • \(bucket.displayName): \(formatCurrency(currentAmount)) → \(formatCurrency(newValue)) (proportion: \(Int(proportion * 100))%)")
                editedBuckets[bucket.id] = newValue
            }
        }

        // Ensure Essential Spending bucket maintains its original amount
        if let essentialBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .essentialSpending }) {
            editedBuckets[essentialBucket.id] = essentialBucket.allocatedAmount
        }

        // Final adjustment: ensure total equals exactly 100% by correcting rounding errors
        // Apply any remaining difference to the largest modifiable bucket (excluding the one just changed)
        let currentTotal = totalAllocated
        let difference = monthlyIncome - currentTotal

        if abs(difference) > 0.01 {
            // Find the largest modifiable bucket that wasn't just changed
            if let largestBucket = otherModifiableBuckets.max(by: {
                (editedBuckets[$0.id] ?? $0.allocatedAmount) < (editedBuckets[$1.id] ?? $1.allocatedAmount)
            }) {
                let currentValue = editedBuckets[largestBucket.id] ?? largestBucket.allocatedAmount
                editedBuckets[largestBucket.id] = max(0, currentValue + difference)
            }
        }

        // CRITICAL: Force SwiftUI to detect dictionary changes
        // SwiftUI only detects when the dictionary reference changes, not individual value updates
        // This triggers @State change detection and updates all bindings/views
        editedBuckets = editedBuckets

        print("   ✅ Total allocation: \(formatCurrency(totalAllocated)) (\(Int(allocationPercentage))%)")
    }

    private func resetBucket(bucketId: String) {
        // Reset to original suggested amount
        if let originalAmount = originalAmounts[bucketId] {
            editedBuckets[bucketId] = originalAmount
        }
    }

    private func showValidationError() {
        validationMessage = validationErrorMessage
        showingValidationError = true
    }

    private func createPlan() {
        // Force exact 100% allocation before saving to prevent floating-point validation failures
        let modifiableBuckets = viewModel.budgetManager.allocationBuckets.filter { $0.isModifiable }
        if let largestBucket = modifiableBuckets.max(by: {
            (editedBuckets[$0.id] ?? $0.allocatedAmount) < (editedBuckets[$1.id] ?? $1.allocatedAmount)
        }) {
            // Calculate sum of all OTHER buckets
            var otherBucketsTotal = 0.0
            for bucket in viewModel.budgetManager.allocationBuckets where bucket.id != largestBucket.id {
                otherBucketsTotal += editedBuckets[bucket.id] ?? bucket.allocatedAmount
            }
            // Largest bucket gets exactly the remainder to guarantee 100%
            editedBuckets[largestBucket.id] = monthlyIncome - otherBucketsTotal
        }

        // Update bucket amounts with edited values (now guaranteed to be exactly 100%)
        for bucket in viewModel.budgetManager.allocationBuckets {
            if let editedAmount = editedBuckets[bucket.id] {
                let newPercentage = (editedAmount / monthlyIncome) * 100
                bucket.updateAllocation(amount: editedAmount, percentage: newPercentage)
            }
        }

        // Call confirm method
        Task {
            await viewModel.confirmAllocationPlan()
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Allocation Planner") {
    let viewModel: FinancialViewModel = {
        let vm = FinancialViewModel()

        // Mock data
        let mockBuckets: [AllocationBucket] = [
            AllocationBucket(
                type: .essentialSpending,
                allocatedAmount: 3200,
                percentageOfIncome: 64,
                linkedCategories: ["Rent", "Groceries", "Utilities", "Transportation"],
                explanation: "Your essential expenses cover rent, groceries, utilities, and transportation."
            ),
            AllocationBucket(
                type: .emergencyFund,
                allocatedAmount: 500,
                percentageOfIncome: 10,
                linkedCategories: [],
                explanation: "Build a 6-month emergency fund for unexpected expenses.",
                targetAmount: 25200,
                monthsToTarget: 50
            ),
            AllocationBucket(
                type: .discretionarySpending,
                allocatedAmount: 800,
                percentageOfIncome: 16,
                linkedCategories: ["Entertainment", "Dining", "Shopping"],
                explanation: "Enjoy life while staying within your budget."
            ),
            AllocationBucket(
                type: .investments,
                allocatedAmount: 500,
                percentageOfIncome: 10,
                linkedCategories: [],
                explanation: "Invest for long-term wealth building and retirement."
            )
        ]

        vm.budgetManager.allocationBuckets = mockBuckets
        vm.summary = FinancialSummary(
            avgMonthlyIncome: 5000,
            avgMonthlyExpenses: 4200,
            totalDebt: 0,
            totalInvested: 0,
            totalCashAvailable: 0,
            availableToSpend: 800,
            monthsAnalyzed: 6,
            totalTransactions: 150,
            lastUpdated: Date()
        )

        return vm
    }()

    return AllocationPlannerView(viewModel: viewModel)
}
