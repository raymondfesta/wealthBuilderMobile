import SwiftUI

// MARK: - Metric Card

/// Expandable card displaying a single financial health metric with explanation
struct MetricCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    let subtitle: String
    let explanation: String
    let progress: ProgressData?

    @State private var showExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon, title, value
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor.gradient)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                // Info button to toggle explanation
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showExplanation.toggle()
                    }
                } label: {
                    Image(systemName: showExplanation ? "info.circle.fill" : "info.circle")
                        .font(.title3)
                        .foregroundColor(showExplanation ? iconColor : .secondary)
                }
            }

            // Subtitle (context)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            // Progress bar if provided
            if let progress = progress {
                ProgressBar(data: progress, color: iconColor)
            }

            // Expandable explanation
            if showExplanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Progress Data Model

/// Data model for progress bars
struct ProgressData {
    let current: Double
    let target: Double
    let unit: String
    var reversed: Bool = false  // For countdown progress (e.g., months to debt-free)
}

// MARK: - Progress Bar

/// Horizontal progress bar with gradient fill and labels
struct ProgressBar: View {
    let data: ProgressData
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))

                    // Progress fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.gradient)
                        .frame(width: geometry.size.width * progressPercentage)
                }
            }
            .frame(height: 12)

            // Labels
            HStack {
                Text(data.reversed ? "Starting point" : "Current")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text(targetText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var progressPercentage: Double {
        guard data.target > 0 else { return 0 }
        let percentage = data.current / data.target
        return min(max(percentage, 0), 1.0)
    }

    private var targetText: String {
        if data.reversed {
            return "Goal: 0 \(data.unit)"
        } else {
            return "Goal: \(formatNumber(data.target)) \(data.unit)"
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0fk", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Spending Breakdown Row

/// Row showing a spending category with amount, percentage, and visual bar
struct SpendingBreakdownRow: View {
    let label: String
    let amount: Double
    let total: Double
    let color: Color
    let description: String

    var body: some View {
        VStack(spacing: 8) {
            // Header with label and amount
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(amount))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("\(percentage)%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Visual bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.3))
                    .frame(width: geometry.size.width * (amount / total))
            }
            .frame(height: 6)

            // Description
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var percentage: Int {
        guard total > 0 else { return 0 }
        return Int((amount / total) * 100)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview Provider

#if DEBUG
struct HealthReportComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Metric Card Example
                MetricCard(
                    icon: "arrow.up.circle.fill",
                    iconColor: .progressGreen,
                    title: "Monthly Savings",
                    value: "$450",
                    subtitle: "↑ Up from $300 last month",
                    explanation: "The amount remaining after your monthly expenses. This is what you can allocate toward goals.",
                    progress: nil
                )

                // Metric Card with Progress
                MetricCard(
                    icon: "shield.fill",
                    iconColor: .stableBlue,
                    title: "Emergency Fund",
                    value: "3.5 months",
                    subtitle: "Covers 3.5 months of essential expenses",
                    explanation: "Your current savings divided by monthly essential expenses. Financial advisors recommend 6 months.",
                    progress: ProgressData(
                        current: 3.5,
                        target: 6.0,
                        unit: "months"
                    )
                )

                // Spending Breakdown Example
                VStack(spacing: 12) {
                    Text("Spending Breakdown")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    SpendingBreakdownRow(
                        label: "Essential Expenses",
                        amount: 2500,
                        total: 5000,
                        color: .stableBlue,
                        description: "Housing, groceries, utilities, transportation"
                    )

                    SpendingBreakdownRow(
                        label: "Discretionary Spending",
                        amount: 800,
                        total: 5000,
                        color: .opportunityOrange,
                        description: "Entertainment, dining, shopping, hobbies"
                    )

                    SpendingBreakdownRow(
                        label: "Savings",
                        amount: 450,
                        total: 5000,
                        color: .progressGreen,
                        description: "Available for goals and future needs"
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
            .padding()
        }
    }
}
#endif
