import Foundation

/// Service responsible for analyzing transaction history to detect paycheck patterns
class PaycheckDetectionService {

    // MARK: - Configuration

    private let minimumPaycheckAmount: Double = 500  // Minimum amount to consider as paycheck
    private let amountTolerancePercentage: Double = 0.10  // ±10% tolerance for grouping
    private let minimumOccurrences: Int = 2  // Minimum paychecks needed to detect pattern
    private let analysisMonths: Int = 6  // How far back to analyze

    // MARK: - Detection Result

    struct DetectionResult {
        let schedule: PaycheckSchedule?
        let confidence: PaycheckDetectionConfidence
        let message: String

        var wasDetected: Bool {
            schedule != nil
        }
    }

    // MARK: - Internal Structures

    private struct PaycheckCandidate {
        let averageAmount: Double
        let transactions: [Transaction]
        let frequency: PaycheckFrequency
        let intervals: [Int]  // Days between deposits
        let anchorDates: [DateComponents]
        let confidence: PaycheckDetectionConfidence
    }

    // MARK: - Public Methods

    /// Detects paycheck schedule from transaction history
    func detectPaycheckSchedule(from transactions: [Transaction]) -> DetectionResult {
        print("🔍 [PaycheckDetection] Analyzing \(transactions.count) transactions...")

        // 1. Filter income transactions
        let incomeTransactions = filterIncomeTransactions(transactions)

        guard !incomeTransactions.isEmpty else {
            print("⚠️ [PaycheckDetection] No income transactions found")
            return DetectionResult(
                schedule: nil,
                confidence: .low,
                message: "No income transactions found in the last \(analysisMonths) months"
            )
        }

        print("💰 [PaycheckDetection] Found \(incomeTransactions.count) income transaction(s)")

        // 2. Group by similar amounts
        let groups = groupBySimilarAmounts(incomeTransactions)

        print("📊 [PaycheckDetection] Grouped into \(groups.count) income source(s)")

        // 3. Analyze each group to find patterns
        var candidates: [PaycheckCandidate] = []

        for group in groups {
            if let candidate = analyzeGroup(group) {
                candidates.append(candidate)
                print("✅ [PaycheckDetection] Found candidate: \(candidate.frequency.rawValue), $\(Int(candidate.averageAmount)), confidence: \(candidate.confidence.rawValue)")
            }
        }

        // 4. Select best candidate (highest confidence + most recent)
        guard let bestCandidate = selectBestCandidate(from: candidates) else {
            print("⚠️ [PaycheckDetection] No consistent pattern detected")
            return DetectionResult(
                schedule: nil,
                confidence: .low,
                message: "We couldn't detect a consistent paycheck pattern. Please set up manually."
            )
        }

        // 5. Build PaycheckSchedule
        let schedule = PaycheckSchedule(
            frequency: bestCandidate.frequency,
            estimatedAmount: bestCandidate.averageAmount,
            confidence: bestCandidate.confidence,
            isUserConfirmed: false,
            anchorDates: bestCandidate.anchorDates,
            sourceTransactionIds: bestCandidate.transactions.map { $0.id }
        )

        print("🎯 [PaycheckDetection] Detected schedule: \(schedule.frequency.rawValue), $\(Int(schedule.estimatedAmount)), \(schedule.confidence.rawValue) confidence")

        return DetectionResult(
            schedule: schedule,
            confidence: bestCandidate.confidence,
            message: buildConfidenceMessage(for: bestCandidate)
        )
    }

    // MARK: - Private Methods

    /// Filters transactions to only income transactions above minimum amount
    private func filterIncomeTransactions(_ transactions: [Transaction]) -> [Transaction] {
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -analysisMonths, to: Date()) ?? Date()

        return transactions.filter { transaction in
            // Income transactions with positive amounts
            transaction.bucketCategory == .income &&
            transaction.amount > minimumPaycheckAmount &&
            transaction.date >= cutoffDate &&
            !transaction.pending
        }
        .sorted { $0.date < $1.date }  // Sort chronologically
    }

    /// Groups transactions by similar amounts (±10% tolerance)
    private func groupBySimilarAmounts(_ transactions: [Transaction]) -> [[Transaction]] {
        var groups: [[Transaction]] = []

        for transaction in transactions {
            var foundGroup = false

            // Try to add to existing group
            for i in 0..<groups.count {
                if let firstInGroup = groups[i].first {
                    let avgAmount = groups[i].map { $0.amount }.reduce(0, +) / Double(groups[i].count)
                    let tolerance = avgAmount * amountTolerancePercentage

                    if abs(transaction.amount - avgAmount) <= tolerance {
                        groups[i].append(transaction)
                        foundGroup = true
                        break
                    }
                }
            }

            // Create new group if no match
            if !foundGroup {
                groups.append([transaction])
            }
        }

        // Filter groups with minimum occurrences
        return groups.filter { $0.count >= minimumOccurrences }
    }

    /// Analyzes a group of transactions to determine frequency and confidence
    private func analyzeGroup(_ transactions: [Transaction]) -> PaycheckCandidate? {
        guard transactions.count >= minimumOccurrences else { return nil }

        // Calculate average amount
        let averageAmount = transactions.map { $0.amount }.reduce(0, +) / Double(transactions.count)

        // Calculate intervals (days between transactions)
        var intervals: [Int] = []
        for i in 1..<transactions.count {
            let days = Calendar.current.dateComponents([.day], from: transactions[i-1].date, to: transactions[i].date).day ?? 0
            intervals.append(days)
        }

        guard !intervals.isEmpty else { return nil }

        // Determine frequency based on average interval
        let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let frequency = determineFrequency(from: avgInterval)

        // Calculate confidence
        let confidence = calculateConfidence(
            transactionCount: transactions.count,
            intervals: intervals,
            expectedInterval: frequency.daysInterval
        )

        // Generate anchor dates
        let anchorDates = generateAnchorDates(from: transactions, frequency: frequency)

        return PaycheckCandidate(
            averageAmount: averageAmount,
            transactions: transactions,
            frequency: frequency,
            intervals: intervals,
            anchorDates: anchorDates,
            confidence: confidence
        )
    }

    /// Determines frequency based on average interval
    private func determineFrequency(from avgInterval: Double) -> PaycheckFrequency {
        switch avgInterval {
        case 0..<10:
            return .weekly
        case 10..<21:
            return .biweekly
        case 21..<28:
            return .semimonthly
        default:
            return .monthly
        }
    }

    /// Calculates confidence score based on consistency
    private func calculateConfidence(transactionCount: Int, intervals: [Int], expectedInterval: Double) -> PaycheckDetectionConfidence {
        // Factor 1: Number of occurrences
        let countScore: Double
        if transactionCount >= 6 {
            countScore = 1.0
        } else if transactionCount >= 4 {
            countScore = 0.7
        } else {
            countScore = 0.4
        }

        // Factor 2: Interval consistency (variance from expected)
        let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let variance = intervals.map { abs(Double($0) - expectedInterval) }.reduce(0, +) / Double(intervals.count)
        let variancePercentage = variance / expectedInterval

        let consistencyScore: Double
        if variancePercentage < 0.05 {
            consistencyScore = 1.0
        } else if variancePercentage < 0.10 {
            consistencyScore = 0.7
        } else {
            consistencyScore = 0.4
        }

        // Combined score
        let overallScore = (countScore + consistencyScore) / 2.0

        if overallScore >= 0.85 {
            return .high
        } else if overallScore >= 0.55 {
            return .medium
        } else {
            return .low
        }
    }

    /// Generates anchor dates based on frequency
    private func generateAnchorDates(from transactions: [Transaction], frequency: PaycheckFrequency) -> [DateComponents] {
        let calendar = Calendar.current

        switch frequency {
        case .weekly, .biweekly:
            // Use most common weekday
            let weekdays = transactions.map { calendar.component(.weekday, from: $0.date) }
            let mostCommonWeekday = mostFrequent(in: weekdays) ?? 6  // Default to Friday
            return [DateComponents(weekday: mostCommonWeekday)]

        case .semimonthly:
            // Use two most common days of month
            let days = transactions.map { calendar.component(.day, from: $0.date) }
            let sorted = days.sorted()

            if sorted.count >= 2 {
                // Take first and middle (approximates 1st and 15th pattern)
                let first = sorted[0]
                let middle = sorted[sorted.count / 2]
                return [DateComponents(day: first), DateComponents(day: middle)]
            } else {
                return [DateComponents(day: 1), DateComponents(day: 15)]  // Default
            }

        case .monthly:
            // Use most common day of month
            let days = transactions.map { calendar.component(.day, from: $0.date) }
            let mostCommonDay = mostFrequent(in: days) ?? 1  // Default to 1st
            return [DateComponents(day: mostCommonDay)]
        }
    }

    /// Finds most frequent element in array
    private func mostFrequent<T: Hashable>(in array: [T]) -> T? {
        let counts = Dictionary(grouping: array, by: { $0 }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Selects best candidate from multiple options
    private func selectBestCandidate(from candidates: [PaycheckCandidate]) -> PaycheckCandidate? {
        guard !candidates.isEmpty else { return nil }

        // Prioritize by confidence, then by transaction count
        return candidates.max { c1, c2 in
            if c1.confidence == c2.confidence {
                return c1.transactions.count < c2.transactions.count
            }

            // Compare confidence levels
            let confidenceLevels: [PaycheckDetectionConfidence] = [.low, .medium, .high]
            let index1 = confidenceLevels.firstIndex(of: c1.confidence) ?? 0
            let index2 = confidenceLevels.firstIndex(of: c2.confidence) ?? 0
            return index1 < index2
        }
    }

    /// Builds user-friendly message based on confidence
    private func buildConfidenceMessage(for candidate: PaycheckCandidate) -> String {
        switch candidate.confidence {
        case .high:
            return "We detected a consistent \(candidate.frequency.rawValue.lowercased()) paycheck pattern with \(candidate.transactions.count) deposits averaging \(formatCurrency(candidate.averageAmount))."
        case .medium:
            return "We found a likely \(candidate.frequency.rawValue.lowercased()) pattern with \(candidate.transactions.count) deposits. Please verify the details below."
        case .low:
            return "We detected a possible \(candidate.frequency.rawValue.lowercased()) pattern, but with limited data. Please review and adjust as needed."
        case .manual:
            return ""
        }
    }

    /// Formats currency for display
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
