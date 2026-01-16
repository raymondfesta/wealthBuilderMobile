import SwiftUI

/// Segmented control for selecting Low/Recommended/High preset allocation amounts
struct AllocationPresetSelector: View {
    let presetOptions: PresetOptions
    @Binding var selectedTier: PresetTier
    let onSelectionChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Allocation")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Native segmented control
            Picker("Allocation Tier", selection: $selectedTier) {
                Text("Low").tag(PresetTier.low)
                Text("Recommended").tag(PresetTier.recommended)
                Text("High").tag(PresetTier.high)
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTier) { newTier in
                let newAmount = presetOptions.value(for: newTier).amount
                onSelectionChange(newAmount)
            }

            // Display selected amount and percentage
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedAmount(presetOptions.value(for: selectedTier).amount))
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(Int(presetOptions.value(for: selectedTier).percentage))% of monthly income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Show all three options for context
                VStack(alignment: .trailing, spacing: 2) {
                    tierLabel(tier: .low, amount: presetOptions.low.amount)
                    tierLabel(tier: .recommended, amount: presetOptions.recommended.amount)
                    tierLabel(tier: .high, amount: presetOptions.high.amount)
                }
                .font(.caption2)
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    @ViewBuilder
    private func tierLabel(tier: PresetTier, amount: Double) -> some View {
        HStack(spacing: 4) {
            Text(tier.displayName)
                .foregroundColor(selectedTier == tier ? .primary : .secondary)
                .fontWeight(selectedTier == tier ? .semibold : .regular)

            Text(formattedAmount(amount))
                .foregroundColor(selectedTier == tier ? .primary : .secondary)
                .fontWeight(selectedTier == tier ? .semibold : .regular)
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

extension PresetTier {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .recommended: return "Rec"
        case .high: return "High"
        }
    }
}

// MARK: - Preview
struct AllocationPresetSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AllocationPresetSelector(
                presetOptions: PresetOptions(
                    low: PresetValue(amount: 250, percentage: 5),
                    recommended: PresetValue(amount: 500, percentage: 10),
                    high: PresetValue(amount: 750, percentage: 15)
                ),
                selectedTier: .constant(.recommended),
                onSelectionChange: { amount in
                    print("Selected amount: $\(amount)")
                }
            )

            AllocationPresetSelector(
                presetOptions: PresetOptions(
                    low: PresetValue(amount: 500, percentage: 10),
                    recommended: PresetValue(amount: 800, percentage: 16),
                    high: PresetValue(amount: 1000, percentage: 20)
                ),
                selectedTier: .constant(.high),
                onSelectionChange: { _ in }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
