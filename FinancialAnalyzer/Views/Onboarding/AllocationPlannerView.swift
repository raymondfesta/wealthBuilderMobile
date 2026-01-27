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
                    VStack(spacing: DesignTokens.Spacing.xl) {
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
                    .padding(DesignTokens.Spacing.md)
                }

                // Sticky bottom button
                VStack {
                    Spacer()
                    createPlanButton
                        .padding(DesignTokens.Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [DesignTokens.Colors.backgroundPrimary.opacity(0), DesignTokens.Colors.backgroundPrimary],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
            .primaryBackgroundGradient()
            .navigationTitle("Build Your Plan")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
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
        GlassmorphicCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Main instruction
                Text("Allocate your \(formatCurrency(monthlyIncome)) monthly income")
                    .title3Style()

                Text("Adjust each category below to create your personalized financial plan. Your total must equal 100%.")
                    .subheadlineStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var edgeCaseWarnings: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
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
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Text(title)
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .fontWeight(.semibold)

                Text(message)
                    .captionStyle()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private var bucketsSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
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
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Bucket dots (visual allocation summary)
            HStack(spacing: DesignTokens.Spacing.xs) {
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
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text(formatCurrency(totalAllocated))
                    .headlineStyle(color: isValid ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.opportunityOrange)

                Text("/ \(formatCurrency(monthlyIncome))")
                    .subheadlineStyle()
            }

            Spacer()

            // Percentage with icon
            HStack(spacing: DesignTokens.Spacing.xxs) {
                Text("\(Int(allocationPercentage))%")
                    .headlineStyle(color: isValid ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.opportunityOrange)

                Image(systemName: isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundColor(isValid ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.opportunityOrange)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .primaryCardStyle()
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg)
                .stroke(isValid ? DesignTokens.Colors.progressGreen.opacity(0.3) : DesignTokens.Colors.opportunityOrange.opacity(0.5), lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: totalAllocated)
    }

    private var createPlanButton: some View {
        PrimaryButton(
            title: "Create My Financial Plan",
            action: {
                if isValid {
                    createPlan()
                } else {
                    showValidationError()
                }
            },
            isDisabled: !isValid,
            isLoading: viewModel.isLoading
        )
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
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("How We Calculate Your Monthly Income")
                            .title3Style()

                        Text("Understanding where this number comes from")
                            .subheadlineStyle()
                    }

                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)

                    // Main explanation
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title2)
                                .foregroundColor(DesignTokens.Colors.progressGreen)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                Text("Monthly Income")
                                    .headlineStyle()

                                Text(formatCurrency(monthlyIncome))
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(DesignTokens.Colors.progressGreen)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.progressGreen.opacity(0.1))
                        .cornerRadius(DesignTokens.CornerRadius.md)

                        // Calculation explanation
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Calculation Method")
                                .headlineStyle()

                            if let summary = viewModel.summary {
                                Text("Your monthly income of \(formatCurrency(monthlyIncome)) is calculated as the average of positive transactions (deposits, paychecks, transfers in) over the past \(summary.monthsAnalyzed) months based on \(summary.totalTransactions) transactions analyzed.")
                                    .subheadlineStyle()
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Breakdown box
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("What's Included:")
                                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                                    .fontWeight(.semibold)

                                Label("Paycheck deposits", systemImage: "checkmark.circle.fill")
                                    .captionStyle()

                                Label("Direct deposits", systemImage: "checkmark.circle.fill")
                                    .captionStyle()

                                Label("Bank transfers (incoming)", systemImage: "checkmark.circle.fill")
                                    .captionStyle()

                                Label("Other positive transactions", systemImage: "checkmark.circle.fill")
                                    .captionStyle()
                            }
                            .padding(DesignTokens.Spacing.md)
                            .primaryCardStyle()
                        }

                        // Analysis period
                        if let summary = viewModel.summary {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text("Analysis Period")
                                    .headlineStyle()

                                HStack {
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                                        Text("Months Analyzed")
                                            .captionStyle()
                                        Text("\(summary.monthsAnalyzed)")
                                            .title3Style()
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xxs) {
                                        Text("Total Transactions")
                                            .captionStyle()
                                        Text("\(summary.totalTransactions)")
                                            .title3Style()
                                    }
                                }
                                .padding(DesignTokens.Spacing.md)
                                .primaryCardStyle()
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .primaryBackgroundGradient()
            .navigationTitle("Monthly Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingIncomeExplanation = false
                    }
                    .foregroundColor(DesignTokens.Colors.accentPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
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
        vm.summary = AnalysisSnapshot(
            monthlyFlow: MonthlyFlow(
                income: 5000,
                essentialExpenses: 4200,
                debtMinimums: 0
            ),
            position: FinancialPosition(
                emergencyCash: 0,
                totalDebt: 0,
                investmentBalances: 0,
                monthlyInvestmentContributions: 0
            ),
            metadata: AnalysisMetadata(
                monthsAnalyzed: 6,
                accountsConnected: 3,
                transactionsAnalyzed: 150,
                transactionsNeedingValidation: 0,
                overallConfidence: 0.9,
                lastUpdated: Date()
            )
        )

        return vm
    }()

    AllocationPlannerView(viewModel: viewModel)
}
