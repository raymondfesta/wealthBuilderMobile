import Foundation

/// Frequency of paycheck deposits
enum PaycheckFrequency: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case semimonthly = "Semi-monthly"
    case monthly = "Monthly"

    var displayName: String {
        self.rawValue
    }

    var description: String {
        switch self {
        case .weekly:
            return "Every week"
        case .biweekly:
            return "Every 2 weeks"
        case .semimonthly:
            return "Twice per month (e.g., 1st and 15th)"
        case .monthly:
            return "Once per month"
        }
    }

    /// Number of paychecks per year
    var paychecksPerYear: Int {
        switch self {
        case .weekly:
            return 52
        case .biweekly:
            return 26
        case .semimonthly:
            return 24
        case .monthly:
            return 12
        }
    }

    /// Approximate days between paychecks
    var daysInterval: Double {
        switch self {
        case .weekly:
            return 7
        case .biweekly:
            return 14
        case .semimonthly:
            return 15 // Approximate (actually varies)
        case .monthly:
            return 30 // Approximate
        }
    }
}

/// Confidence level for paycheck detection
enum PaycheckDetectionConfidence: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case manual = "Manual" // User manually created schedule

    var description: String {
        switch self {
        case .high:
            return "We detected a consistent pattern with high confidence"
        case .medium:
            return "We found a likely pattern, but please verify"
        case .low:
            return "Pattern detected with limited data, please confirm"
        case .manual:
            return "Manually configured by you"
        }
    }

    var icon: String {
        switch self {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "checkmark.circle"
        case .low:
            return "questionmark.circle"
        case .manual:
            return "hand.raised.fill"
        }
    }

    var color: String {
        switch self {
        case .high:
            return "#34C759" // Green
        case .medium:
            return "#FF9500" // Orange
        case .low:
            return "#FF3B30" // Red
        case .manual:
            return "#007AFF" // Blue
        }
    }
}

/// Represents a detected or manually configured paycheck schedule
struct PaycheckSchedule: Codable, Identifiable {
    let id: String
    var frequency: PaycheckFrequency
    var estimatedAmount: Double
    var confidence: PaycheckDetectionConfidence
    var isUserConfirmed: Bool
    var createdAt: Date
    var updatedAt: Date

    // Anchor dates for scheduling
    // - For weekly/biweekly: Single anchor date (e.g., every Friday)
    // - For semi-monthly: Two anchor dates (e.g., 1st and 15th)
    // - For monthly: Single anchor date (e.g., last Friday of month)
    var anchorDates: [DateComponents] // Day of month OR day of week

    // Optional: Detected source transaction IDs (for reference)
    var sourceTransactionIds: [String]

    init(
        id: String = UUID().uuidString,
        frequency: PaycheckFrequency,
        estimatedAmount: Double,
        confidence: PaycheckDetectionConfidence = .manual,
        isUserConfirmed: Bool = false,
        anchorDates: [DateComponents],
        sourceTransactionIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.frequency = frequency
        self.estimatedAmount = estimatedAmount
        self.confidence = confidence
        self.isUserConfirmed = isUserConfirmed
        self.anchorDates = anchorDates
        self.sourceTransactionIds = sourceTransactionIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Updates the schedule (marks as user-confirmed and manual confidence)
    mutating func update(frequency: PaycheckFrequency, amount: Double, anchorDates: [DateComponents]) {
        self.frequency = frequency
        self.estimatedAmount = amount
        self.anchorDates = anchorDates
        self.isUserConfirmed = true
        self.confidence = .manual
        self.updatedAt = Date()
    }

    /// Confirms the detected schedule without changes
    mutating func confirm() {
        self.isUserConfirmed = true
        self.updatedAt = Date()
    }

    /// Generates next N paycheck dates from a given start date
    func nextPaycheckDates(from startDate: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        switch frequency {
        case .weekly, .biweekly:
            // Use anchor date's weekday
            guard let anchorComponents = anchorDates.first,
                  let weekday = anchorComponents.weekday else {
                return []
            }

            var currentDate = startDate
            let interval = frequency == .weekly ? 7 : 14

            // Find next occurrence of weekday
            currentDate = calendar.nextDate(
                after: currentDate,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime
            ) ?? currentDate

            for _ in 0..<count {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: interval, to: currentDate) ?? currentDate
            }

        case .semimonthly:
            // Two dates per month (e.g., 1st and 15th)
            guard anchorDates.count == 2 else { return [] }

            var currentMonth = calendar.dateComponents([.year, .month], from: startDate)

            for _ in 0..<count {
                for anchor in anchorDates.sorted(by: { ($0.day ?? 0) < ($1.day ?? 0) }) {
                    if let day = anchor.day {
                        var components = currentMonth
                        components.day = day

                        if let date = calendar.date(from: components), date >= startDate {
                            dates.append(date)

                            if dates.count >= count {
                                return dates
                            }
                        }
                    }
                }

                // Move to next month
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: currentMonth)!) {
                    currentMonth = calendar.dateComponents([.year, .month], from: nextMonth)
                }
            }

        case .monthly:
            // One date per month (e.g., last Friday, or 15th)
            guard let anchorComponents = anchorDates.first else { return [] }

            var currentMonth = calendar.dateComponents([.year, .month], from: startDate)

            for _ in 0..<count {
                var components = currentMonth
                components.day = anchorComponents.day
                components.weekday = anchorComponents.weekday

                if let date = calendar.date(from: components), date >= startDate {
                    dates.append(date)
                } else if let monthStart = calendar.date(from: currentMonth) {
                    // If anchor day doesn't exist in month, find next occurrence
                    if let nextDate = calendar.nextDate(
                        after: monthStart,
                        matching: anchorComponents,
                        matchingPolicy: .nextTime
                    ) {
                        // Make sure it's in the same month
                        let nextComponents = calendar.dateComponents([.year, .month], from: nextDate)
                        if nextComponents == currentMonth {
                            dates.append(nextDate)
                        }
                    }
                }

                // Move to next month
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: currentMonth)!) {
                    currentMonth = calendar.dateComponents([.year, .month], from: nextMonth)
                }
            }
        }

        return dates
    }

    /// Calculates average monthly income based on frequency
    var averageMonthlyIncome: Double {
        let yearlyIncome = estimatedAmount * Double(frequency.paychecksPerYear)
        return yearlyIncome / 12.0
    }
}

