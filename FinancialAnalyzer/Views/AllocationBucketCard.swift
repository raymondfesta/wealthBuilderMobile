import SwiftUI

/// Reusable card component for displaying and editing allocation buckets
struct AllocationBucketCard: View {
    @ObservedObject var bucket: AllocationBucket
    let monthlyIncome: Double
    @Binding var editedAmount: Double
    let originalAmount: Double
    let essentialSpendingAmount: Double?
    let allAccounts: [BankAccount]
    var onAmountChanged: ((Double) -> Void)?
    var onReset: (() -> Void)?
    var onEmergencyDurationChanged: ((Int) -> Void)?

    @State private var showingDetailsSheet: Bool = false
    @State private var showingAccountLinkingSheet: Bool = false
    @State private var selectedPresetTier: PresetTier = .recommended
    @State private var selectedEmergencyDuration: Int?

    init(
        bucket: AllocationBucket,
        monthlyIncome: Double,
        editedAmount: Binding<Double>,
        originalAmount: Double? = nil,
        essentialSpendingAmount: Double? = nil,
        allAccounts: [BankAccount] = [],
        onAmountChanged: ((Double) -> Void)? = nil,
        onReset: (() -> Void)? = nil,
        onEmergencyDurationChanged: ((Int) -> Void)? = nil
    ) {
        self.bucket = bucket
        self.monthlyIncome = monthlyIncome
        self._editedAmount = editedAmount
        self.originalAmount = originalAmount ?? editedAmount.wrappedValue
        self.essentialSpendingAmount = essentialSpendingAmount
        self.allAccounts = allAccounts
        self.onAmountChanged = onAmountChanged
        self.onReset = onReset
        self.onEmergencyDurationChanged = onEmergencyDurationChanged

        // Initialize selected tier from bucket
        self._selectedPresetTier = State(initialValue: bucket.selectedPresetTier)
        self._selectedEmergencyDuration = State(initialValue: bucket.selectedEmergencyDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compressed header
            compressedHeader
                .padding(.bottom, DesignTokens.Spacing.lg)

            // Allocation amount section (varies by bucket type)
            allocationSection
                .padding(.bottom, DesignTokens.Spacing.md)

            // Account linking section
            if !allAccounts.isEmpty {
                accountLinkingSection
                    .padding(.bottom, DesignTokens.Spacing.md)
            }

            // Investment projections
            if bucket.type == .investments,
               let projection = bucket.investmentProjection {
                InvestmentProjectionView(
                    projection: projection,
                    selectedTier: selectedPresetTier
                )
                .padding(.bottom, DesignTokens.Spacing.md)
            }

            // Contextual warnings
            if bucket.type == .discretionarySpending {
                discretionarySpendingWarning
                    .padding(.bottom, DesignTokens.Spacing.sm)
            }

            if bucket.type == .investments {
                investmentsWarning
                    .padding(.bottom, DesignTokens.Spacing.sm)
            }

            // "Why This Amount?" button
            whyThisAmountButton
        }
        .padding(DesignTokens.Spacing.lg)
        .primaryCardStyle()
        .sheet(isPresented: $showingDetailsSheet) {
            AllocationDetailsSheet(
                bucket: bucket,
                monthlyIncome: monthlyIncome,
                essentialSpendingAmount: essentialSpendingAmount
            )
        }
        .sheet(isPresented: $showingAccountLinkingSheet) {
            AccountLinkingDetailSheet(
                bucketType: bucket.type,
                allAccounts: allAccounts,
                linkedAccountIds: Binding(
                    get: { bucket.linkedAccountIds },
                    set: { bucket.linkedAccountIds = $0 }
                ),
                linkageMethods: Binding(
                    get: { bucket.accountLinkageMethod },
                    set: { bucket.accountLinkageMethod = $0 }
                ),
                onSave: { ids, methods in
                    bucket.linkedAccountIds = ids
                    bucket.accountLinkageMethod = methods
                    // Recalculate balance
                    updateAccountBalance()
                }
            )
        }
    }

    // MARK: - Subviews

    /// Compressed header with icon, name, and action buttons
    private var compressedHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon (smaller, 32px)
            ZStack {
                Circle()
                    .fill(Color(hex: bucket.color).opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: bucket.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: bucket.color))
            }

            // Bucket name
            Text(bucket.displayName)
                .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                .fontWeight(.semibold)

            // Non-modifiable badge
            if !bucket.isModifiable {
                Text("LOCKED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DesignTokens.Colors.stableBlue.opacity(0.2))
                    .foregroundColor(DesignTokens.Colors.stableBlue)
                    .cornerRadius(DesignTokens.CornerRadius.sm / 2)
            }

            // Auto-adjusted badge (with dismiss button)
            if bucket.hasUnacknowledgedChange {
                HStack(spacing: DesignTokens.Spacing.xxs) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("AUTO-ADJUSTED")
                        .font(.caption2)
                        .fontWeight(.bold)

                    Button {
                        bucket.acknowledgeChange()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 2)
                .background(DesignTokens.Colors.opportunityOrange.opacity(0.2))
                .foregroundColor(DesignTokens.Colors.opportunityOrange)
                .cornerRadius(DesignTokens.CornerRadius.sm / 2)
            }

            Spacer()

            // Info button
            Button {
                showingDetailsSheet = true
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Colors.accentSecondary)
            }
            .accessibilityLabel("Show allocation details")
        }
    }

    /// Allocation amount section - varies by bucket type
    @ViewBuilder
    private var allocationSection: some View {
        switch bucket.type {
        case .emergencyFund:
            // Emergency fund uses duration picker
            if let durationOptions = bucket.emergencyDurationOptions {
                EmergencyFundDurationPicker(
                    durationOptions: durationOptions,
                    selectedDuration: $selectedEmergencyDuration,
                    selectedPresetTier: $selectedPresetTier,
                    onSelectionChange: { months, amount in
                        bucket.selectedEmergencyDuration = months
                        bucket.selectedPresetTier = selectedPresetTier
                        editedAmount = amount
                        onAmountChanged?(amount)
                        onEmergencyDurationChanged?(months)
                    }
                )
            } else {
                // Fallback to simple display
                simpleAmountDisplay
            }

        case .discretionarySpending, .investments:
            // These use preset selectors
            if let presetOptions = bucket.presetOptions {
                AllocationPresetSelector(
                    presetOptions: presetOptions,
                    selectedTier: $selectedPresetTier,
                    onSelectionChange: { amount in
                        bucket.selectedPresetTier = selectedPresetTier
                        editedAmount = amount
                        onAmountChanged?(amount)
                    }
                )
            } else {
                // Fallback to simple display
                simpleAmountDisplay
            }

        case .essentialSpending:
            // Essential spending is locked - just show amount
            lockedAmountDisplay

        case .debtPaydown:
            // Debt uses preset selector (but should use DebtPaydownCard at planner level)
            if let presetOptions = bucket.presetOptions {
                AllocationPresetSelector(
                    presetOptions: presetOptions,
                    selectedTier: $selectedPresetTier,
                    onSelectionChange: { amount in
                        bucket.selectedPresetTier = selectedPresetTier
                        editedAmount = amount
                        onAmountChanged?(amount)
                    }
                )
            } else {
                simpleAmountDisplay
            }
        }
    }

    /// Simple amount display for non-modifiable or fallback cases
    private var simpleAmountDisplay: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text(formatCurrency(editedAmount))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: bucket.color))

                // Change indicator (only if changed)
                if abs(bucket.changeFromOriginal) > 0.01 {
                    changeIndicatorBadge
                        .transition(.scale.combined(with: .opacity))
                }
            }

            // Percentage and description
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("\(Int(percentageOfIncome))%")
                    .title3Style(color: DesignTokens.Colors.textSecondary)

                Text("•")
                    .title3Style(color: DesignTokens.Colors.textSecondary)

                Text(bucket.description)
                    .captionStyle()
                    .lineLimit(1)
            }
        }
    }

    /// Locked amount display for essential spending
    private var lockedAmountDisplay: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(formatCurrency(editedAmount))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: bucket.color))

                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("\(Int(percentageOfIncome))%")
                            .title3Style(color: DesignTokens.Colors.textSecondary)

                        Text("•")
                            .title3Style(color: DesignTokens.Colors.textSecondary)

                        Text(bucket.description)
                            .captionStyle()
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            // Locked explanation
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.stableBlue)
                Text("Based on your actual spending")
                    .captionStyle()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                    .fill(DesignTokens.Colors.stableBlue.opacity(0.1))
            )
        }
    }

    /// Account linking section with balance display
    @ViewBuilder
    private var accountLinkingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(Color(hex: bucket.color))
                Text("Linked Accounts")
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    showingAccountLinkingSheet = true
                } label: {
                    HStack(spacing: DesignTokens.Spacing.xxs) {
                        Text(bucket.linkedAccountIds.isEmpty ? "Link" : "Manage")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(DesignTokens.Colors.accentSecondary)
                }
            }

            // Current balance from linked accounts
            if bucket.currentBalanceFromAccounts > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Balance")
                            .captionStyle()
                        Text(formatCurrency(bucket.currentBalanceFromAccounts))
                            .title3Style(color: Color(hex: bucket.color))
                            .fontWeight(.bold)
                    }

                    Spacer()

                    // Auto-linked badge if applicable
                    if bucket.linkedAccountIds.contains(where: { bucket.accountLinkageMethod[$0] == .automatic }) {
                        Text("AUTO-LINKED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignTokens.Colors.backgroundPrimary)
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 3)
                            .background(DesignTokens.Colors.protectionMint)
                            .cornerRadius(DesignTokens.CornerRadius.sm / 2)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                        .fill(Color(hex: bucket.color).opacity(0.1))
                )
            } else if !bucket.linkedAccountIds.isEmpty {
                // Linked but zero balance
                Text("\(bucket.linkedAccountIds.count) account\(bucket.linkedAccountIds.count == 1 ? "" : "s") linked")
                    .captionStyle()
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(DesignTokens.Colors.cardOverlay1)
                    )
            } else {
                // No accounts linked
                Text("No accounts linked")
                    .captionStyle()
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm)
                            .fill(DesignTokens.Colors.cardOverlay1)
                    )
            }
        }
    }


    /// Button to open details sheet
    private var whyThisAmountButton: some View {
        Button {
            showingDetailsSheet = true
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: bucket.color))

                Text("Why This Amount?")
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.sm)
            .background(Color(hex: bucket.color).opacity(0.05))
            .cornerRadius(DesignTokens.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                    .stroke(Color(hex: bucket.color).opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel("Show allocation details and explanation")
    }


    /// Warning for Investments below recommended minimum
    private var investmentsWarning: some View {
        let recommendedMinimum = bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome)
        let isBelowMinimum = editedAmount < recommendedMinimum

        return Group {
            if isBelowMinimum {
                warningBox(
                    icon: "info.circle.fill",
                    color: .blue,
                    title: "Low Investment Allocation",
                    message: "Allocating at least \(Int(bucket.recommendedMinimumPercentage))% (\(formatCurrency(recommendedMinimum))) to investments helps build long-term wealth and prepare for retirement."
                )
            }
        }
    }

    private var discretionarySpendingWarning: some View {
        let validation = bucket.validateDiscretionarySpending(monthlyIncome: monthlyIncome)

        return Group {
            switch validation {
            case .valid:
                EmptyView()
            case .warning(let percentage):
                warningBox(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "High Discretionary Spending",
                    message: "At \(Int(percentage))% of income. Financial experts recommend keeping this below 35% for better savings and financial flexibility."
                )
            case .hardLimit(let percentage):
                warningBox(
                    icon: "xmark.octagon.fill",
                    color: .red,
                    title: "Discretionary Spending Limit Exceeded",
                    message: "At \(Int(percentage))% of income. Please reduce to 50% or below. Excessive discretionary spending can prevent building emergency funds and achieving financial goals."
                )
            }
        }
    }

    private func warningBox(icon: String, color: Color, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .subheadlineStyle(color: color)
                    .fontWeight(.semibold)
            }

            Text(message)
                .captionStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.md)
        .background(color.opacity(0.1))
        .cornerRadius(DesignTokens.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.md)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var changeIndicatorBadge: some View {
        let change = bucket.changeFromOriginal
        let isIncrease = change > 0
        let arrow = isIncrease ? "↑" : "↓"
        let color: Color = isIncrease ? DesignTokens.Colors.progressGreen : DesignTokens.Colors.opportunityOrange

        return HStack(spacing: 2) {
            Text(arrow)
                .font(.caption)
                .fontWeight(.bold)
            Text(formatCurrency(abs(change)))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, DesignTokens.Spacing.xxs)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(DesignTokens.CornerRadius.sm)
        .accessibilityLabel("\(isIncrease ? "Increased" : "Decreased") by \(formatCurrency(abs(change)))")
    }

    // MARK: - Computed Properties

    private var percentageOfIncome: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (editedAmount / monthlyIncome) * 100
    }

    private var hasChanged: Bool {
        abs(editedAmount - originalAmount) > 0.01
    }

    // MARK: - Helper Methods

    private func updateAmount(_ newAmount: Double) {
        // Guard against modifying non-modifiable buckets (defense in depth)
        guard bucket.isModifiable else {
            print("⚠️ [AllocationBucketCard] Attempted to modify non-modifiable bucket: \(bucket.displayName)")
            return
        }

        print("   🔄 [AllocationBucketCard] \(bucket.displayName) updateAmount: \(formatCurrency(editedAmount)) → \(formatCurrency(newAmount))")

        editedAmount = newAmount
        onAmountChanged?(newAmount)
    }


    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func updateAccountBalance() {
        let linkingService = AccountLinkingService()
        bucket.currentBalanceFromAccounts = linkingService.calculateBucketBalance(
            for: bucket.type,
            linkedAccountIds: bucket.linkedAccountIds,
            accounts: allAccounts
        )
    }
}

// MARK: - Flow Layout for Category Pills

/// Simple flow layout for wrapping category chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowLayoutResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowLayoutResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }

    struct FlowLayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))

                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview("Allocation Bucket Card") {
    let emergencyBucket = AllocationBucket(
        type: .emergencyFund,
        allocatedAmount: 500,
        percentageOfIncome: 10,
        linkedCategories: [],
        explanation: "Building an emergency fund is crucial. Based on your essential expenses of $4,200/month, we recommend saving $500/month to reach a 6-month safety net in 4.2 years.",
        targetAmount: 25200,
        monthsToTarget: 50
    )

    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            AllocationBucketCard(
                bucket: emergencyBucket,
                monthlyIncome: 5000,
                editedAmount: .constant(500)
            )

            AllocationBucketCard(
                bucket: AllocationBucket(
                    type: .essentialSpending,
                    allocatedAmount: 3200,
                    percentageOfIncome: 64,
                    linkedCategories: ["Rent", "Groceries", "Utilities", "Transportation", "Insurance"],
                    explanation: "Your essential expenses include rent, groceries, utilities, transportation, and insurance. This allocation covers your non-negotiable monthly costs."
                ),
                monthlyIncome: 5000,
                editedAmount: .constant(3200)
            )
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}
