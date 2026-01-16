import SwiftUI

/// Toast notification showing auto-rebalancing feedback when user changes allocations
struct RebalanceToast: View {
    let adjustments: [AllocationAdjustment]
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundColor(.blue)

                Text("Auto-Adjusted")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            // Adjustment list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(adjustments) { adjustment in
                    HStack(spacing: 8) {
                        Image(systemName: adjustment.bucketType.icon)
                            .font(.caption)
                            .foregroundColor(Color(hex: adjustment.bucketType.color))
                            .frame(width: 20)

                        Text(adjustment.bucketType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: adjustment.isIncrease ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text(formatCurrency(abs(adjustment.amountChanged)))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(adjustment.isIncrease ? Color.progressGreen : Color.opportunityOrange)
                    }
                }
            }

            // Explanation (if available)
            if !adjustments.isEmpty {
                Text("To keep your total at 100%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .offset(y: isVisible ? 0 : -100)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }

            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    onDismiss()
                }
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

/// Represents a single allocation adjustment
struct AllocationAdjustment: Identifiable {
    let id = UUID()
    let bucketType: AllocationBucketType
    let amountChanged: Double  // Positive = increased, negative = decreased
    let previousAmount: Double
    let newAmount: Double

    var isIncrease: Bool {
        amountChanged > 0
    }
}

// MARK: - Toast Container View Modifier
extension View {
    /// Adds a rebalance toast overlay to the view
    func rebalanceToast(
        adjustments: Binding<[AllocationAdjustment]?>,
        isPresented: Binding<Bool>
    ) -> some View {
        self.overlay(alignment: .top) {
            if isPresented.wrappedValue, let adjustments = adjustments.wrappedValue {
                RebalanceToast(adjustments: adjustments) {
                    isPresented.wrappedValue = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(1000)
            }
        }
    }
}

// MARK: - Preview
struct RebalanceToast_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()

            RebalanceToast(
                adjustments: [
                    AllocationAdjustment(
                        bucketType: .discretionarySpending,
                        amountChanged: -150,
                        previousAmount: 800,
                        newAmount: 650
                    ),
                    AllocationAdjustment(
                        bucketType: .investments,
                        amountChanged: -50,
                        previousAmount: 500,
                        newAmount: 450
                    )
                ],
                onDismiss: {
                    print("Toast dismissed")
                }
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
