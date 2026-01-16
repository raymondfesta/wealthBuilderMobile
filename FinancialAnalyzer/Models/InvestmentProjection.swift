import Foundation

/// Investment growth projection showing potential future value based on regular contributions
struct InvestmentProjection: Codable {
    let currentBalance: Double
    let lowProjection: ProjectionTimeline
    let recommendedProjection: ProjectionTimeline
    let highProjection: ProjectionTimeline

    /// Get projection timeline for a specific tier
    func timeline(for tier: PresetTier) -> ProjectionTimeline {
        switch tier {
        case .low:
            return lowProjection
        case .recommended:
            return recommendedProjection
        case .high:
            return highProjection
        }
    }
}

/// Timeline showing projected values at 10, 20, and 30 years
struct ProjectionTimeline: Codable {
    let monthlyContribution: Double
    let year10: Double
    let year20: Double
    let year30: Double

    /// Calculate the total gain from contributions and growth
    func totalGain(years: Int) -> Double {
        let value: Double
        switch years {
        case 10:
            value = year10
        case 20:
            value = year20
        case 30:
            value = year30
        default:
            return 0
        }

        let totalContributions = monthlyContribution * 12 * Double(years)
        return value - totalContributions
    }

    /// Calculate ROI percentage
    func roi(years: Int) -> Double {
        let totalContributions = monthlyContribution * 12 * Double(years)
        guard totalContributions > 0 else { return 0 }

        let value: Double
        switch years {
        case 10:
            value = year10
        case 20:
            value = year20
        case 30:
            value = year30
        default:
            return 0
        }

        return ((value - totalContributions) / totalContributions) * 100
    }
}
