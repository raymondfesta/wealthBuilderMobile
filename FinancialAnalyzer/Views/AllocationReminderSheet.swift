import SwiftUI

/// Sheet displayed when user taps notification or "Mark as Complete" button
/// Shows checklist with individual checkboxes and editable amounts per bucket
struct AllocationReminderSheet: View {
    @ObservedObject var viewModel: FinancialViewModel
    let allocations: [ScheduledAllocation]
    @Environment(\.dismiss) private var dismiss

    // Track completion and amounts for each allocation
    @State private var completionStatus: [String: Bool] = [:]
    @State private var actualAmounts: [String: Double] = [:]
    @State private var isSubmitting: Bool = false
    @State private var showingSkipConfirmation: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Checklist
                    checklistSection

                    // Summary
                    summarySection

                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Complete Allocations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeState()
            }
            .confirmationDialog(
                "Skip All Allocations?",
                isPresented: $showingSkipConfirmation,
                titleVisibility: .visible
            ) {
                Button("Skip This Payday", role: .destructive) {
                    skipAllAllocations()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can always allocate manually later.")
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            if let first = allocations.first {
                VStack(spacing: 4) {
                    Text(first.formattedDate)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Mark the allocations you've completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Allocations")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(allocations) { allocation in
                    AllocationChecklistItem(
                        allocation: allocation,
                        isCompleted: completionBinding(for: allocation.id),
                        actualAmount: amountBinding(for: allocation.id, defaultAmount: allocation.scheduledAmount)
                    )
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(spacing: 12) {
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(completedCount) of \(allocations.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressGradient)
                            .frame(width: geometry.size.width * progressPercentage, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Total amounts
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(totalScheduled))
                        .font(.headline)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Actual")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(formatCurrency(totalActual))
                        .font(.headline)
                        .foregroundColor(varianceColor)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            // Variance message
            if abs(totalActual - totalScheduled) > 0.01 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)

                    Text(varianceMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Mark as Complete button
            Button {
                completeAllocations()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Allocations")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canComplete ? Color.blue : Color.gray)
                .cornerRadius(16)
                .shadow(color: canComplete ? Color.blue.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!canComplete || isSubmitting)

            // Skip button
            Button {
                showingSkipConfirmation = true
            } label: {
                Text("Skip This Payday")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .disabled(isSubmitting)
        }
    }

    // MARK: - Computed Properties

    private var completedCount: Int {
        completionStatus.values.filter { $0 }.count
    }

    private var progressPercentage: Double {
        guard !allocations.isEmpty else { return 0 }
        return Double(completedCount) / Double(allocations.count)
    }

    private var progressGradient: LinearGradient {
        if progressPercentage >= 1.0 {
            return LinearGradient(colors: [.green, .green], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var totalScheduled: Double {
        allocations.reduce(0) { $0 + $1.scheduledAmount }
    }

    private var totalActual: Double {
        allocations.reduce(0) { sum, allocation in
            if completionStatus[allocation.id] == true {
                return sum + (actualAmounts[allocation.id] ?? allocation.scheduledAmount)
            }
            return sum
        }
    }

    private var varianceColor: Color {
        let diff = totalActual - totalScheduled
        if abs(diff) < 0.01 {
            return .primary
        } else if diff > 0 {
            return .orange
        } else {
            return .blue
        }
    }

    private var varianceMessage: String {
        let diff = totalActual - totalScheduled
        if abs(diff) < 0.01 {
            return ""
        } else if diff > 0 {
            return "You allocated \(formatCurrency(abs(diff))) more than planned"
        } else {
            return "You allocated \(formatCurrency(abs(diff))) less than planned"
        }
    }

    private var canComplete: Bool {
        completedCount > 0
    }

    // MARK: - Bindings

    private func completionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { completionStatus[id] ?? false },
            set: { completionStatus[id] = $0 }
        )
    }

    private func amountBinding(for id: String, defaultAmount: Double) -> Binding<Double> {
        Binding(
            get: { actualAmounts[id] ?? defaultAmount },
            set: { actualAmounts[id] = $0 }
        )
    }

    // MARK: - Methods

    private func initializeState() {
        for allocation in allocations {
            completionStatus[allocation.id] = false
            actualAmounts[allocation.id] = allocation.scheduledAmount
        }
    }

    private func completeAllocations() {
        guard !isSubmitting else { return }
        isSubmitting = true

        Task {
            // Build list of completed allocations
            var completedAllocations: [(ScheduledAllocation, Double)] = []

            for allocation in allocations {
                if completionStatus[allocation.id] == true {
                    let amount = actualAmounts[allocation.id] ?? allocation.scheduledAmount
                    completedAllocations.append((allocation, amount))
                }
            }

            // Call viewModel to process completions
            await viewModel.completeAllocations(completedAllocations)

            await MainActor.run {
                isSubmitting = false
                dismiss()
            }
        }
    }

    private func skipAllAllocations() {
        guard let firstDate = allocations.first?.paycheckDate else { return }

        Task {
            await viewModel.skipAllocation(paycheckDate: firstDate)
            await MainActor.run {
                dismiss()
            }
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Preview

#Preview("Allocation Reminder Sheet") {
    let viewModel = FinancialViewModel()

    let allocations = [
        ScheduledAllocation(paycheckDate: Date(), bucketType: .essentialSpending, scheduledAmount: 1250, status: .upcoming),
        ScheduledAllocation(paycheckDate: Date(), bucketType: .emergencyFund, scheduledAmount: 500, status: .upcoming),
        ScheduledAllocation(paycheckDate: Date(), bucketType: .discretionarySpending, scheduledAmount: 600, status: .upcoming),
        ScheduledAllocation(paycheckDate: Date(), bucketType: .investments, scheduledAmount: 250, status: .upcoming)
    ]

    return AllocationReminderSheet(viewModel: viewModel, allocations: allocations)
}
