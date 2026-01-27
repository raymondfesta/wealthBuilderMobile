import SwiftUI

/// Card component showing plan adherence for a single allocation bucket
/// Adapts content based on bucket type (spending vs savings)
struct PlanAdherenceCard: View {
    let bucket: AllocationBucket
    let transactions: [Transaction]
    let accounts: [BankAccount]
    let essentialMonthlySpend: Double
    let cycleStart: Date

    // MARK: - Computed Properties

    private var cycleEnd: Date {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: cycleStart),
              let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth) else {
            return Date()
        }
        return lastDay
    }

    private var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: cycleEnd).day ?? 0
    }

    private var bucketColor: Color {
        Color(hex: bucket.color)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Header with title and status
            cardHeader

            // Content based on bucket type
            switch bucket.type {
            case .essentialSpending, .discretionarySpending:
                SpendingCardContent(
                    bucket: bucket,
                    transactions: transactions,
                    cycleStart: cycleStart,
                    cycleEnd: cycleEnd,
                    daysRemaining: daysRemaining
                )

            case .emergencyFund:
                EmergencyFundCardContent(
                    bucket: bucket,
                    essentialMonthlySpend: essentialMonthlySpend
                )

            case .investments:
                InvestmentsCardContent(bucket: bucket)

            case .debtPaydown:
                EmptyView()
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .primaryCardStyle()
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack {
            // Icon and title
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: bucket.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(bucketColor)

                Text(bucket.displayName)
                    .headlineStyle(color: bucketColor)
            }

            Spacer()

            // Status badge
            statusBadge
        }
    }

    // MARK: - Status Badge

    private var status: PlanAdherenceStatus {
        switch bucket.type {
        case .essentialSpending, .discretionarySpending:
            return calculateSpendingStatus()
        case .emergencyFund:
            return calculateEmergencyFundStatus()
        case .investments:
            return bucket.linkedAccountIds.isEmpty ? .noData : .onTrack
        case .debtPaydown:
            return .noData
        }
    }

    private var statusBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xxs) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(Color(hex: status.color))
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, 4)
        .background(Color(hex: status.color).opacity(0.15))
        .cornerRadius(DesignTokens.CornerRadius.sm)
    }

    // MARK: - Status Calculations

    private func calculateSpendingStatus() -> PlanAdherenceStatus {
        guard bucket.allocatedAmount > 0 else { return .noData }

        let projected = TransactionAnalyzer.projectedCycleSpend(
            for: bucket.type,
            transactions: transactions,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd
        )

        let projectedPercentage = (projected / bucket.allocatedAmount) * 100

        if projectedPercentage <= 100 {
            return .onTrack
        } else if projectedPercentage <= 120 {
            return .warning
        } else {
            return .overBudget
        }
    }

    private func calculateEmergencyFundStatus() -> PlanAdherenceStatus {
        guard bucket.currentBalanceFromAccounts > 0 else {
            return bucket.linkedAccountIds.isEmpty ? .noData : .behind
        }

        let coverage = bucket.monthsOfCoverage(essentialMonthlySpend: essentialMonthlySpend)

        if coverage >= 6 { return .onTrack }
        if coverage >= 3 { return .warning }
        return .behind
    }
}

// MARK: - Spending Card Content

struct SpendingCardContent: View {
    let bucket: AllocationBucket
    let transactions: [Transaction]
    let cycleStart: Date
    let cycleEnd: Date
    let daysRemaining: Int

    private var spent: Double {
        TransactionAnalyzer.spentThisCycle(
            for: bucket.type,
            transactions: transactions,
            cycleStart: cycleStart
        )
    }

    private var remaining: Double {
        max(0, bucket.allocatedAmount - spent)
    }

    private var burnRate: Double {
        TransactionAnalyzer.dailyBurnRate(
            for: bucket.type,
            transactions: transactions,
            cycleStart: cycleStart
        )
    }

    private var percentUsed: Double {
        guard bucket.allocatedAmount > 0 else { return 0 }
        return (spent / bucket.allocatedAmount) * 100
    }

    private var status: PlanAdherenceStatus {
        guard bucket.allocatedAmount > 0 else { return .noData }

        let projected = TransactionAnalyzer.projectedCycleSpend(
            for: bucket.type,
            transactions: transactions,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd
        )

        let projectedPercentage = (projected / bucket.allocatedAmount) * 100

        if projectedPercentage <= 100 {
            return .onTrack
        } else if projectedPercentage <= 120 {
            return .warning
        } else {
            return .overBudget
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Subtitle
            Text("Remaining \(bucket.type == .discretionarySpending ? "discretionary " : "")balance")
                .captionStyle()

            // Primary metric - remaining amount
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text(formatCurrency(remaining))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("of \(formatCurrency(bucket.allocatedAmount))")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
            }

            // Progress bar
            progressBar

            // Percentage label
            HStack {
                Text("Budget used")
                    .captionStyle()
                Spacer()
                Text("\(Int(min(percentUsed, 100)))%")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
            }

            Divider()
                .background(DesignTokens.Colors.divider)

            // Secondary metrics
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // Daily burn rate
                HStack {
                    Text("Daily burn rate")
                        .captionStyle()
                    Spacer()
                    Text(formatCurrency(burnRate))
                        .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                        .fontWeight(.semibold)
                }

                // Days remaining
                HStack {
                    Text("Days remaining")
                        .captionStyle()
                    Spacer()
                    Text("\(daysRemaining)")
                        .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.cardOverlay1)

                // Progress fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: status.color))
                    .frame(width: geometry.size.width * min(CGFloat(percentUsed / 100), 1.0))
            }
        }
        .frame(height: 8)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Emergency Fund Card Content

struct EmergencyFundCardContent: View {
    let bucket: AllocationBucket
    let essentialMonthlySpend: Double

    private var balance: Double {
        bucket.currentBalanceFromAccounts
    }

    private var target: Double {
        bucket.targetAmount ?? (essentialMonthlySpend * 6)
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min((balance / target) * 100, 100)
    }

    private var monthsOfCoverage: Int {
        bucket.monthsOfCoverage(essentialMonthlySpend: essentialMonthlySpend)
    }

    private var status: PlanAdherenceStatus {
        guard balance > 0 else {
            return bucket.linkedAccountIds.isEmpty ? .noData : .behind
        }

        if monthsOfCoverage >= 6 { return .onTrack }
        if monthsOfCoverage >= 3 { return .warning }
        return .behind
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if bucket.linkedAccountIds.isEmpty {
                noAccountView
            } else {
                linkedAccountView
            }
        }
    }

    private var noAccountView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Monthly contribution goal")
                .captionStyle()

            Text(formatCurrency(bucket.allocatedAmount))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Link account prompt
            HStack {
                Image(systemName: "link.badge.plus")
                    .foregroundColor(Color(hex: bucket.color))
                Text("Link a savings account to track progress")
                    .subheadlineStyle(color: Color(hex: bucket.color))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(Color(hex: bucket.color).opacity(0.1))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }

    private var linkedAccountView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Subtitle
            Text("Current balance vs emergency goal")
                .captionStyle()

            // Primary metric - current balance
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text(formatCurrency(balance))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(DesignTokens.Colors.textPrimary)

                Text("of \(formatCurrency(target))")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
            }

            // Progress bar
            progressBar

            // Progress percentage
            HStack {
                Text("Progress towards goal")
                    .captionStyle()
                Spacer()
                Text("\(Int(progress))%")
                    .subheadlineStyle(color: DesignTokens.Colors.textSecondary)
            }

            Divider()
                .background(DesignTokens.Colors.divider)

            // Months of coverage
            HStack {
                Text("Months of coverage")
                    .captionStyle()
                Spacer()
                Text("\(monthsOfCoverage) \(monthsOfCoverage == 1 ? "month" : "months")")
                    .subheadlineStyle(color: DesignTokens.Colors.textPrimary)
                    .fontWeight(.semibold)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignTokens.Colors.cardOverlay1)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: status.color))
                    .frame(width: geometry.size.width * CGFloat(progress / 100))
            }
        }
        .frame(height: 8)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Investments Card Content

struct InvestmentsCardContent: View {
    let bucket: AllocationBucket

    private var balance: Double {
        bucket.currentBalanceFromAccounts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if bucket.linkedAccountIds.isEmpty {
                noAccountView
            } else {
                linkedAccountView
            }
        }
    }

    private var noAccountView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Monthly contribution goal")
                .captionStyle()

            Text(formatCurrency(bucket.allocatedAmount))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            // Link account prompt
            HStack {
                Image(systemName: "link.badge.plus")
                    .foregroundColor(Color(hex: bucket.color))
                Text("Link an investment account to track balance")
                    .subheadlineStyle(color: Color(hex: bucket.color))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.textSecondary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(Color(hex: bucket.color).opacity(0.1))
            .cornerRadius(DesignTokens.CornerRadius.md)
        }
    }

    private var linkedAccountView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Subtitle
            Text("Current investment balance")
                .captionStyle()

            // Primary metric - current balance
            Text(formatCurrency(balance))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(DesignTokens.Colors.textPrimary)

            Divider()
                .background(DesignTokens.Colors.divider)

            // Monthly contribution
            HStack {
                Text("Monthly contribution")
                    .captionStyle()
                Spacer()
                Text(formatCurrency(bucket.allocatedAmount))
                    .subheadlineStyle(color: Color(hex: bucket.color))
                    .fontWeight(.semibold)
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
