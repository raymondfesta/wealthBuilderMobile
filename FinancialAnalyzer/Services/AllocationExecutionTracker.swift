import Foundation

/// Service responsible for tracking allocation execution history and progress
class AllocationExecutionTracker {

    // MARK: - Public Methods

    /// Records a completed allocation to history
    func recordExecution(
        scheduledAllocation: ScheduledAllocation,
        actualAmount: Double,
        wasAutomatic: Bool = false,
        notes: String? = nil
    ) -> AllocationExecution {
        let execution = AllocationExecution(
            bucketType: scheduledAllocation.bucketType,
            scheduledAmount: scheduledAllocation.scheduledAmount,
            actualAmount: actualAmount,
            paycheckDate: scheduledAllocation.paycheckDate,
            completedAt: Date(),
            wasAutomatic: wasAutomatic,
            notes: notes,
            scheduledAllocationId: scheduledAllocation.id
        )

        print("✅ [ExecutionTracker] Recorded: \(execution.bucketType.rawValue), $\(Int(actualAmount))")

        return execution
    }

    /// Calculates progress toward bucket targets
    @MainActor
    func calculateProgress(
        executions: [AllocationExecution],
        bucket: AllocationBucket
    ) -> BucketProgressMetrics {
        let bucketExecutions = executions.forBucket(bucket.type)

        // Total allocated so far
        let totalAllocated = bucketExecutions.totalAllocated()

        // Calculate progress percentage (for buckets with targets)
        var progressPercentage: Double = 0
        var remainingToTarget: Double = 0
        var estimatedMonthsToTarget: Int?

        if let targetAmount = bucket.targetAmount {
            let currentBalance = bucket.currentBalanceFromAccounts + totalAllocated
            progressPercentage = min((currentBalance / targetAmount) * 100, 100)
            remainingToTarget = max(targetAmount - currentBalance, 0)

            // Estimate months to target based on average allocation
            if bucket.allocatedAmount > 0 {
                let monthsNeeded = ceil(remainingToTarget / bucket.allocatedAmount)
                estimatedMonthsToTarget = Int(monthsNeeded)
            }
        }

        return BucketProgressMetrics(
            bucketType: bucket.type,
            totalAllocatedToDate: totalAllocated,
            currentBalance: bucket.currentBalanceFromAccounts,
            targetAmount: bucket.targetAmount,
            progressPercentage: progressPercentage,
            remainingToTarget: remainingToTarget,
            estimatedMonthsToTarget: estimatedMonthsToTarget,
            allocationCount: bucketExecutions.count
        )
    }

    /// Calculates overall allocation statistics
    func calculateOverallStats(executions: [AllocationExecution]) -> AllocationExecutionStats {
        return AllocationExecutionStats(executions: executions)
    }

    /// Gets recent activity summary (last N days)
    func getRecentActivity(executions: [AllocationExecution], days: Int = 30) -> RecentActivitySummary {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return RecentActivitySummary(executions: [], days: days)
        }

        let recentExecutions = executions.filter { $0.completedAt >= cutoffDate }

        return RecentActivitySummary(executions: recentExecutions, days: days)
    }

    /// Detects allocation consistency (on-time vs. late)
    func analyzeConsistency(
        scheduledAllocations: [ScheduledAllocation],
        executions: [AllocationExecution]
    ) -> ConsistencyAnalysis {
        let completedAllocations = scheduledAllocations.filter { $0.status == .completed }

        guard !completedAllocations.isEmpty else {
            return ConsistencyAnalysis(
                totalScheduled: 0,
                completedOnTime: 0,
                completedLate: 0,
                skipped: 0,
                onTimeRate: 0,
                averageDelayDays: 0
            )
        }

        var onTimeCount = 0
        var lateCount = 0
        var totalDelayDays = 0

        for allocation in completedAllocations {
            // Find corresponding execution
            if let execution = executions.first(where: { $0.scheduledAllocationId == allocation.id }) {
                let calendar = Calendar.current
                let delayDays = calendar.dateComponents([.day], from: allocation.paycheckDate, to: execution.completedAt).day ?? 0

                if delayDays <= 0 {
                    onTimeCount += 1
                } else {
                    lateCount += 1
                    totalDelayDays += delayDays
                }
            }
        }

        let skippedCount = scheduledAllocations.filter { $0.status == .skipped }.count
        let totalScheduled = completedAllocations.count + skippedCount
        let onTimeRate = totalScheduled > 0 ? Double(onTimeCount) / Double(totalScheduled) : 0
        let avgDelay = lateCount > 0 ? Double(totalDelayDays) / Double(lateCount) : 0

        return ConsistencyAnalysis(
            totalScheduled: totalScheduled,
            completedOnTime: onTimeCount,
            completedLate: lateCount,
            skipped: skippedCount,
            onTimeRate: onTimeRate,
            averageDelayDays: avgDelay
        )
    }

    /// Generates achievement badges based on execution history
    func generateAchievements(executions: [AllocationExecution]) -> [Achievement] {
        var achievements: [Achievement] = []

        // First allocation
        if executions.count >= 1 {
            achievements.append(Achievement(
                id: "first_allocation",
                title: "First Allocation",
                description: "Completed your first allocation",
                icon: "star.fill",
                unlockedAt: executions.first?.completedAt ?? Date()
            ))
        }

        // Consistency streak (5 in a row on time)
        let recentOnTime = executions.suffix(5).filter { execution in
            Calendar.current.isDate(execution.completedAt, inSameDayAs: execution.paycheckDate)
        }
        if recentOnTime.count >= 5 {
            achievements.append(Achievement(
                id: "consistent_allocator",
                title: "Consistent Allocator",
                description: "Completed 5 allocations on time",
                icon: "checkmark.seal.fill",
                unlockedAt: recentOnTime.last?.completedAt ?? Date()
            ))
        }

        // Total allocated milestone ($10k)
        let totalAllocated = executions.totalAllocated()
        if totalAllocated >= 10000 {
            achievements.append(Achievement(
                id: "ten_k_milestone",
                title: "$10K Allocated",
                description: "Allocated $10,000 total across all buckets",
                icon: "dollarsign.circle.fill",
                unlockedAt: Date()
            ))
        }

        return achievements
    }

    /// Gets the last contribution amount for a specific bucket
    func lastContribution(
        for bucketType: AllocationBucketType,
        executions: [AllocationExecution]
    ) -> Double? {
        let bucketExecutions = executions.forBucket(bucketType)
            .sorted { $0.completedAt > $1.completedAt }

        return bucketExecutions.first?.actualAmount
    }

    /// Gets contributions count for current month (completed vs planned)
    func contributionsThisMonth(
        for bucketType: AllocationBucketType,
        executions: [AllocationExecution],
        scheduledAllocations: [ScheduledAllocation]
    ) -> (completed: Int, planned: Int) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = now.startOfMonth
        guard let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return (0, 0)
        }

        // Count completed executions this month
        let completedThisMonth = executions.filter { execution in
            execution.bucketType == bucketType &&
            execution.completedAt >= startOfMonth &&
            execution.completedAt < endOfMonth
        }.count

        // Count scheduled allocations this month for this bucket type
        let plannedThisMonth = scheduledAllocations.filter { allocation in
            allocation.paycheckDate >= startOfMonth &&
            allocation.paycheckDate < endOfMonth &&
            allocation.bucketType == bucketType
        }.count

        return (completed: completedThisMonth, planned: max(plannedThisMonth, completedThisMonth))
    }

    /// Calculates typical monthly spend/contribution for a bucket based on history
    func typicalMonthlyAmount(
        for bucketType: AllocationBucketType,
        executions: [AllocationExecution],
        months: Int = 3
    ) -> Double? {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .month, value: -months, to: Date()) else {
            return nil
        }

        let recentExecutions = executions.filter {
            $0.bucketType == bucketType && $0.completedAt >= cutoffDate
        }

        guard !recentExecutions.isEmpty else { return nil }

        let totalAmount = recentExecutions.reduce(0) { $0 + $1.actualAmount }

        // Calculate actual months with data
        let monthsWithData = Set(recentExecutions.map {
            calendar.dateComponents([.year, .month], from: $0.completedAt)
        }).count

        guard monthsWithData > 0 else { return nil }

        return totalAmount / Double(monthsWithData)
    }

    /// Prunes old executions beyond retention period
    func pruneOldExecutions(
        executions: [AllocationExecution],
        retentionMonths: Int = 12
    ) -> [AllocationExecution] {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .month, value: -retentionMonths, to: Date()) else {
            return executions
        }

        let pruned = executions.filter { $0.completedAt >= cutoffDate }

        let removedCount = executions.count - pruned.count
        if removedCount > 0 {
            print("🗑️ [ExecutionTracker] Pruned \(removedCount) old executions (older than \(retentionMonths) months)")
        }

        return pruned
    }
}

// MARK: - Supporting Models

/// Progress metrics for a specific bucket
struct BucketProgressMetrics {
    let bucketType: AllocationBucketType
    let totalAllocatedToDate: Double
    let currentBalance: Double
    let targetAmount: Double?
    let progressPercentage: Double
    let remainingToTarget: Double
    let estimatedMonthsToTarget: Int?
    let allocationCount: Int

    var formattedProgress: String {
        "\(Int(progressPercentage))%"
    }

    var isTargetReached: Bool {
        guard let target = targetAmount else { return false }
        return currentBalance >= target
    }
}

/// Recent activity summary
struct RecentActivitySummary {
    let executions: [AllocationExecution]
    let days: Int

    var totalAllocated: Double {
        executions.totalAllocated()
    }

    var allocationCount: Int {
        executions.count
    }

    var bucketBreakdown: [AllocationBucketType: Double] {
        Dictionary(grouping: executions, by: { $0.bucketType })
            .mapValues { $0.reduce(0) { $0 + $1.actualAmount } }
    }

    var isEmpty: Bool {
        executions.isEmpty
    }
}

/// Consistency analysis
struct ConsistencyAnalysis {
    let totalScheduled: Int
    let completedOnTime: Int
    let completedLate: Int
    let skipped: Int
    let onTimeRate: Double
    let averageDelayDays: Double

    var onTimePercentage: String {
        "\(Int(onTimeRate * 100))%"
    }

    var isConsistent: Bool {
        onTimeRate >= 0.8  // 80% or better
    }
}

/// Achievement model
struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let unlockedAt: Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: unlockedAt)
    }
}

// MARK: - Storage Extensions

extension Array where Element == AllocationExecution {
    /// Saves execution history to UserDefaults
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: "allocationExecutionHistory")
            print("💾 [AllocationExecution] Saved \(self.count) execution records")
        } else {
            print("❌ [AllocationExecution] Failed to encode execution history")
        }
    }

    /// Loads execution history from UserDefaults
    static func load() -> [AllocationExecution] {
        guard let data = UserDefaults.standard.data(forKey: "allocationExecutionHistory") else {
            print("📭 [AllocationExecution] No saved execution history found")
            return []
        }

        let decoder = JSONDecoder()
        if let executions = try? decoder.decode([AllocationExecution].self, from: data) {
            print("📦 [AllocationExecution] Loaded \(executions.count) execution records")
            return executions
        } else {
            print("❌ [AllocationExecution] Failed to decode execution history")
            return []
        }
    }

    /// Clears execution history from UserDefaults
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "allocationExecutionHistory")
        print("🗑️ [AllocationExecution] Cleared execution history")
    }
}
