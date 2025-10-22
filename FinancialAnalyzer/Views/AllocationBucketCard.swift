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

    @State private var isExpanded: Bool = false
    @State private var showingExplanation: Bool = false
    @State private var localAmount: Double = 0
    @State private var isEditingTextField: Bool = false
    @State private var emergencyFundMonths: Int = 6 // For Emergency Fund duration picker

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

        // Initialize emergency fund months from bucket target (prevents race condition)
        if bucket.type == .emergencyFund,
           let targetAmount = bucket.targetAmount,
           let essentialSpending = essentialSpendingAmount,
           essentialSpending > 0 {
            let months = Int(round(targetAmount / essentialSpending))
            // Map to closest valid value (3, 6, or 12)
            if months <= 4 {
                self._emergencyFundMonths = State(initialValue: 3)
            } else if months <= 9 {
                self._emergencyFundMonths = State(initialValue: 6)
            } else {
                self._emergencyFundMonths = State(initialValue: 12)
            }
        } else {
            self._emergencyFundMonths = State(initialValue: 6)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Icon, Name, Amount, Percentage
            headerSection

            // Emergency Fund: Show Target Duration picker instead of slider
            if bucket.type == .emergencyFund {
                emergencyFundDurationPicker
            }
            // Other modifiable buckets: Show slider and text field
            else if bucket.isModifiable {
                sliderSection
                textFieldSection
            }

            // Expand/collapse button
            expandButton

            // Expandable details section (inside card)
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)

                expandedDetailsContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
        .onChange(of: editedAmount) { newValue in
            // Sync localAmount when parent updates the binding (e.g., auto-adjustment of other buckets)
            // Only update if there's a meaningful difference to avoid fighting with user input
            if abs(localAmount - newValue) > 0.01 {
                localAmount = newValue
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(Color(hex: bucket.color).opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: bucket.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: bucket.color))
            }

            // Name and amount
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(bucket.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    // Non-modifiable badge
                    if !bucket.isModifiable {
                        Text("CALCULATED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                Text(bucket.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Spacer().frame(height: 4)

                // Current allocated amount with reset button
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(formatCurrency(editedAmount))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: bucket.color))

                    // Show reset button if amount changed and bucket is modifiable
                    if bucket.isModifiable && hasChanged && onReset != nil {
                        Button {
                            onReset?()
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                        .accessibilityLabel("Reset to suggested amount")
                    }
                }

                // Percentage of income
                Text("\(Int(percentageOfIncome))% of monthly income")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bucket.displayName), \(formatCurrency(editedAmount)), \(Int(percentageOfIncome))% of income")
    }

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bucket.isModifiable ? "Adjust Allocation" : "Calculated Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                if !bucket.isModifiable {
                    Spacer()
                    Text("Based on your actual spending data")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            HStack(spacing: 12) {
                Text("$0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .leading)

                Slider(
                    value: $localAmount,
                    in: 0...(monthlyIncome),
                    step: 50,
                    onEditingChanged: { editing in
                        if !editing {
                            // User finished sliding
                            updateAmount(localAmount)
                        }
                    }
                )
                .tint(Color(hex: bucket.color))
                .disabled(!bucket.isModifiable)
                .opacity(bucket.isModifiable ? 1.0 : 0.5)
                .accessibilityLabel("Allocation amount slider")
                .accessibilityValue("\(formatCurrency(localAmount))")
                .accessibilityHint(bucket.isModifiable ? "Adjust the amount allocated to \(bucket.displayName)" : "This amount is calculated and cannot be changed")

                Text(formatCurrency(monthlyIncome))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private var textFieldSection: some View {
        HStack {
            Text("Precise Amount:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Text("$")
                    .foregroundColor(.secondary)

                TextField("0", value: $localAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .multilineTextAlignment(.trailing)
                    .disabled(!bucket.isModifiable)
                    .opacity(bucket.isModifiable ? 1.0 : 0.7)
                    .onChange(of: localAmount) { newValue in
                        // Clamp to valid range
                        if newValue > monthlyIncome {
                            localAmount = monthlyIncome
                        } else if newValue < 0 {
                            localAmount = 0
                        }
                        updateAmount(localAmount)
                    }
                    .accessibilityLabel("Precise allocation amount")
                    .accessibilityHint(bucket.isModifiable ? "Enter exact dollar amount for \(bucket.displayName)" : "This amount is calculated and cannot be changed")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .opacity(bucket.isModifiable ? 1.0 : 0.7)
    }

    private var emergencyFundDurationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Duration picker header
            HStack {
                Text("Target Duration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if let essentialSpending = essentialSpendingAmount {
                    Text("Based on \(formatCurrency(essentialSpending))/mo essential")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            // Segmented picker for months
            Picker("Emergency Fund Months", selection: $emergencyFundMonths) {
                Text("3 months").tag(3)
                Text("6 months").tag(6)
                Text("12 months").tag(12)
            }
            .pickerStyle(.segmented)
            .onChange(of: emergencyFundMonths) { newValue in
                print("🎯 [EmergencyFund] Picker changed to \(newValue) months")
                // Calculate new allocated amount based on target and savings period
                if let essentialSpending = essentialSpendingAmount {
                    // Target = essential spending × selected months
                    let targetAmount = essentialSpending * Double(newValue)

                    // Assume 2-year savings period (24 months) as reasonable default
                    let savingsPeriodMonths = 24.0

                    // Monthly allocation = target / savings period
                    let newAmount = targetAmount / savingsPeriodMonths

                    // Clamp to valid range (0 to monthly income)
                    let clampedAmount = min(max(newAmount, 0), monthlyIncome)
                    print("   ↳ Calculated new amount: \(formatCurrency(clampedAmount))")
                    localAmount = clampedAmount
                    updateAmount(clampedAmount)
                } else {
                    print("   ⚠️ Essential spending amount not available, cannot calculate")
                }
            }

            // Show calculated target
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emergency Fund Target")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let essentialSpending = essentialSpendingAmount {
                        Text(formatCurrency(essentialSpending * Double(emergencyFundMonths)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Monthly Allocation")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(editedAmount))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: bucket.color))
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(.vertical, 8)
        .accessibilityLabel("Emergency fund target duration")
        .accessibilityValue("\(emergencyFundMonths) months")
    }

    private var expandButton: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color(hex: bucket.color))

                Text(isExpanded ? "Hide Details" : "Why This Amount?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: bucket.color))

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .accessibilityLabel(isExpanded ? "Hide allocation details" : "Show allocation details")
    }

    private var expandedDetailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // AI Explanation
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("AI Recommendation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Text(bucket.explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color.purple.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )

            // Emergency Fund specific details
            if bucket.type == .emergencyFund,
               let targetAmount = bucket.targetAmount,
               let monthsToTarget = bucket.monthsToTarget {
                emergencyFundDetails(targetAmount: targetAmount, monthsToTarget: monthsToTarget)
            }

            // Linked categories (for spending buckets)
            if !bucket.linkedBudgetCategories.isEmpty {
                linkedCategoriesSection
            }
        }
    }

    private func emergencyFundDetails(targetAmount: Double, monthsToTarget: Int) -> some View {
        // Use the target amount from the bucket (already calculated)
        let calculatedTarget = targetAmount
        let calculatedMonthsToTarget = calculatedTarget > 0 && editedAmount > 0 ? Int(ceil(calculatedTarget / editedAmount)) : 0
        // Derive the months from the target amount and essential spending
        let targetMonths = essentialSpendingAmount ?? 0 > 0 ? Int(calculatedTarget / (essentialSpendingAmount ?? 1)) : 6

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Emergency Fund Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Calculation breakdown
            if let essentialSpending = essentialSpendingAmount {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calculation")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Essential Spending:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatCurrency(essentialSpending))/month")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("× \(targetMonths) months")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("=")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Amount:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(formatCurrency(calculatedTarget))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Current contribution and timeline
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Contribution:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(editedAmount))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                HStack {
                    Text("Time to Reach Goal:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(calculatedMonthsToTarget) months")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                // Progress visualization
                let progress = calculatedTarget > 0 ? min(editedAmount * Double(calculatedMonthsToTarget) / calculatedTarget, 1.0) : 0
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.green)
                    Text("Projected completion: \(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var linkedCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundColor(.blue)
                Text("Included Spending Categories")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This allocation covers your spending in the following categories:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Display categories as detailed rows
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(bucket.linkedBudgetCategories, id: \.self) { category in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: bucket.color))

                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            // Visual indicator badge
                            Text(categoryBadgeText(for: category))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: bucket.color).opacity(0.15))
                                .foregroundColor(Color(hex: bucket.color))
                                .cornerRadius(6)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                // Help text
                Text("Your actual spending in these categories was analyzed to determine this allocation amount.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func categoryBadgeText(for category: String) -> String {
        // Map common categories to helpful badges
        let badges: [String: String] = [
            "Groceries": "ESSENTIAL",
            "Rent": "ESSENTIAL",
            "Utilities": "ESSENTIAL",
            "Transportation": "ESSENTIAL",
            "Insurance": "ESSENTIAL",
            "Healthcare": "ESSENTIAL",
            "Entertainment": "LIFESTYLE",
            "Dining": "LIFESTYLE",
            "Shopping": "LIFESTYLE",
            "Travel": "LIFESTYLE",
            "Hobbies": "LIFESTYLE"
        ]
        return badges[category] ?? "TRACKED"
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

// MARK: - Color Hex Extension

extension Color {
    /// Initialize Color from hex string (e.g., "#FF5733" or "FF5733")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
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

    return ScrollView {
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
