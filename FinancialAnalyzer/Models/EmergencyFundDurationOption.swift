import Foundation

/// Emergency fund duration option with target calculation and monthly contribution presets
struct EmergencyFundDurationOption: Codable, Identifiable {
    var id: Int { months }

    let months: Int // 3, 6, or 12
    let targetAmount: Double // Total amount needed for this duration
    let shortfall: Double // Amount still needed (target - currentBalance)
    let monthlyContribution: PresetOptions // Low/Rec/High monthly contribution amounts
    let isRecommended: Bool // Based on income stability from health metrics

    /// Calculate time to reach goal at a given tier
    func timeToGoal(tier: PresetTier) -> Int? {
        let contribution = monthlyContribution.value(for: tier).amount
        guard contribution > 0, shortfall > 0 else { return nil }
        return Int(ceil(shortfall / contribution))
    }

    /// Check if goal is already met
    var isGoalMet: Bool {
        return shortfall <= 0
    }
}
