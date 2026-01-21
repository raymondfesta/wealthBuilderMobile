import SwiftUI

/// Row component for displaying financial metrics with label, value, and optional chevron
struct FinancialMetricRow: View {
    let label: String
    let value: Double
    let showChevron: Bool
    let valueColor: Color
    let action: (() -> Void)?

    init(
        label: String,
        value: Double,
        showChevron: Bool = true,
        valueColor: Color = DesignTokens.Colors.textEmphasis,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.showChevron = showChevron
        self.valueColor = valueColor
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .bodyStyle(color: DesignTokens.Colors.textTertiary)

                    Text(formatCurrency(value))
                        .titleValueStyle(color: valueColor)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(DesignTokens.Colors.accentSecondary)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0

        let absValue = abs(value)
        let formatted = formatter.string(from: NSNumber(value: absValue)) ?? "$0"

        return value < 0 ? "-\(formatted)" : formatted
    }
}

/// Row component for displaying text-based metrics (non-currency)
struct TextMetricRow: View {
    let label: String
    let value: String
    let showChevron: Bool
    let valueColor: Color
    let action: (() -> Void)?

    init(
        label: String,
        value: String,
        showChevron: Bool = true,
        valueColor: Color = DesignTokens.Colors.textEmphasis,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.value = value
        self.showChevron = showChevron
        self.valueColor = valueColor
        self.action = action
    }

    var body: some View {
        Button(action: { action?() }) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .bodyStyle(color: DesignTokens.Colors.textTertiary)

                    Text(value)
                        .titleValueStyle(color: valueColor)
                }

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(DesignTokens.Colors.accentSecondary)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Preview

#Preview("FinancialMetricRow") {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassmorphicCard(title: "Financial Metrics") {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    FinancialMetricRow(
                        label: "Emergency Fund",
                        value: 22800
                    )

                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)

                    FinancialMetricRow(
                        label: "Total Debt:",
                        value: -1850,
                        valueColor: DesignTokens.Colors.opportunityOrange
                    )

                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)

                    FinancialMetricRow(
                        label: "Available to Allocate:",
                        value: 515,
                        showChevron: false,
                        valueColor: DesignTokens.Colors.accentPrimary
                    )
                }
            }

            GlassmorphicCard(title: "Text Metrics") {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    TextMetricRow(
                        label: "Income Stability",
                        value: "Stable",
                        valueColor: DesignTokens.Colors.progressGreen
                    )

                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(height: 1)

                    TextMetricRow(
                        label: "Emergency Coverage",
                        value: "4.5 months",
                        showChevron: false
                    )
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
    }
    .primaryBackgroundGradient()
    .preferredColorScheme(.dark)
}
