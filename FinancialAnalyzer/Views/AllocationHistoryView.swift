import SwiftUI

/// Historical log of completed allocations grouped by month
struct AllocationHistoryView: View {
    @ObservedObject var viewModel: FinancialViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if monthlyGroups.isEmpty {
                    emptyStateView
                } else {
                    // Summary stats at top
                    summaryStatsSection

                    // Monthly groups
                    ForEach(monthlyGroups) { group in
                        MonthGroupCard(group: group)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var monthlyGroups: [MonthlyAllocationGroup] {
        viewModel.allocationHistory.groupedByMonth()
    }

    private var stats: AllocationExecutionStats {
        AllocationExecutionStats(executions: viewModel.allocationHistory)
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))

            Text("No History Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Your completed allocations will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var summaryStatsSection: some View {
        VStack(spacing: 12) {
            Text("All-Time Stats")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                StatCard(
                    title: "Total Allocated",
                    value: formatCurrency(stats.totalAllocated),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )

                StatCard(
                    title: "Allocations",
                    value: "\(stats.totalExecutions)",
                    icon: "checkmark.circle.fill",
                    color: .blue
                )
            }

            HStack(spacing: 12) {
                StatCard(
                    title: "On-Time Rate",
                    value: stats.onTimePercentageString,
                    icon: "clock.fill",
                    color: .orange
                )

                StatCard(
                    title: "Avg Per Allocation",
                    value: formatCurrency(stats.averagePerAllocation),
                    icon: "chart.bar.fill",
                    color: .purple
                )
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

// MARK: - Month Group Card

struct MonthGroupCard: View {
    let group: MonthlyAllocationGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Month header with summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.monthYear)
                        .font(.headline)

                    Text(group.summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Total amount badge
                Text(formatCurrency(group.totalAllocated))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            Divider()

            // Individual executions
            VStack(spacing: 10) {
                ForEach(group.executions.sorted(by: { $0.completedAt > $1.completedAt })) { execution in
                    HistoryRow(execution: execution)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let execution: AllocationExecution

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(monthAbbr)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // Bucket info
            HStack(spacing: 10) {
                Image(systemName: execution.bucketType.icon)
                    .font(.body)
                    .foregroundColor(Color(hex: execution.bucketType.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: execution.bucketType.color).opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(execution.bucketType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if execution.isDifferentThanPlanned {
                        Text("Adjusted from \(formatCurrency(execution.scheduledAmount))")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(execution.actualAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if execution.wasAutomatic {
                    Text("Auto")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: execution.completedAt)
    }

    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: execution.completedAt)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)

                Spacer()
            }

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Allocation History") {
    let viewModel: FinancialViewModel = {
        let vm = FinancialViewModel()

        let calendar = Calendar.current
        let today = Date()

        // Generate mock history
        var executions: [AllocationExecution] = []

        for monthOffset in 0..<3 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: today) else { continue }

            for _ in 0..<4 {
                executions.append(AllocationExecution(
                    bucketType: .emergencyFund,
                    scheduledAmount: 500,
                    actualAmount: 500,
                    paycheckDate: monthDate,
                    completedAt: monthDate,
                    scheduledAllocationId: UUID().uuidString
                ))

                executions.append(AllocationExecution(
                    bucketType: .investments,
                    scheduledAmount: 250,
                    actualAmount: 275,
                    paycheckDate: monthDate,
                    completedAt: monthDate,
                    scheduledAllocationId: UUID().uuidString
                ))
            }
        }

        vm.allocationHistory = executions

        return vm
    }()

    return AllocationHistoryView(viewModel: viewModel)
}
