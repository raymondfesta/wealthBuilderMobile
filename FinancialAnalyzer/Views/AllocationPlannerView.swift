import SwiftUI

/// Main view for reviewing and customizing allocation recommendations
struct AllocationPlannerView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @StateObject private var editorViewModel = AllocationEditorViewModel()

    @State private var showingValidationError: Bool = false
    @State private var validationMessage: String = ""
    @State private var showingIncomeExplanation: Bool = false
    @State private var rebalanceAdjustments: [AllocationAdjustment]? = nil
    @State private var showRebalanceToast: Bool = false
    @State private var showingScheduleSetup: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header section
                        headerSection

                        // Edge case warnings
                        edgeCaseWarnings

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
            .sheet(isPresented: $showingScheduleSetup) {
                PaycheckScheduleSetupView(viewModel: viewModel)
            }
            .onAppear {
                initializeEditedBuckets()
            }
            .rebalanceToast(
                adjustments: $rebalanceAdjustments,
                isPresented: $showRebalanceToast
            )
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main instruction
            Text("Allocate your \(formatCurrency(monthlyIncome)) monthly income")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Adjust each category below to create your personalized financial plan. Your total must equal 100%.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    @ViewBuilder
    private var edgeCaseWarnings: some View {
        VStack(spacing: 12) {
            // High essential spending warning
            if let essentialBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .essentialSpending }) {
                let detection = editorViewModel.detectHighEssentialSpending(
                    essentialBucketId: essentialBucket.id,
                    monthlyIncome: monthlyIncome
                )
                if detection.isHigh {
                    warningBanner(
                        icon: "exclamationmark.triangle.fill",
                        title: "High Essential Spending",
                        message: "Your essential expenses are \(Int(detection.percentage))% of income. Consider reviewing your essential categories to find savings opportunities.",
                        color: .orange
                    )
                }
            }

            // Low discretionary spending warning
            if let discretionaryBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .discretionarySpending }) {
                let detection = editorViewModel.detectLowDiscretionarySpending(
                    discretionaryBucketId: discretionaryBucket.id,
                    monthlyIncome: monthlyIncome
                )
                if detection.isTooLow {
                    warningBanner(
                        icon: "info.circle.fill",
                        title: "Low Discretionary Spending",
                        message: "You've allocated only \(Int(detection.percentage))% for discretionary spending. Make sure you have enough flexibility for quality of life.",
                        color: .blue
                    )
                }
            }

            // Insufficient emergency fund warning
            if let emergencyBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .emergencyFund }) {
                let detection = editorViewModel.detectInsufficientEmergencyFund(
                    emergencyBucketId: emergencyBucket.id,
                    monthlyIncome: monthlyIncome
                )
                if detection.isInsufficient {
                    warningBanner(
                        icon: "exclamationmark.shield.fill",
                        title: "Low Emergency Fund Allocation",
                        message: "Your emergency fund allocation is only \(Int(detection.percentage))% of income. Consider increasing this to build financial security faster.",
                        color: .red
                    )
                }
            }
        }
    }

    private func warningBanner(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private var bucketsSection: some View {
        VStack(spacing: 20) {
            ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                AllocationBucketCard(
                    bucket: bucket,
                    monthlyIncome: monthlyIncome,
                    editedAmount: editorViewModel.binding(
                        for: bucket.id,
                        defaultValue: bucket.allocatedAmount
                    ),
                    originalAmount: editorViewModel.originalAmounts[bucket.id] ?? bucket.allocatedAmount,
                    essentialSpendingAmount: essentialSpendingAmount,
                    allAccounts: viewModel.accounts,
                    onAmountChanged: { newAmount in
                        let adjustments = editorViewModel.updateBucket(
                            id: bucket.id,
                            newAmount: newAmount,
                            monthlyIncome: monthlyIncome,
                            allBuckets: viewModel.budgetManager.allocationBuckets
                        )

                        // Show toast if there were auto-adjustments
                        if !adjustments.isEmpty {
                            rebalanceAdjustments = adjustments
                            withAnimation {
                                showRebalanceToast = true
                            }
                        }
                    },
                    onReset: {
                        editorViewModel.resetBucket(id: bucket.id)
                    },
                    onEmergencyDurationChanged: { newDuration in
                        handleEmergencyDurationChange(bucket: bucket, newDuration: newDuration)
                    }
                )
            }
        }
    }

    private var validationBar: some View {
        HStack(spacing: 12) {
            // Bucket dots (visual allocation summary)
            HStack(spacing: 6) {
                ForEach(viewModel.budgetManager.allocationBuckets) { bucket in
                    let currentAmount = editorViewModel.bucketAmounts[bucket.id] ?? bucket.allocatedAmount
                    Circle()
                        .fill(Color(hex: bucket.color))
                        .frame(width: 8, height: 8)
                        .opacity(currentAmount > 0 ? 1.0 : 0.3)
                }
            }

            Divider()
                .frame(height: 20)

            // Allocated vs total
            HStack(spacing: 4) {
                Text(formatCurrency(totalAllocated))
                    .font(.headline)
                    .foregroundColor(isValid ? .primary : .orange)

                Text("/ \(formatCurrency(monthlyIncome))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Percentage with icon
            HStack(spacing: 4) {
                Text("\(Int(allocationPercentage))%")
                    .font(.headline)
                    .foregroundColor(isValid ? .green : .orange)

                Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundColor(isValid ? .green : .orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isValid ? Color.green.opacity(0.3) : Color.orange.opacity(0.5), lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: totalAllocated)
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
        return editorViewModel.bucketAmounts[essentialBucket.id] ?? essentialBucket.allocatedAmount
    }

    private var totalAllocated: Double {
        return editorViewModel.totalAllocated
    }

    private var allocationPercentage: Double {
        return editorViewModel.allocationPercentage(monthlyIncome: monthlyIncome)
    }

    private var isValid: Bool {
        return editorViewModel.isValid(
            monthlyIncome: monthlyIncome,
            allBuckets: viewModel.budgetManager.allocationBuckets
        )
    }

    private var validationErrorMessage: String {
        // Check discretionary spending first
        if let discretionaryBucket = viewModel.budgetManager.allocationBuckets.first(where: { $0.type == .discretionarySpending }) {
            let validation = discretionaryBucket.validateDiscretionarySpending(monthlyIncome: monthlyIncome)
            if !validation.isValid {
                return validation.message
            }
        }

        // Check allocation total
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
        editorViewModel.initialize(buckets: viewModel.budgetManager.allocationBuckets)
    }

    private func handleEmergencyDurationChange(bucket: AllocationBucket, newDuration: Int) {
        // Update the bucket's selected emergency duration
        bucket.selectedEmergencyDuration = newDuration

        // Find the selected duration option to get the recommended target amount
        if let selectedOption = bucket.emergencyDurationOptions?.first(where: { $0.months == newDuration }) {
            // Get the recommended preset for this duration
            let recommendedAmount = selectedOption.monthlyContribution.value(for: .recommended).amount

            // Update the bucket allocation
            let adjustments = editorViewModel.updateBucket(
                id: bucket.id,
                newAmount: recommendedAmount,
                monthlyIncome: monthlyIncome,
                allBuckets: viewModel.budgetManager.allocationBuckets
            )

            // Show toast if there were auto-adjustments
            if !adjustments.isEmpty {
                rebalanceAdjustments = adjustments
                withAnimation {
                    showRebalanceToast = true
                }
            }

            print("🎯 [AllocationPlanner] Emergency duration changed to \(newDuration) months, new target: $\(Int(recommendedAmount))")
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
            (editorViewModel.bucketAmounts[$0.id] ?? $0.allocatedAmount) < (editorViewModel.bucketAmounts[$1.id] ?? $1.allocatedAmount)
        }) {
            // Calculate sum of all OTHER buckets
            var otherBucketsTotal = 0.0
            for bucket in viewModel.budgetManager.allocationBuckets where bucket.id != largestBucket.id {
                otherBucketsTotal += editorViewModel.bucketAmounts[bucket.id] ?? bucket.allocatedAmount
            }
            // Largest bucket gets exactly the remainder to guarantee 100%
            let remainingAmount = monthlyIncome - otherBucketsTotal

            // Safety check: Don't allow negative values
            if remainingAmount < 0 {
                print("⚠️ [AllocationPlanner] Warning: Final adjustment would make \(largestBucket.displayName) negative ($\(remainingAmount)). Aborting save.")
                showValidationError()
                return
            }

            editorViewModel.bucketAmounts[largestBucket.id] = remainingAmount
        }

        // Final safety check: ensure no negative values before saving
        for bucket in viewModel.budgetManager.allocationBuckets {
            let amount = editorViewModel.bucketAmounts[bucket.id] ?? bucket.allocatedAmount
            if amount < 0 {
                print("⚠️ [AllocationPlanner] Error: \(bucket.displayName) has negative value ($\(amount)). Aborting save.")
                validationMessage = "\(bucket.displayName) has an invalid negative value. Please adjust allocations."
                showingValidationError = true
                return
            }
        }

        // Update bucket amounts with edited values (now guaranteed to be exactly 100%)
        for bucket in viewModel.budgetManager.allocationBuckets {
            if let editedAmount = editorViewModel.bucketAmounts[bucket.id] {
                let newPercentage = (editedAmount / monthlyIncome) * 100
                bucket.updateAllocation(amount: editedAmount, percentage: newPercentage)
            }
        }

        // Call confirm method
        Task {
            await viewModel.confirmAllocationPlan()

            // After successful plan creation, present schedule setup
            await MainActor.run {
                showingScheduleSetup = true
            }
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

    AllocationPlannerView(viewModel: viewModel)
}
