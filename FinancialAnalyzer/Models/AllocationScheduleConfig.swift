import Foundation

/// Main configuration object that wraps the entire allocation scheduling system
struct AllocationScheduleConfig: Codable {
    var paycheckSchedule: PaycheckSchedule
    var isActive: Bool                   // Whether schedule is active
    var notificationsEnabled: Bool       // Whether to send notifications
    var createdAt: Date
    var updatedAt: Date

    // Notification preferences
    var sendPrePaydayReminder: Bool      // Send reminder 1 day before
    var sendPaydayNotification: Bool     // Send notification on payday
    var sendFollowUpReminder: Bool       // Send follow-up if not completed
    var followUpDelayDays: Int           // Days to wait before follow-up (default: 2)

    // Display preferences
    var upcomingMonthsToShow: Int        // How many months to show in timeline (default: 3)
    var historyMonthsToKeep: Int         // How many months of history to keep (default: 12)

    init(
        paycheckSchedule: PaycheckSchedule,
        isActive: Bool = true,
        notificationsEnabled: Bool = true,
        sendPrePaydayReminder: Bool = true,
        sendPaydayNotification: Bool = true,
        sendFollowUpReminder: Bool = true,
        followUpDelayDays: Int = 2,
        upcomingMonthsToShow: Int = 3,
        historyMonthsToKeep: Int = 12,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.paycheckSchedule = paycheckSchedule
        self.isActive = isActive
        self.notificationsEnabled = notificationsEnabled
        self.sendPrePaydayReminder = sendPrePaydayReminder
        self.sendPaydayNotification = sendPaydayNotification
        self.sendFollowUpReminder = sendFollowUpReminder
        self.followUpDelayDays = followUpDelayDays
        self.upcomingMonthsToShow = upcomingMonthsToShow
        self.historyMonthsToKeep = historyMonthsToKeep
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Updates the paycheck schedule
    mutating func updatePaycheckSchedule(_ newSchedule: PaycheckSchedule) {
        self.paycheckSchedule = newSchedule
        self.updatedAt = Date()
    }

    /// Toggles schedule active status
    mutating func setActive(_ active: Bool) {
        self.isActive = active
        self.updatedAt = Date()
    }

    /// Updates notification preferences
    mutating func updateNotificationPreferences(
        enabled: Bool,
        prePayday: Bool,
        payday: Bool,
        followUp: Bool,
        followUpDelay: Int
    ) {
        self.notificationsEnabled = enabled
        self.sendPrePaydayReminder = prePayday
        self.sendPaydayNotification = payday
        self.sendFollowUpReminder = followUp
        self.followUpDelayDays = followUpDelay
        self.updatedAt = Date()
    }

    /// Updates display preferences
    mutating func updateDisplayPreferences(upcomingMonths: Int, historyMonths: Int) {
        self.upcomingMonthsToShow = upcomingMonths
        self.historyMonthsToKeep = historyMonths
        self.updatedAt = Date()
    }
}

// MARK: - Storage Helper

extension AllocationScheduleConfig {
    private static let userDefaultsKey = "allocationScheduleConfig"

    /// Saves the config to UserDefaults
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
            print("💾 [AllocationScheduleConfig] Saved schedule configuration")
        } else {
            print("❌ [AllocationScheduleConfig] Failed to encode configuration")
        }
    }

    /// Loads the config from UserDefaults
    static func load() -> AllocationScheduleConfig? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("📭 [AllocationScheduleConfig] No saved configuration found")
            return nil
        }

        let decoder = JSONDecoder()
        if let config = try? decoder.decode(AllocationScheduleConfig.self, from: data) {
            print("📦 [AllocationScheduleConfig] Loaded schedule configuration")
            return config
        } else {
            print("❌ [AllocationScheduleConfig] Failed to decode configuration")
            return nil
        }
    }

    /// Clears the saved config from UserDefaults
    static func clear() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("🗑️ [AllocationScheduleConfig] Cleared schedule configuration")
    }
}

// MARK: - Default Configurations

extension AllocationScheduleConfig {
    /// Creates a default monthly schedule (for manual setup)
    static func defaultMonthly(estimatedAmount: Double) -> AllocationScheduleConfig {
        let paycheckSchedule = PaycheckSchedule(
            frequency: .monthly,
            estimatedAmount: estimatedAmount,
            confidence: .manual,
            isUserConfirmed: false,
            anchorDates: [DateComponents(day: 1)] // Default to 1st of month
        )

        return AllocationScheduleConfig(paycheckSchedule: paycheckSchedule)
    }

    /// Creates a default bi-weekly schedule (for manual setup)
    static func defaultBiweekly(estimatedAmount: Double, weekday: Int = 6) -> AllocationScheduleConfig {
        let paycheckSchedule = PaycheckSchedule(
            frequency: .biweekly,
            estimatedAmount: estimatedAmount,
            confidence: .manual,
            isUserConfirmed: false,
            anchorDates: [DateComponents(weekday: weekday)] // Default to Friday
        )

        return AllocationScheduleConfig(paycheckSchedule: paycheckSchedule)
    }

    /// Creates a default semi-monthly schedule (for manual setup)
    static func defaultSemiMonthly(estimatedAmount: Double) -> AllocationScheduleConfig {
        let paycheckSchedule = PaycheckSchedule(
            frequency: .semimonthly,
            estimatedAmount: estimatedAmount,
            confidence: .manual,
            isUserConfirmed: false,
            anchorDates: [
                DateComponents(day: 1),
                DateComponents(day: 15)
            ]
        )

        return AllocationScheduleConfig(paycheckSchedule: paycheckSchedule)
    }
}
