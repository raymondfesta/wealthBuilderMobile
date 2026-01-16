import SwiftUI

/// Picker for emergency fund duration (3/6/12 months) with shortfall and contribution options
struct EmergencyFundDurationPicker: View {
    let durationOptions: [EmergencyFundDurationOption]
    @Binding var selectedDuration: Int?
    @Binding var selectedPresetTier: PresetTier
    let onSelectionChange: (Int, Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emergency Fund Target")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Duration option cards
            VStack(spacing: 12) {
                ForEach(durationOptions) { option in
                    durationCard(option)
                }
            }

            // Preset selector for selected duration
            if let selected = selectedDuration,
               let option = durationOptions.first(where: { $0.months == selected }) {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Monthly Contribution")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Picker("Contribution Level", selection: $selectedPresetTier) {
                        Text("Low").tag(PresetTier.low)
                        Text("Recommended").tag(PresetTier.recommended)
                        Text("High").tag(PresetTier.high)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPresetTier) { newTier in
                        let newAmount = option.monthlyContribution.value(for: newTier).amount
                        onSelectionChange(selected, newAmount)
                    }

                    // Contribution details
                    contributionDetails(option)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    @ViewBuilder
    private func durationCard(_ option: EmergencyFundDurationOption) -> some View {
        Button {
            selectedDuration = option.months
            let amount = option.monthlyContribution.value(for: selectedPresetTier).amount
            onSelectionChange(option.months, amount)
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: selectedDuration == option.months ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selectedDuration == option.months ? Color.protectionMint : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(option.months) Months")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if option.isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.protectionMint)
                                .cornerRadius(4)
                        }

                        if option.isGoalMet {
                            Text("GOAL MET")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.progressGreen)
                                .cornerRadius(4)
                        }
                    }

                    Text("Target: \(formattedAmount(option.targetAmount))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if option.shortfall > 0 {
                        Text("Need: \(formattedAmount(option.shortfall))")
                            .font(.caption)
                            .foregroundColor(Color.opportunityOrange)
                    }
                }

                Spacer()

                if selectedDuration == option.months {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedDuration == option.months ?
                        Color(.systemGray6) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(selectedDuration == option.months ?
                                Color.protectionMint : Color(.systemGray4),
                                lineWidth: selectedDuration == option.months ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contributionDetails(_ option: EmergencyFundDurationOption) -> some View {
        let selectedValue = option.monthlyContribution.value(for: selectedPresetTier)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedAmount(selectedValue.amount))
                    .font(.title2)
                    .fontWeight(.bold)

                Text("/ month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(selectedValue.percentage))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Time to goal
            if let timeToGoal = option.timeToGoal(tier: selectedPresetTier), timeToGoal > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Goal in \(timeToGoal) months")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            } else if option.isGoalMet {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Target already met! Consider increasing duration.")
                        .font(.caption)
                }
                .foregroundColor(Color.progressGreen)
            }

            // Comparison of all tiers
            Divider()
                .padding(.vertical, 4)

            HStack(spacing: 16) {
                tierComparison("Low", option.monthlyContribution.low, tier: .low)
                tierComparison("Rec", option.monthlyContribution.recommended, tier: .recommended)
                tierComparison("High", option.monthlyContribution.high, tier: .high)
            }
            .font(.caption2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private func tierComparison(_ label: String, _ value: PresetValue, tier: PresetTier) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(selectedPresetTier == tier ? .primary : .secondary)
                .fontWeight(selectedPresetTier == tier ? .semibold : .regular)
            Text(formattedAmount(value.amount))
                .foregroundColor(selectedPresetTier == tier ? .primary : .secondary)
                .fontWeight(selectedPresetTier == tier ? .semibold : .regular)
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview
struct EmergencyFundDurationPicker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            EmergencyFundDurationPicker(
                durationOptions: [
                    EmergencyFundDurationOption(
                        months: 3,
                        targetAmount: 7500,
                        shortfall: 0,
                        monthlyContribution: PresetOptions(
                            low: PresetValue(amount: 0, percentage: 0),
                            recommended: PresetValue(amount: 0, percentage: 0),
                            high: PresetValue(amount: 0, percentage: 0)
                        ),
                        isRecommended: false
                    ),
                    EmergencyFundDurationOption(
                        months: 6,
                        targetAmount: 15000,
                        shortfall: 5000,
                        monthlyContribution: PresetOptions(
                            low: PresetValue(amount: 208, percentage: 4),
                            recommended: PresetValue(amount: 347, percentage: 7),
                            high: PresetValue(amount: 625, percentage: 13)
                        ),
                        isRecommended: true
                    ),
                    EmergencyFundDurationOption(
                        months: 12,
                        targetAmount: 30000,
                        shortfall: 20000,
                        monthlyContribution: PresetOptions(
                            low: PresetValue(amount: 833, percentage: 17),
                            recommended: PresetValue(amount: 1389, percentage: 28),
                            high: PresetValue(amount: 2500, percentage: 50)
                        ),
                        isRecommended: false
                    )
                ],
                selectedDuration: .constant(6),
                selectedPresetTier: .constant(.recommended),
                onSelectionChange: { months, amount in
                    print("Selected: \(months) months at $\(amount)/month")
                }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
