import Foundation
import SwiftUI

/// ViewModel for managing allocation bucket editing state and rebalancing logic
@MainActor
class AllocationEditorViewModel: ObservableObject {
    /// Current edited amounts for each bucket (bucketId -> amount)
    @Published var bucketAmounts: [String: Double] = [:]

    /// Original amounts from backend recommendation (for reset functionality)
    @Published var originalAmounts: [String: Double] = [:]

    /// Initializer
    init() {}

    /// Total allocated across all buckets
    var totalAllocated: Double {
        bucketAmounts.values.reduce(0, +)
    }

    /// Calculate allocation percentage relative to income
    func allocationPercentage(monthlyIncome: Double) -> Double {
        guard monthlyIncome > 0 else { return 0 }
        return (totalAllocated / monthlyIncome) * 100
    }

    /// Check if allocation is valid (within 0.1% of 100%)
    func isValid(monthlyIncome: Double, allBuckets: [AllocationBucket]) -> Bool {
        let percentDiff = abs(allocationPercentage(monthlyIncome: monthlyIncome) - 100.0)
        let allocationValid = percentDiff < 0.1

        // Check discretionary spending limit
        if let discretionaryBucket = allBuckets.first(where: { $0.type == .discretionarySpending }),
           let discretionaryAmount = bucketAmounts[discretionaryBucket.id] {
            let validation = discretionaryBucket.validateDiscretionarySpending(monthlyIncome: monthlyIncome)
            if !validation.isValid {
                return false
            }
        }

        return allocationValid
    }

    /// Initialize with bucket amounts
    func initialize(buckets: [AllocationBucket]) {
        bucketAmounts.removeAll()
        originalAmounts.removeAll()

        for bucket in buckets {
            bucketAmounts[bucket.id] = bucket.allocatedAmount
            originalAmounts[bucket.id] = bucket.allocatedAmount
        }

        print("💰 [AllocationEditor] Initialized with \(buckets.count) buckets, total: $\(Int(totalAllocated))")
    }

    /// Reset a specific bucket to its original amount
    func resetBucket(id: String) {
        if let originalAmount = originalAmounts[id] {
            bucketAmounts[id] = originalAmount
            print("💰 [AllocationEditor] Reset bucket \(id) to $\(Int(originalAmount))")
        }
    }

    /// Update a bucket amount and rebalance others
    /// Returns list of auto-adjustments made to other buckets (for toast notification)
    func updateBucket(
        id: String,
        newAmount: Double,
        monthlyIncome: Double,
        allBuckets: [AllocationBucket]
    ) -> [AllocationAdjustment] {
        guard let changedBucket = allBuckets.first(where: { $0.id == id }) else {
            print("⚠️ [AllocationEditor] Bucket \(id) not found")
            return []
        }

        // Prevent modification of non-modifiable buckets
        guard changedBucket.isModifiable else {
            print("⚠️ [AllocationEditor] Cannot modify locked bucket: \(changedBucket.displayName)")
            return []
        }

        let oldAmount = bucketAmounts[id] ?? changedBucket.allocatedAmount
        let delta = newAmount - oldAmount

        print("💰 [AllocationEditor] '\(changedBucket.displayName)' changed: $\(Int(oldAmount)) → $\(Int(newAmount)) (Δ\(delta > 0 ? "+" : "")\(Int(delta)))")

        // Update the changed bucket
        bucketAmounts[id] = newAmount

        // Update change indicator
        if let original = originalAmounts[id] {
            changedBucket.updateChange(from: original)
        }

        // If delta is negligible, no rebalancing needed
        guard abs(delta) > 0.01 else {
            print("   ↳ No rebalancing needed (delta too small)")
            return []
        }

        // Get other modifiable buckets for rebalancing
        let otherModifiableBuckets = allBuckets.filter { bucket in
            bucket.id != id && bucket.isModifiable
        }

        guard !otherModifiableBuckets.isEmpty else {
            print("   ↳ No other modifiable buckets to adjust")
            return []
        }

        print("   ↳ Rebalancing \(otherModifiableBuckets.count) modifiable bucket(s):")

        // Smart priority-based rebalancing
        // Priority: Discretionary → Investments → Debt Paydown → Emergency Fund
        // Rationale: Preserve emergency fund as last resort, adjust flexible spending first
        var remainingDelta = -delta // Amount to distribute to other buckets
        var adjustedBuckets: [(bucket: AllocationBucket, oldAmount: Double, newAmount: Double)] = []

        let priorityOrder: [AllocationBucketType] = [.discretionarySpending, .investments, .debtPaydown, .emergencyFund]

        for priorityType in priorityOrder {
            guard abs(remainingDelta) > 0.01 else { break }

            guard let bucket = otherModifiableBuckets.first(where: { $0.type == priorityType }) else {
                continue
            }

            let currentAmount = bucketAmounts[bucket.id] ?? bucket.allocatedAmount
            let recommendedMin = bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome)
            let availableToTake = max(0, currentAmount - recommendedMin)

            if remainingDelta > 0 {
                // Need to reduce this bucket
                let amountToTake = min(remainingDelta, availableToTake)
                let newAmountForBucket = currentAmount - amountToTake

                if amountToTake > 0.01 {
                    bucketAmounts[bucket.id] = newAmountForBucket
                    adjustedBuckets.append((bucket, currentAmount, newAmountForBucket))
                    remainingDelta -= amountToTake
                    print("      • \(bucket.displayName): $\(Int(currentAmount)) → $\(Int(newAmountForBucket)) (-$\(Int(amountToTake)))")
                }
            } else {
                // Need to add to this bucket
                let amountToAdd = min(abs(remainingDelta), monthlyIncome - totalAllocated)
                let newAmountForBucket = currentAmount + amountToAdd

                if amountToAdd > 0.01 {
                    bucketAmounts[bucket.id] = newAmountForBucket
                    adjustedBuckets.append((bucket, currentAmount, newAmountForBucket))
                    remainingDelta += amountToAdd
                    print("      • \(bucket.displayName): $\(Int(currentAmount)) → $\(Int(newAmountForBucket)) (+$\(Int(amountToAdd)))")
                }
            }
        }

        // Distribute any remaining delta proportionally
        if abs(remainingDelta) > 0.01 {
            print("   ↳ Distributing remaining $\(Int(abs(remainingDelta))) proportionally")

            var totalAdjustable = 0.0
            for bucket in otherModifiableBuckets {
                let currentAmount = bucketAmounts[bucket.id] ?? bucket.allocatedAmount
                if remainingDelta > 0 {
                    let recommendedMin = bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome)
                    totalAdjustable += max(0, currentAmount - recommendedMin)
                } else {
                    totalAdjustable += currentAmount
                }
            }

            if totalAdjustable > 0.01 {
                for bucket in otherModifiableBuckets {
                    let currentAmount = bucketAmounts[bucket.id] ?? bucket.allocatedAmount
                    let recommendedMin = bucket.getRecommendedMinimum(monthlyIncome: monthlyIncome)

                    let adjustableAmount = remainingDelta > 0 ? max(0, currentAmount - recommendedMin) : currentAmount
                    let proportion = adjustableAmount / totalAdjustable
                    let adjustment = remainingDelta * proportion
                    let newAmountForBucket = max(recommendedMin, currentAmount - adjustment)

                    if abs(newAmountForBucket - currentAmount) > 0.01 {
                        bucketAmounts[bucket.id] = newAmountForBucket
                        adjustedBuckets.append((bucket, currentAmount, newAmountForBucket))
                        print("      • \(bucket.displayName): $\(Int(currentAmount)) → $\(Int(newAmountForBucket))")
                    }
                }
            }
        }

        // Update change indicators for all adjusted buckets
        for (bucket, _, _) in adjustedBuckets {
            if let original = originalAmounts[bucket.id] {
                bucket.updateChange(from: original)
            }
        }

        // Final rounding adjustment to ensure exactly 100%
        let currentTotal = totalAllocated
        let difference = monthlyIncome - currentTotal

        if abs(difference) > 0.01 {
            if let largestBucket = otherModifiableBuckets.max(by: {
                (bucketAmounts[$0.id] ?? $0.allocatedAmount) < (bucketAmounts[$1.id] ?? $1.allocatedAmount)
            }) {
                let currentValue = bucketAmounts[largestBucket.id] ?? largestBucket.allocatedAmount
                let adjustedValue = max(0, currentValue + difference)

                bucketAmounts[largestBucket.id] = adjustedValue
                print("   ↳ Rounding adjustment of $\(Int(difference)) to \(largestBucket.displayName)")

                if let original = originalAmounts[largestBucket.id] {
                    largestBucket.updateChange(from: original)
                }
            }
        }

        print("   ✅ Total allocation: $\(Int(totalAllocated)) (\(Int(allocationPercentage(monthlyIncome: monthlyIncome)))%)")

        // Convert adjusted buckets into AllocationAdjustment instances
        var adjustmentsList: [AllocationAdjustment] = []

        for (bucket, previousAmount, newAmount) in adjustedBuckets {
            let amountChanged = newAmount - previousAmount

            // Only include if change is significant
            if abs(amountChanged) > 0.01 {
                let adjustment = AllocationAdjustment(
                    bucketType: bucket.type,
                    amountChanged: amountChanged,
                    previousAmount: previousAmount,
                    newAmount: newAmount
                )
                adjustmentsList.append(adjustment)

                // Record auto-adjustment on the bucket for badge display
                bucket.recordAutoAdjustment(amountChanged: amountChanged)
            }
        }

        print("   📊 Recorded \(adjustmentsList.count) auto-adjustment(s)")

        return adjustmentsList
    }

    /// Get binding for a specific bucket
    func binding(for bucketId: String, defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { self.bucketAmounts[bucketId] ?? defaultValue },
            set: { self.bucketAmounts[bucketId] = $0 }
        )
    }

    // MARK: - Edge Case Detection

    /// Detects if essential spending exceeds safe threshold (>80% of income)
    func detectHighEssentialSpending(
        essentialBucketId: String,
        monthlyIncome: Double
    ) -> (isHigh: Bool, percentage: Double) {
        guard let essentialAmount = bucketAmounts[essentialBucketId], monthlyIncome > 0 else {
            return (false, 0)
        }

        let percentage = (essentialAmount / monthlyIncome) * 100
        return (percentage > 80, percentage)
    }

    /// Detects if discretionary spending is below minimum healthy level (<5% of income)
    func detectLowDiscretionarySpending(
        discretionaryBucketId: String,
        monthlyIncome: Double
    ) -> (isTooLow: Bool, percentage: Double) {
        guard let discretionaryAmount = bucketAmounts[discretionaryBucketId], monthlyIncome > 0 else {
            return (false, 0)
        }

        let percentage = (discretionaryAmount / monthlyIncome) * 100
        return (percentage < 5, percentage)
    }

    /// Detects if emergency fund allocation is insufficient (<3% of income)
    func detectInsufficientEmergencyFund(
        emergencyBucketId: String,
        monthlyIncome: Double
    ) -> (isInsufficient: Bool, percentage: Double) {
        guard let emergencyAmount = bucketAmounts[emergencyBucketId], monthlyIncome > 0 else {
            return (false, 0)
        }

        let percentage = (emergencyAmount / monthlyIncome) * 100
        return (percentage < 3, percentage)
    }

    /// Detects budget overflow (total allocation > income)
    func detectBudgetOverflow(monthlyIncome: Double) -> (hasOverflow: Bool, overflowAmount: Double) {
        let overflow = totalAllocated - monthlyIncome
        return (overflow > 0.01, overflow)
    }

    /// Detects unallocated income (total allocation < income)
    func detectUnallocatedIncome(monthlyIncome: Double) -> (hasUnallocated: Bool, unallocatedAmount: Double) {
        let unallocated = monthlyIncome - totalAllocated
        return (unallocated > 0.01, unallocated)
    }
}
