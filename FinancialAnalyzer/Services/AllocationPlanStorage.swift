import Foundation

/// Service for persisting allocation plan preferences to UserDefaults
class AllocationPlanStorage {
    static let shared = AllocationPlanStorage()

    private let defaults = UserDefaults.standard

    // UserDefaults keys
    private let accountLinksKey = "allocationPlan_accountLinks"
    private let presetSelectionsKey = "allocationPlan_presetSelections"
    private let emergencyDurationKey = "allocationPlan_emergencyDuration"
    private let customAmountsKey = "allocationPlan_customAmounts"
    private let lastSavedDateKey = "allocationPlan_lastSavedDate"

    private init() {}

    // MARK: - Account Links

    /// Save account links for a specific bucket
    /// - Parameters:
    ///   - accountIds: Array of account IDs linked to this bucket
    ///   - bucketType: The bucket type
    func saveAccountLinks(accountIds: [String], for bucketType: AllocationBucketType) {
        var allLinks = loadAllAccountLinks()
        allLinks[bucketType.rawValue] = accountIds

        if let encoded = try? JSONEncoder().encode(allLinks) {
            defaults.set(encoded, forKey: accountLinksKey)
            print("💾 [Storage] Saved \(accountIds.count) account link(s) for \(bucketType.rawValue)")
        }
    }

    /// Load account links for a specific bucket
    func loadAccountLinks(for bucketType: AllocationBucketType) -> [String] {
        let allLinks = loadAllAccountLinks()
        return allLinks[bucketType.rawValue] ?? []
    }

    /// Load all account links
    private func loadAllAccountLinks() -> [String: [String]] {
        guard let data = defaults.data(forKey: accountLinksKey),
              let links = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return links
    }

    /// Clear account links for a specific bucket
    func clearAccountLinks(for bucketType: AllocationBucketType) {
        var allLinks = loadAllAccountLinks()
        allLinks.removeValue(forKey: bucketType.rawValue)

        if let encoded = try? JSONEncoder().encode(allLinks) {
            defaults.set(encoded, forKey: accountLinksKey)
            print("🗑️ [Storage] Cleared account links for \(bucketType.rawValue)")
        }
    }

    // MARK: - Preset Tier Selections

    /// Save preset tier selection for a bucket
    func savePresetTier(_ tier: PresetTier, for bucketType: AllocationBucketType) {
        var allSelections = loadAllPresetSelections()
        allSelections[bucketType.rawValue] = tier.rawValue

        if let encoded = try? JSONEncoder().encode(allSelections) {
            defaults.set(encoded, forKey: presetSelectionsKey)
            print("💾 [Storage] Saved preset tier '\(tier.rawValue)' for \(bucketType.rawValue)")
        }
    }

    /// Load preset tier selection for a bucket
    func loadPresetTier(for bucketType: AllocationBucketType) -> PresetTier? {
        let allSelections = loadAllPresetSelections()
        guard let tierString = allSelections[bucketType.rawValue],
              let tier = PresetTier(rawValue: tierString) else {
            return nil
        }
        return tier
    }

    private func loadAllPresetSelections() -> [String: String] {
        guard let data = defaults.data(forKey: presetSelectionsKey),
              let selections = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return selections
    }

    // MARK: - Emergency Fund Duration

    /// Save emergency fund duration selection
    func saveEmergencyDuration(_ months: Int) {
        defaults.set(months, forKey: emergencyDurationKey)
        print("💾 [Storage] Saved emergency fund duration: \(months) months")
    }

    /// Load emergency fund duration selection
    func loadEmergencyDuration() -> Int? {
        let duration = defaults.integer(forKey: emergencyDurationKey)
        return duration > 0 ? duration : nil
    }

    /// Clear emergency fund duration
    func clearEmergencyDuration() {
        defaults.removeObject(forKey: emergencyDurationKey)
        print("🗑️ [Storage] Cleared emergency fund duration")
    }

    // MARK: - Custom Allocation Amounts

    /// Save custom allocation amounts (amounts that differ from backend recommendations)
    func saveCustomAmounts(_ amounts: [String: Double]) {
        if let encoded = try? JSONEncoder().encode(amounts) {
            defaults.set(encoded, forKey: customAmountsKey)
            defaults.set(Date(), forKey: lastSavedDateKey)
            print("💾 [Storage] Saved custom amounts for \(amounts.count) bucket(s)")
        }
    }

    /// Load custom allocation amounts
    func loadCustomAmounts() -> [String: Double] {
        guard let data = defaults.data(forKey: customAmountsKey),
              let amounts = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return amounts
    }

    /// Get last saved date
    func getLastSavedDate() -> Date? {
        return defaults.object(forKey: lastSavedDateKey) as? Date
    }

    // MARK: - Clear All Data

    /// Clear all allocation plan data (for testing and reset)
    func clearAllData() {
        defaults.removeObject(forKey: accountLinksKey)
        defaults.removeObject(forKey: presetSelectionsKey)
        defaults.removeObject(forKey: emergencyDurationKey)
        defaults.removeObject(forKey: customAmountsKey)
        defaults.removeObject(forKey: lastSavedDateKey)

        print("🗑️ [Storage] Cleared all allocation plan data")
    }

    // MARK: - Summary

    /// Get a summary of stored data (for debugging)
    func getSummary() -> String {
        var summary: [String] = []

        let accountLinks = loadAllAccountLinks()
        summary.append("Account Links: \(accountLinks.count) bucket(s)")

        let presetSelections = loadAllPresetSelections()
        summary.append("Preset Selections: \(presetSelections.count) bucket(s)")

        if let duration = loadEmergencyDuration() {
            summary.append("Emergency Duration: \(duration) months")
        }

        let customAmounts = loadCustomAmounts()
        summary.append("Custom Amounts: \(customAmounts.count) bucket(s)")

        if let lastSaved = getLastSavedDate() {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            summary.append("Last Saved: \(formatter.string(from: lastSaved))")
        }

        return summary.joined(separator: "\n")
    }
}
