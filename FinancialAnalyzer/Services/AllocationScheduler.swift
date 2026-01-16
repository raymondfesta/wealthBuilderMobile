import Foundation

/// Service responsible for generating scheduled allocation events
class AllocationScheduler {

    // MARK: - Public Methods

    /// Generates scheduled allocations for the next N months
    @MainActor
    func generateSchedule(
        paycheckSchedule: PaycheckSchedule,
        allocationBuckets: [AllocationBucket],
        monthsAhead: Int = 3,
        startDate: Date = Date()
    ) -> [ScheduledAllocation] {
        print("📅 [AllocationScheduler] Generating schedule for next \(monthsAhead) months...")

        // Calculate how many paychecks we need based on frequency
        let paychecksNeeded = calculatePaychecksNeeded(
            frequency: paycheckSchedule.frequency,
            monthsAhead: monthsAhead
        )

        // Get next N paycheck dates
        let paycheckDates = paycheckSchedule.nextPaycheckDates(from: startDate, count: paychecksNeeded)

        guard !paycheckDates.isEmpty else {
            print("⚠️ [AllocationScheduler] Failed to generate paycheck dates")
            return []
        }

        print("📆 [AllocationScheduler] Generated \(paycheckDates.count) paycheck dates")

        // Generate allocation events for each paycheck × each bucket
        var scheduledAllocations: [ScheduledAllocation] = []

        for date in paycheckDates {
            for bucket in allocationBuckets {
                // Skip buckets with zero allocation
                guard bucket.allocatedAmount > 0 else { continue }

                let allocation = ScheduledAllocation(
                    paycheckDate: date,
                    bucketType: bucket.type,
                    scheduledAmount: bucket.allocatedAmount,
                    status: .upcoming
                )

                scheduledAllocations.append(allocation)
            }
        }

        print("✅ [AllocationScheduler] Generated \(scheduledAllocations.count) scheduled allocations")

        return scheduledAllocations.sorted { $0.paycheckDate < $1.paycheckDate }
    }

    /// Regenerates schedule (use when paycheck schedule or buckets change)
    @MainActor
    func regenerateSchedule(
        paycheckSchedule: PaycheckSchedule,
        allocationBuckets: [AllocationBucket],
        existingAllocations: [ScheduledAllocation],
        monthsAhead: Int = 3
    ) -> [ScheduledAllocation] {
        print("🔄 [AllocationScheduler] Regenerating schedule...")

        // Keep completed/skipped allocations, discard pending ones
        let historicalAllocations = existingAllocations.filter { allocation in
            allocation.status == .completed || allocation.status == .skipped
        }

        // Generate new upcoming allocations starting from today
        let newUpcoming = generateSchedule(
            paycheckSchedule: paycheckSchedule,
            allocationBuckets: allocationBuckets,
            monthsAhead: monthsAhead,
            startDate: Date()
        )

        // Combine: keep historical + add new upcoming
        let combined = historicalAllocations + newUpcoming

        print("✅ [AllocationScheduler] Regenerated: \(historicalAllocations.count) historical + \(newUpcoming.count) upcoming")

        return combined.sorted { $0.paycheckDate < $1.paycheckDate }
    }

    /// Updates specific allocation amounts when buckets change (preserves dates)
    @MainActor
    func updateAllocationAmounts(
        scheduledAllocations: [ScheduledAllocation],
        updatedBuckets: [AllocationBucket]
    ) -> [ScheduledAllocation] {
        print("💰 [AllocationScheduler] Updating allocation amounts...")

        // Create lookup dictionary for new amounts
        let bucketAmounts = Dictionary(uniqueKeysWithValues: updatedBuckets.map { ($0.type, $0.allocatedAmount) })

        // Update amounts for upcoming allocations only
        var updated = scheduledAllocations.map { allocation -> ScheduledAllocation in
            var updated = allocation

            // Only update upcoming/reminderSent allocations
            if allocation.status.isPending, let newAmount = bucketAmounts[allocation.bucketType] {
                updated.scheduledAmount = newAmount
                updated.updatedAt = Date()
            }

            return updated
        }

        // Remove allocations for buckets that now have zero amount
        updated = updated.filter { allocation in
            // Keep completed/skipped regardless
            if !allocation.status.isPending {
                return true
            }

            // Keep upcoming if bucket still has allocation
            if let amount = bucketAmounts[allocation.bucketType], amount > 0 {
                return true
            }

            return false
        }

        print("✅ [AllocationScheduler] Updated \(updated.count) allocations")

        return updated.sorted { $0.paycheckDate < $1.paycheckDate }
    }

    /// Adds missing allocations when new buckets are added
    @MainActor
    func addMissingAllocations(
        scheduledAllocations: [ScheduledAllocation],
        newBucket: AllocationBucket,
        paycheckSchedule: PaycheckSchedule,
        monthsAhead: Int = 3
    ) -> [ScheduledAllocation] {
        print("➕ [AllocationScheduler] Adding allocations for new bucket: \(newBucket.type.rawValue)")

        // Get unique paycheck dates from existing schedule
        let existingPaycheckDates = Set(scheduledAllocations.map { $0.paycheckDate })
            .filter { $0 >= Date() }  // Only future dates
            .sorted()

        // Generate new allocations for this bucket
        var newAllocations = scheduledAllocations

        for date in existingPaycheckDates {
            // Check if allocation already exists for this date + bucket
            let alreadyExists = scheduledAllocations.contains { allocation in
                allocation.paycheckDate == date && allocation.bucketType == newBucket.type
            }

            if !alreadyExists && newBucket.allocatedAmount > 0 {
                let allocation = ScheduledAllocation(
                    paycheckDate: date,
                    bucketType: newBucket.type,
                    scheduledAmount: newBucket.allocatedAmount,
                    status: .upcoming
                )
                newAllocations.append(allocation)
            }
        }

        print("✅ [AllocationScheduler] Added \(newAllocations.count - scheduledAllocations.count) new allocations")

        return newAllocations.sorted { $0.paycheckDate < $1.paycheckDate }
    }

    /// Prunes old allocations beyond retention period
    func pruneOldAllocations(
        scheduledAllocations: [ScheduledAllocation],
        retentionMonths: Int = 12
    ) -> [ScheduledAllocation] {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .month, value: -retentionMonths, to: Date()) else {
            return scheduledAllocations
        }

        let pruned = scheduledAllocations.filter { allocation in
            // Keep all upcoming allocations
            if allocation.status.isPending {
                return true
            }

            // Keep historical allocations within retention period
            return allocation.paycheckDate >= cutoffDate
        }

        let removedCount = scheduledAllocations.count - pruned.count
        if removedCount > 0 {
            print("🗑️ [AllocationScheduler] Pruned \(removedCount) old allocations (older than \(retentionMonths) months)")
        }

        return pruned
    }

    // MARK: - Helper Methods

    /// Calculates how many paychecks are needed to cover N months
    private func calculatePaychecksNeeded(frequency: PaycheckFrequency, monthsAhead: Int) -> Int {
        let paychecksPerYear = Double(frequency.paychecksPerYear)
        let paychecksPerMonth = paychecksPerYear / 12.0
        let needed = Int(ceil(paychecksPerMonth * Double(monthsAhead)))

        return max(needed, 1)  // At least 1
    }

    /// Generates preview text for schedule
    @MainActor
    func generateSchedulePreview(
        paycheckSchedule: PaycheckSchedule,
        allocationBuckets: [AllocationBucket],
        previewCount: Int = 3
    ) -> String {
        let paycheckDates = paycheckSchedule.nextPaycheckDates(from: Date(), count: previewCount)

        guard !paycheckDates.isEmpty else {
            return "No upcoming paychecks"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let dateStrings = paycheckDates.map { formatter.string(from: $0) }
        let joined = dateStrings.joined(separator: ", ")

        let totalPerPaycheck = allocationBuckets.reduce(0) { $0 + $1.allocatedAmount }
        let formattedAmount = formatCurrency(totalPerPaycheck)

        return "Next paychecks: \(joined) • \(formattedAmount) per payday"
    }

    /// Formats currency
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Extensions for Storage

extension Array where Element == ScheduledAllocation {
    /// Saves scheduled allocations to UserDefaults
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: "scheduledAllocations")
            print("💾 [ScheduledAllocation] Saved \(self.count) scheduled allocations")
        } else {
            print("❌ [ScheduledAllocation] Failed to encode allocations")
        }
    }

    /// Loads scheduled allocations from UserDefaults
    static func load() -> [ScheduledAllocation] {
        guard let data = UserDefaults.standard.data(forKey: "scheduledAllocations") else {
            print("📭 [ScheduledAllocation] No saved allocations found")
            return []
        }

        let decoder = JSONDecoder()
        if let allocations = try? decoder.decode([ScheduledAllocation].self, from: data) {
            print("📦 [ScheduledAllocation] Loaded \(allocations.count) scheduled allocations")
            return allocations
        } else {
            print("❌ [ScheduledAllocation] Failed to decode allocations")
            return []
        }
    }

    /// Clears saved allocations from UserDefaults
    static func clear() {
        UserDefaults.standard.removeObject(forKey: "scheduledAllocations")
        print("🗑️ [ScheduledAllocation] Cleared saved allocations")
    }
}
