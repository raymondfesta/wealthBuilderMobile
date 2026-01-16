import SwiftUI

/// Specialized card for debt paydown allocation bucket with payoff timeline
struct DebtPaydownCard: View {
    let bucket: AllocationBucket
    @Binding var selectedPresetTier: PresetTier
    let onPresetChange: (Double) -> Void
    let onManageAccounts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            header

            Divider()

            // Current debt section
            if bucket.currentBalanceFromAccounts > 0 {
                currentDebtSection
                Divider()
            }

            // Preset selector
            if let presetOptions = bucket.presetOptions {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Payment")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Payment Level", selection: $selectedPresetTier) {
                        Text("Low").tag(PresetTier.low)
                        Text("Recommended").tag(PresetTier.recommended)
                        Text("High").tag(PresetTier.high)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPresetTier) { newTier in
                        let newAmount = presetOptions.value(for: newTier).amount
                        onPresetChange(newAmount)
                    }

                    paymentDetails(presetOptions)
                }

                Divider()
            }

            // Payoff timeline (if available from backend)
            if bucket.explanation.contains("months") {
                payoffTimelineSection(bucket.explanation)
            }

            // Account linking
            accountLinkingSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: bucket.type.icon)
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.red.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(bucket.type.rawValue)
                    .font(.headline)

                Text(bucket.type.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var currentDebtSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Debt")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(formattedAmount(bucket.currentBalanceFromAccounts))
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.red)

            if !bucket.linkedAccountIds.isEmpty {
                Text("From \(bucket.linkedAccountIds.count) linked account\(bucket.linkedAccountIds.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func paymentDetails(_ presetOptions: PresetOptions) -> some View {
        let selectedValue = presetOptions.value(for: selectedPresetTier)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formattedAmount(selectedValue.amount))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)

                    Text("\(Int(selectedValue.percentage))% of monthly income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Comparison
                VStack(alignment: .trailing, spacing: 2) {
                    tierComparison("Low", presetOptions.low, tier: .low)
                    tierComparison("Rec", presetOptions.recommended, tier: .recommended)
                    tierComparison("High", presetOptions.high, tier: .high)
                }
                .font(.caption2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private func tierComparison(_ label: String, _ value: PresetValue, tier: PresetTier) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundColor(selectedPresetTier == tier ? .primary : .secondary)
                .fontWeight(selectedPresetTier == tier ? .semibold : .regular)

            Text(formattedAmount(value.amount))
                .foregroundColor(selectedPresetTier == tier ? .primary : .secondary)
                .fontWeight(selectedPresetTier == tier ? .semibold : .regular)
        }
    }

    @ViewBuilder
    private func payoffTimelineSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color.progressGreen)
                Text("Payoff Timeline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Extract timeline from explanation (basic parsing)
            if let timelineText = extractTimeline(from: explanation) {
                Text(timelineText)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.progressGreen.opacity(0.1))
                    )
            }

            // Interest saved
            if let interestSaved = extractInterestSaved(from: explanation) {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(Color.progressGreen)
                    Text("Save \(interestSaved) in interest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var accountLinkingSection: some View {
        Button {
            onManageAccounts()
        } label: {
            HStack {
                Image(systemName: "link.circle")
                    .foregroundColor(.red)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Manage Linked Accounts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if bucket.linkedAccountIds.isEmpty {
                        Text("No accounts linked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(bucket.linkedAccountIds.count) account\(bucket.linkedAccountIds.count == 1 ? "" : "s") linked")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func extractTimeline(from text: String) -> String? {
        // Look for patterns like "6-11 months" or "paid off in X months"
        let patterns = [
            "\\d+-\\d+ months",
            "\\d+ months",
            "paid off in [^.]*"
        ]

        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        return nil
    }

    private func extractInterestSaved(from text: String) -> String? {
        // Look for patterns like "$1,500-$1,700"
        if let range = text.range(of: "\\$[\\d,]+-\\$[\\d,]+", options: .regularExpression) {
            return String(text[range])
        }
        return nil
    }
}

// MARK: - Preview
struct DebtPaydownCard_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                DebtPaydownCard(
                    bucket: {
                        let bucket = AllocationBucket(
                            type: .debtPaydown,
                            allocatedAmount: 750,
                            percentageOfIncome: 15,
                            explanation: "At $750/month, you'll pay off $5,000 in 6-7 months, saving $1,525-$1,746 in interest compared to minimum payments."
                        )
                        bucket.presetOptions = PresetOptions(
                            low: PresetValue(amount: 500, percentage: 10),
                            recommended: PresetValue(amount: 750, percentage: 15),
                            high: PresetValue(amount: 1000, percentage: 20)
                        )
                        bucket.currentBalanceFromAccounts = 5000
                        bucket.linkedAccountIds = ["acc1", "acc2"]
                        return bucket
                    }(),
                    selectedPresetTier: .constant(.recommended),
                    onPresetChange: { amount in
                        print("Changed to $\(amount)")
                    },
                    onManageAccounts: {
                        print("Manage accounts tapped")
                    }
                )

                DebtPaydownCard(
                    bucket: {
                        let bucket = AllocationBucket(
                            type: .debtPaydown,
                            allocatedAmount: 400,
                            percentageOfIncome: 16,
                            explanation: "Focus on paying down high-interest debt to improve financial health."
                        )
                        bucket.presetOptions = PresetOptions(
                            low: PresetValue(amount: 200, percentage: 8),
                            recommended: PresetValue(amount: 400, percentage: 16),
                            high: PresetValue(amount: 600, percentage: 24)
                        )
                        return bucket
                    }(),
                    selectedPresetTier: .constant(.high),
                    onPresetChange: { _ in },
                    onManageAccounts: {}
                )
            }
            .padding()
        }
        .previewLayout(.sizeThatFits)
    }
}
