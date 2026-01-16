import Foundation

/// Preset allocation options provided by the backend for Low/Recommended/High tiers
struct PresetOptions: Codable {
    let low: PresetValue
    let recommended: PresetValue
    let high: PresetValue

    /// Get value for a specific tier
    func value(for tier: PresetTier) -> PresetValue {
        switch tier {
        case .low:
            return low
        case .recommended:
            return recommended
        case .high:
            return high
        }
    }
}

/// Individual preset value with amount and percentage
struct PresetValue: Codable {
    let amount: Double
    let percentage: Double
}
