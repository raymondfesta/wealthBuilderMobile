import SwiftUI

/// Individual checklist item for marking allocations complete with editable amount
struct AllocationChecklistItem: View {
    let allocation: ScheduledAllocation
    @Binding var isCompleted: Bool
    @Binding var actualAmount: Double
    @State private var amountText: String = ""
    @State private var isEditingAmount: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isCompleted.toggle()
                }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : Color(.tertiaryLabel))
            }

            // Bucket icon and name
            HStack(spacing: 10) {
                Image(systemName: allocation.bucketType.icon)
                    .font(.body)
                    .foregroundColor(Color(hex: allocation.bucketType.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: allocation.bucketType.color).opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(allocation.bucketType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCompleted ? .secondary : .primary)
                        .strikethrough(isCompleted)

                    if actualAmount != allocation.scheduledAmount {
                        Text("Scheduled: \(formatCurrency(allocation.scheduledAmount))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Amount editor
            Button {
                isEditingAmount = true
            } label: {
                HStack(spacing: 4) {
                    Text(formatCurrency(actualAmount))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isCompleted ? .secondary : .primary)

                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.6))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isCompleted ? Color(.secondarySystemBackground) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.green.opacity(0.3) : Color(.separator), lineWidth: 1)
        )
        .onAppear {
            if actualAmount == 0 {
                actualAmount = allocation.scheduledAmount
            }
            amountText = String(format: "%.0f", actualAmount)
        }
        .alert("Edit Amount", isPresented: $isEditingAmount) {
            TextField("Amount", text: $amountText)
                .keyboardType(.decimalPad)

            Button("Cancel", role: .cancel) {
                amountText = String(format: "%.0f", actualAmount)
            }

            Button("Save") {
                if let newAmount = Double(amountText), newAmount >= 0 {
                    actualAmount = newAmount
                } else {
                    amountText = String(format: "%.0f", actualAmount)
                }
            }
        } message: {
            Text("Enter the amount you actually allocated to \(allocation.bucketType.displayName)")
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

#Preview("Allocation Checklist Item") {
    VStack(spacing: 12) {
        AllocationChecklistItem(
            allocation: ScheduledAllocation(
                paycheckDate: Date(),
                bucketType: .emergencyFund,
                scheduledAmount: 500,
                status: .upcoming
            ),
            isCompleted: .constant(false),
            actualAmount: .constant(500)
        )

        AllocationChecklistItem(
            allocation: ScheduledAllocation(
                paycheckDate: Date(),
                bucketType: .investments,
                scheduledAmount: 250,
                status: .upcoming
            ),
            isCompleted: .constant(true),
            actualAmount: .constant(250)
        )

        AllocationChecklistItem(
            allocation: ScheduledAllocation(
                paycheckDate: Date(),
                bucketType: .discretionarySpending,
                scheduledAmount: 600,
                status: .upcoming
            ),
            isCompleted: .constant(false),
            actualAmount: .constant(450)  // Adjusted amount
        )
    }
    .padding()
}
