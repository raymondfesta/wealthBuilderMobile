import SwiftUI

/// Reusable card component for displaying and editing allocation buckets
struct AllocationBucketCard: View {
    @ObservedObject var bucket: AllocationBucket
    let monthlyIncome: Double
    @Binding var editedAmount: Double
    let originalAmount: Double
    let essentialSpendingAmount: Double?
    var onAmountChanged: ((Double) -> Void)?
    var onReset: (() -> Void)?

    @State private var showingDetailsSheet: Bool = false
    @State private var localAmount: Double = 0
    @State private var debounceTask: Task<Void, Never>? = nil

    // Initialize local amount from editedAmount
    init(bucket: AllocationBucket, monthlyIncome: Double, editedAmount: Binding<Double>, originalAmount: Double? = nil, essentialSpendingAmount: Double? = nil, onAmountChanged: ((Double) -> Void)? = nil, onReset: (() -> Void)? = nil) {
        self.bucket = bucket
        self.monthlyIncome = monthlyIncome
        self._editedAmount = editedAmount
        self.originalAmount = originalAmount ?? editedAmount.wrappedValue
        self.essentialSpendingAmount = essentialSpendingAmount
        self.onAmountChanged = onAmountChanged
        self.onReset = onReset
        self._localAmount = State(initialValue: editedAmount.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compressed header
            compressedHeader
                .padding(.bottom, 20)

            // Hero number display
            heroNumberSection
                .padding(.bottom, 16)

            // All modifiable buckets: Show custom slider
            if bucket.isModifiable {
                customSliderSection
                    .padding(.bottom, 12)
            }

            // Emergency Fund: Show coverage info
            if bucket.type == .emergencyFund {
                emergencyFundInfoDisplay
                    .padding(.bottom, 12)
            }

            // Contextual warnings
            if bucket.type == .discretionarySpending {
                discretionarySpendingWarning
                    .padding(.bottom, 12)
            }

            if bucket.type == .emergencyFund {
                emergencyFundWarning
                    .padding(.bottom, 12)
            }

            if bucket.type == .investments {
                investmentsWarning
                    .padding(.bottom, 12)
            }

            // "Why This Amount?" button
            whyThisAmountButton
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingDetailsSheet) {
            AllocationDetailsSheet(
                bucket: bucket,
                monthlyIncome: monthlyIncome,
                essentialSpendingAmount: essentialSpendingAmount
            )
        }
        .onChange(of: editedAmount) { newValue in
            // Sync localAmount when parent updates the binding (e.g., auto-adjustment of other buckets)
            if abs(localAmount - newValue) > 0.01 {
                localAmount = newValue
            }
        }
    }

    // MARK: - Subviews

    /// Compressed header with icon, name, and action buttons
    private var compressedHeader: some View {
        HStack(spacing: 12) {
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
                .font(.subheadline)
                .fontWeight(.semibold)

            // Non-modifiable badge
            if !bucket.isModifiable {
                Text("LOCKED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }

            Spacer()

            // Lock toggle button (for modifiable buckets)
            if bucket.isModifiable {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        bucket.isLocked.toggle()
                    }
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Image(systemName: bucket.isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.subheadline)
                        .foregroundColor(bucket.isLocked ? .orange : .secondary)
                        .rotationEffect(.degrees(bucket.isLocked ? 0 : 15))
                }
                .accessibilityLabel(bucket.isLocked ? "Unlock bucket" : "Lock bucket")
            }

            // Info button
            Button {
                showingDetailsSheet = true
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .accessibilityLabel("Show allocation details")
        }
    }

    /// Hero number section - makes the amount the visual focal point
    private var heroNumberSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Amount - largest element (48pt)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatCurrency(editedAmount))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: bucket.color))

                // Change indicator (only if changed)
                if bucket.isModifiable && abs(bucket.changeFromOriginal) > 0.01 {
                    changeIndicatorBadge
                        .transition(.scale.combined(with: .opacity))
                }

                // Reset button (if changed)
                if bucket.isModifiable && hasChanged && onReset != nil {
                    Button {
                        onReset?()
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Reset to suggested amount")
                }
            }

            // Percentage and description
            HStack(spacing: 8) {
                Text("\(Int(percentageOfIncome))%")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("•")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(bucket.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// Custom slider section with color-coded safety zones
    private var customSliderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Custom slider with safety zones
            CustomSlider(
                value: $localAmount,
                in: 0...monthlyIncome,
                step: 50,
                recommendedValue: bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome),
                warningThreshold: bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome) * 0.5,
                hardLimit: bucket.getMaxSafeAllocation(monthlyIncome: monthlyIncome, otherBuckets: []),
                color: Color(hex: bucket.color),
                onEditingChanged: { editing in
                    if !editing {
                        updateAmount(localAmount)
                    }
                }
            )

            // Min/Max labels
            HStack {
                Text("$0")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatCurrency(monthlyIncome))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Emergency Fund information display - shows coverage and time to goal
    private var emergencyFundInfoDisplay: some View {
        Group {
            if let essentialSpending = essentialSpendingAmount, essentialSpending > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    // Coverage and Goal metrics
                    HStack(spacing: 16) {
                        // Current Coverage
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Coverage")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            let monthsCovered = editedAmount / essentialSpending
                            Text(String(format: "%.1f months", monthsCovered))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(monthsCovered >= 6 ? .green : .orange)
                        }

                        Spacer()

                        // Time to 6-month goal
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("To 6-Month Goal")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            let targetAmount = essentialSpending * 6.0
                            let monthsToGoal = editedAmount > 0 ? Int(ceil(targetAmount / editedAmount)) : 0
                            Text("\(monthsToGoal) months")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)

                    // Explanation text
                    Text("At \(formatCurrency(editedAmount))/month, you're building an emergency fund to cover 6 months of essential expenses (\(formatCurrency(essentialSpending))/month).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(hex: bucket.color).opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: bucket.color).opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel("Show allocation details and explanation")
    }

    /// Warning for Emergency Fund below recommended minimum
    private var emergencyFundWarning: some View {
        let recommendedMinimum = bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome)
        let isBelowMinimum = editedAmount < recommendedMinimum

        return Group {
            if isBelowMinimum {
                warningBox(
                    icon: "exclamationmark.triangle.fill",
                    color: .orange,
                    title: "Below Recommended Minimum",
                    message: "Your emergency fund allocation is below the recommended \(Int(bucket.recommendedMinimumPercentage))% (\(formatCurrency(recommendedMinimum))). Consider increasing this for better financial security."
                )
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }

    private var changeIndicatorBadge: some View {
        let change = bucket.changeFromOriginal
        let isIncrease = change > 0
        let arrow = isIncrease ? "↑" : "↓"
        let color: Color = isIncrease ? .green : .orange

        return HStack(spacing: 2) {
            Text(arrow)
                .font(.caption)
                .fontWeight(.bold)
            Text(formatCurrency(abs(change)))
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(8)
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
        VStack(spacing: 20) {
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
        .padding()
    }
}
