import Foundation

/// Represents a completed allocation that has been executed (logged in history)
struct AllocationExecution: Codable, Identifiable {
    let id: String
    let bucketType: AllocationBucketType
    let scheduledAmount: Double      // Original planned amount
    let actualAmount: Double         // Amount user actually allocated (may differ)
    let paycheckDate: Date          // Original paycheck date
    let completedAt: Date           // When user marked it complete
    var wasAutomatic: Bool          // Future: true if auto-transferred via ACH
    var notes: String?              // Optional user notes
    let scheduledAllocationId: String // Link back to ScheduledAllocation

    init(
        id: String = UUID().uuidString,
        bucketType: AllocationBucketType,
        scheduledAmount: Double,
        actualAmount: Double,
        paycheckDate: Date,
        completedAt: Date = Date(),
        wasAutomatic: Bool = false,
        notes: String? = nil,
        scheduledAllocationId: String
    ) {
        self.id = id
        self.bucketType = bucketType
        self.scheduledAmount = scheduledAmount
        self.actualAmount = actualAmount
        self.paycheckDate = paycheckDate
        self.completedAt = completedAt
        self.wasAutomatic = wasAutomatic
        self.notes = notes
        self.scheduledAllocationId = scheduledAllocationId
    }

    /// Whether the actual amount differs from scheduled
    var isDifferentThanPlanned: Bool {
        abs(actualAmount - scheduledAmount) > 0.01
    }

    /// Difference from planned amount (positive = over, negative = under)
    var varianceFromPlan: Double {
        actualAmount - scheduledAmount
    }

    /// Percentage variance from plan
    var variancePercentage: Double {
        guard scheduledAmount > 0 else { return 0 }
        return (varianceFromPlan / scheduledAmount) * 100
    }

    /// Formatted completed date (e.g., "Nov 15, 2025")
    var formattedCompletedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: completedAt)
    }

    /// Short formatted date (e.g., "Nov 15")
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: completedAt)
    }

    /// Month/year string for grouping (e.g., "November 2025")
    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: completedAt)
    }
}

// MARK: - Grouping Helper for History View

/// Groups allocation executions by month for history display
struct MonthlyAllocationGroup: Identifiable {
    let monthYear: String            // "November 2025"
    let executions: [AllocationExecution]

    var id: String { monthYear }

    /// Total amount allocated this month
    var totalAllocated: Double {
        executions.reduce(0) { $0 + $1.actualAmount }
    }

    /// Number of individual allocations
    var allocationCount: Int {
        executions.count
    }

    /// Breakdown by bucket type
    var bucketBreakdown: [AllocationBucketType: Double] {
        Dictionary(grouping: executions, by: { $0.bucketType })
            .mapValues { $0.reduce(0) { $0 + $1.actualAmount } }
    }

    /// Number of allocations that differed from plan
    var adjustedCount: Int {
        executions.filter { $0.isDifferentThanPlanned }.count
    }

    /// Formatted summary (e.g., "12 allocations • $3,600")
    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let amountString = formatter.string(from: NSNumber(value: totalAllocated)) ?? "$0"

        return "\(allocationCount) allocation\(allocationCount == 1 ? "" : "s") • \(amountString)"
    }
}

// MARK: - Extension for Array Grouping

extension Array where Element == AllocationExecution {
    /// Groups executions by month
    func groupedByMonth() -> [MonthlyAllocationGroup] {
        let grouped = Dictionary(grouping: self) { $0.monthYearString }
        return grouped.map { MonthlyAllocationGroup(monthYear: $0.key, executions: $0.value) }
            .sorted { group1, group2 in
                // Sort by most recent first
                guard let date1 = group1.executions.first?.completedAt,
                      let date2 = group2.executions.first?.completedAt else {
                    return false
                }
                return date1 > date2
            }
    }

    /// Filters executions for a specific bucket type
    func forBucket(_ bucketType: AllocationBucketType) -> [AllocationExecution] {
        filter { $0.bucketType == bucketType }
    }

    /// Filters executions for a specific date range
    func withinDateRange(_ dateRange: ClosedRange<Date>) -> [AllocationExecution] {
        filter { dateRange.contains($0.completedAt) }
    }

    /// Calculates total allocated for a specific bucket
    func totalAllocated(for bucketType: AllocationBucketType) -> Double {
        forBucket(bucketType).reduce(0) { $0 + $1.actualAmount }
    }

    /// Calculates total allocated across all buckets
    func totalAllocated() -> Double {
        reduce(0) { $0 + $1.actualAmount }
    }

    /// Gets executions from the last N months
    func lastNMonths(_ n: Int) -> [AllocationExecution] {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .month, value: -n, to: Date()) else {
            return []
        }
        return filter { $0.completedAt >= cutoffDate }
    }

    /// Gets most recent execution for each bucket type
    func latestPerBucket() -> [AllocationBucketType: AllocationExecution] {
        let sorted = self.sorted { $0.completedAt > $1.completedAt }
        var result: [AllocationBucketType: AllocationExecution] = [:]

        for execution in sorted {
            if result[execution.bucketType] == nil {
                result[execution.bucketType] = execution
            }
        }

        return result
    }
}

// MARK: - Summary Statistics

/// Summary statistics for allocation execution history
struct AllocationExecutionStats {
    let totalExecutions: Int
    let totalAllocated: Double
    let averagePerAllocation: Double
    let onTimeCompletionRate: Double // Percentage completed on scheduled date
    let adjustmentRate: Double       // Percentage that differed from plan
    let bucketBreakdown: [AllocationBucketType: Double]

    init(executions: [AllocationExecution]) {
        self.totalExecutions = executions.count
        self.totalAllocated = executions.reduce(0) { $0 + $1.actualAmount }
        self.averagePerAllocation = totalExecutions > 0 ? totalAllocated / Double(totalExecutions) : 0

        // On-time rate: completed on same day as paycheck
        let onTimeCount = executions.filter { execution in
            Calendar.current.isDate(execution.completedAt, inSameDayAs: execution.paycheckDate)
        }.count
        self.onTimeCompletionRate = totalExecutions > 0 ? Double(onTimeCount) / Double(totalExecutions) : 0

        // Adjustment rate: actual differs from scheduled
        let adjustedCount = executions.filter { $0.isDifferentThanPlanned }.count
        self.adjustmentRate = totalExecutions > 0 ? Double(adjustedCount) / Double(totalExecutions) : 0

        // Bucket breakdown
        self.bucketBreakdown = Dictionary(grouping: executions, by: { $0.bucketType })
            .mapValues { $0.reduce(0) { $0 + $1.actualAmount } }
    }

    /// Formatted on-time percentage (e.g., "87%")
    var onTimePercentageString: String {
        "\(Int(onTimeCompletionRate * 100))%"
    }

    /// Formatted adjustment percentage (e.g., "12%")
    var adjustmentPercentageString: String {
        "\(Int(adjustmentRate * 100))%"
    }
}
