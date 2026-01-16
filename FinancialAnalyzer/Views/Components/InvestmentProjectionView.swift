import SwiftUI

/// Shows investment growth projections across 10/20/30 years for different contribution levels
struct InvestmentProjectionView: View {
    let projection: InvestmentProjection
    let selectedTier: PresetTier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Investment Growth Projection")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    if projection.currentBalance > 0 {
                        Text("Starting balance: \(formattedAmount(projection.currentBalance))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(Color.wealthPurple)
            }

            // Assumption note
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.caption)
                Text("Assumes 7% annual return")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Divider()

            // Projection table
            VStack(spacing: 12) {
                // Header row
                HStack {
                    Text("Timeline")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    projectionHeader("Low", tier: .low)
                    projectionHeader("Recommended", tier: .recommended)
                    projectionHeader("High", tier: .high)
                }

                Divider()

                // 10 years
                projectionRow(
                    years: 10,
                    low: projection.lowProjection.year10,
                    recommended: projection.recommendedProjection.year10,
                    high: projection.highProjection.year10
                )

                // 20 years
                projectionRow(
                    years: 20,
                    low: projection.lowProjection.year20,
                    recommended: projection.recommendedProjection.year20,
                    high: projection.highProjection.year20
                )

                // 30 years
                projectionRow(
                    years: 30,
                    low: projection.lowProjection.year30,
                    recommended: projection.recommendedProjection.year30,
                    high: projection.highProjection.year30
                )
            }

            Divider()

            // Selected tier details
            selectedTierDetails()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    @ViewBuilder
    private func projectionHeader(_ label: String, tier: PresetTier) -> some View {
        Text(label)
            .font(.caption)
            .fontWeight(selectedTier == tier ? .bold : .semibold)
            .foregroundColor(selectedTier == tier ? Color.wealthPurple : .secondary)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func projectionRow(years: Int, low: Double, recommended: Double, high: Double) -> some View {
        HStack {
            Text("\(years) years")
                .font(.subheadline)
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .leading)

            projectionCell(amount: low, tier: .low)
            projectionCell(amount: recommended, tier: .recommended)
            projectionCell(amount: high, tier: .high)
        }
    }

    @ViewBuilder
    private func projectionCell(amount: Double, tier: PresetTier) -> some View {
        Text(formattedAmountShort(amount))
            .font(.subheadline)
            .fontWeight(selectedTier == tier ? .bold : .regular)
            .foregroundColor(selectedTier == tier ? Color.wealthPurple : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selectedTier == tier ? Color.wealthPurple.opacity(0.1) : Color.clear)
            )
    }

    @ViewBuilder
    private func selectedTierDetails() -> some View {
        let timeline = projection.timeline(for: selectedTier)

        VStack(alignment: .leading, spacing: 8) {
            Text("Your \(selectedTier.displayName) Tier Projection")
                .font(.subheadline)
                .fontWeight(.semibold)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Contribution")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedAmount(timeline.monthlyContribution))
                        .font(.headline)
                        .foregroundColor(Color.wealthPurple)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("30-Year Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formattedAmountShort(timeline.year30))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color.wealthPurple)
                }
            }

            // Gain breakdown
            let totalGain = timeline.totalGain(years: 30)
            let totalContributions = timeline.monthlyContribution * 12 * 30

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Contributions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formattedAmountShort(totalContributions))
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Investment Growth")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(formattedAmountShort(totalGain))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.progressGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total ROI")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(Int(timeline.roi(years: 30)))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.progressGreen)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.wealthPurple.opacity(0.05))
            )
        }
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }

    private func formattedAmountShort(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            let millions = amount / 1_000_000
            return String(format: "$%.1fM", millions)
        } else if amount >= 1_000 {
            let thousands = amount / 1_000
            return String(format: "$%.0fk", thousands)
        } else {
            return formattedAmount(amount)
        }
    }
}

// MARK: - Preview
struct InvestmentProjectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            InvestmentProjectionView(
                projection: InvestmentProjection(
                    currentBalance: 25000,
                    lowProjection: ProjectionTimeline(
                        monthlyContribution: 250,
                        year10: 68000,
                        year20: 155000,
                        year30: 333000
                    ),
                    recommendedProjection: ProjectionTimeline(
                        monthlyContribution: 500,
                        year10: 111000,
                        year20: 285000,
                        year30: 635000
                    ),
                    highProjection: ProjectionTimeline(
                        monthlyContribution: 750,
                        year10: 154000,
                        year20: 415000,
                        year30: 1100000
                    )
                ),
                selectedTier: .recommended
            )

            InvestmentProjectionView(
                projection: InvestmentProjection(
                    currentBalance: 0,
                    lowProjection: ProjectionTimeline(
                        monthlyContribution: 200,
                        year10: 35000,
                        year20: 105000,
                        year30: 245000
                    ),
                    recommendedProjection: ProjectionTimeline(
                        monthlyContribution: 400,
                        year10: 70000,
                        year20: 210000,
                        year30: 490000
                    ),
                    highProjection: ProjectionTimeline(
                        monthlyContribution: 600,
                        year10: 105000,
                        year20: 315000,
                        year30: 735000
                    )
                ),
                selectedTier: .high
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
