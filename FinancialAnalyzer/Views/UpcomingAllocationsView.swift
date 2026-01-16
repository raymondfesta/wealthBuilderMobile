import SwiftUI

/// Timeline view showing upcoming allocation events grouped by payday
struct UpcomingAllocationsView: View {
    @ObservedObject var viewModel: FinancialViewModel
    @State private var selectedPayday: PaycheckAllocationGroup?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if upcomingGroups.isEmpty {
                    emptyStateView
                } else {
                    ForEach(upcomingGroups) { group in
                        PaydayCard(
                            group: group,
                            onMarkComplete: {
                                selectedPayday = group
                            },
                            onSkip: {
                                skipPayday(group)
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedPayday) { group in
            AllocationReminderSheet(
                viewModel: viewModel,
                allocations: group.allocations
            )
        }
    }

    // MARK: - Computed Properties

    private var upcomingGroups: [PaycheckAllocationGroup] {
        viewModel.scheduledAllocations
            .filter { $0.status.isPending && $0.paycheckDate >= Date() }
            .groupedByPaycheck()
            .prefix(6)  // Show next 6 paydays
            .map { $0 }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.6))

            Text("All Caught Up!")
                .font(.title3)
                .fontWeight(.semibold)

            Text("You don't have any pending allocations right now.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

    private func skipPayday(_ group: PaycheckAllocationGroup) {
        Task {
            await viewModel.skipAllocation(paycheckDate: group.paycheckDate)
        }
    }
}

// MARK: - Payday Card

struct PaydayCard: View {
    let group: PaycheckAllocationGroup
    let onMarkComplete: () -> Void
    let onSkip: () -> Void

    @State private var showingSkipConfirmation: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Date and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.formattedDate)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Days indicator
                if daysUntil >= 0 {
                    VStack(spacing: 2) {
                        Text("\(daysUntil)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(daysColor)

                        Text("day\(daysUntil == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Total amount
            HStack {
                Text("Total Allocation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatCurrency(group.totalScheduledAmount))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)

            Divider()

            // Bucket breakdown
            VStack(spacing: 10) {
                ForEach(group.allocations.sorted(by: { $0.scheduledAmount > $1.scheduledAmount })) { allocation in
                    AllocationRow(allocation: allocation)
                }
            }

            // Action buttons
            if group.hasPendingAllocations {
                HStack(spacing: 12) {
                    Button {
                        showingSkipConfirmation = true
                    } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(10)
                    }

                    Button {
                        onMarkComplete()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Complete")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: isDueToday ? 2 : 1)
        )
        .confirmationDialog(
            "Skip This Payday?",
            isPresented: $showingSkipConfirmation,
            titleVisibility: .visible
        ) {
            Button("Skip Allocations", role: .destructive) {
                onSkip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can always allocate manually later.")
        }
    }

    // MARK: - Computed Properties

    private var daysUntil: Int {
        guard let first = group.allocations.first else { return 0 }
        return first.daysUntilPaycheck
    }

    private var isDueToday: Bool {
        guard let first = group.allocations.first else { return false }
        return first.isDueToday
    }

    private var isOverdue: Bool {
        guard let first = group.allocations.first else { return false }
        return first.isOverdue
    }

    private var statusText: String {
        if isDueToday {
            return "Due Today"
        } else if isOverdue {
            return "Overdue"
        } else if daysUntil == 1 {
            return "Tomorrow"
        } else {
            return "In \(daysUntil) days"
        }
    }

    private var daysColor: Color {
        if isDueToday || isOverdue {
            return .red
        } else if daysUntil <= 2 {
            return .orange
        } else {
            return .blue
        }
    }

    private var borderColor: Color {
        if isDueToday {
            return .blue
        } else if isOverdue {
            return .red.opacity(0.5)
        } else {
            return Color(.separator)
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

// MARK: - Allocation Row

struct AllocationRow: View {
    let allocation: ScheduledAllocation

    var body: some View {
        HStack(spacing: 12) {
            // Bucket icon
            Image(systemName: allocation.bucketType.icon)
                .font(.title3)
                .foregroundColor(Color(hex: allocation.bucketType.color))
                .frame(width: 32, height: 32)
                .background(Color(hex: allocation.bucketType.color).opacity(0.1))
                .cornerRadius(8)

            // Bucket name
            Text(allocation.bucketType.displayName)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            // Amount
            Text(formatCurrency(allocation.scheduledAmount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
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

#Preview("Upcoming Allocations") {
    let viewModel: FinancialViewModel = {
        let vm = FinancialViewModel()

        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!

        vm.scheduledAllocations = [
            // Today's allocations
            ScheduledAllocation(paycheckDate: today, bucketType: .essentialSpending, scheduledAmount: 1250, status: .upcoming),
            ScheduledAllocation(paycheckDate: today, bucketType: .emergencyFund, scheduledAmount: 500, status: .upcoming),
            ScheduledAllocation(paycheckDate: today, bucketType: .discretionarySpending, scheduledAmount: 500, status: .upcoming),
            ScheduledAllocation(paycheckDate: today, bucketType: .investments, scheduledAmount: 250, status: .upcoming),

            // Tomorrow's allocations
            ScheduledAllocation(paycheckDate: tomorrow, bucketType: .essentialSpending, scheduledAmount: 1250, status: .upcoming),
            ScheduledAllocation(paycheckDate: tomorrow, bucketType: .emergencyFund, scheduledAmount: 500, status: .upcoming),

            // Next week
            ScheduledAllocation(paycheckDate: nextWeek, bucketType: .essentialSpending, scheduledAmount: 1250, status: .upcoming),
            ScheduledAllocation(paycheckDate: nextWeek, bucketType: .emergencyFund, scheduledAmount: 500, status: .upcoming),
        ]

        return vm
    }()

    return UpcomingAllocationsView(viewModel: viewModel)
}
