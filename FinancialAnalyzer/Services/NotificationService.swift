import Foundation
import UserNotifications
import SwiftUI

/// Manages local push notifications for proactive budget alerts
@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Requests notification permissions from the user
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]

        let granted = try await notificationCenter.requestAuthorization(options: options)
        await checkAuthorizationStatus()

        return granted
    }

    /// Checks current authorization status
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Schedule Proactive Alerts

    /// Schedules a notification for a pending transaction
    func schedulePurchaseAlert(
        amount: Double,
        merchantName: String,
        budgetRemaining: Double,
        category: String,
        triggerInSeconds: TimeInterval = 1
    ) async throws {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "💡 Budget Check: \(merchantName)"
        content.body = budgetRemaining > amount
            ? "You have \(formatCurrency(budgetRemaining)) left in \(category)"
            : "⚠️ This exceeds your \(category) budget"
        content.sound = .default
        content.badge = 1

        // Add user info for handling tap
        content.userInfo = [
            "type": "purchase_alert",
            "amount": amount,
            "merchantName": merchantName,
            "budgetRemaining": budgetRemaining,
            "category": category
        ]

        // Create trigger (time-based)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInSeconds, repeats: false)

        // Create request
        let request = UNNotificationRequest(
            identifier: "purchase_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        // Schedule notification
        try await notificationCenter.add(request)
    }

    /// Schedules a savings opportunity notification
    func scheduleSavingsOpportunityAlert(
        surplusAmount: Double,
        recommendedGoal: String,
        triggerInSeconds: TimeInterval = 1
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "✨ Smart Money Alert"
        content.body = "You're \(formatCurrency(surplusAmount)) under budget! Consider adding to \(recommendedGoal)."
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "type": "savings_opportunity",
            "amount": surplusAmount,
            "recommendedGoal": recommendedGoal
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInSeconds, repeats: false)

        let request = UNNotificationRequest(
            identifier: "savings_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// Schedules a cash flow warning notification
    func scheduleCashFlowWarning(
        currentBalance: Double,
        upcomingExpenses: Double,
        daysAhead: Int,
        triggerInSeconds: TimeInterval = 1
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "⚡ Cash Flow Alert"
        content.body = "\(formatCurrency(upcomingExpenses)) in bills coming in \(daysAhead) days. Current balance: \(formatCurrency(currentBalance))"
        content.sound = .defaultCritical // More urgent sound
        content.badge = 1

        content.userInfo = [
            "type": "cash_flow_warning",
            "currentBalance": currentBalance,
            "upcomingExpenses": upcomingExpenses,
            "daysAhead": daysAhead
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInSeconds, repeats: false)

        let request = UNNotificationRequest(
            identifier: "cashflow_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// Schedules a weekly budget review reminder
    func scheduleWeeklyReview(dayOfWeek: Int = 1, hour: Int = 9) async throws {
        let content = UNMutableNotificationContent()
        content.title = "📊 Weekly Financial Review"
        content.body = "Take 2 minutes to review your budget and spending patterns."
        content.sound = .default

        content.userInfo = [
            "type": "weekly_review"
        ]

        // Create calendar-based trigger
        var dateComponents = DateComponents()
        dateComponents.weekday = dayOfWeek // 1 = Sunday, 2 = Monday, etc.
        dateComponents.hour = hour

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly_review",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// Schedules a goal milestone notification
    func scheduleGoalMilestone(
        goalName: String,
        percentComplete: Double,
        triggerInSeconds: TimeInterval = 1
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "🎯 Goal Milestone!"
        content.body = "You're \(Int(percentComplete))% of the way to your \(goalName) goal. Keep it up!"
        content.sound = .default

        content.userInfo = [
            "type": "goal_milestone",
            "goalName": goalName,
            "percentComplete": percentComplete
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerInSeconds, repeats: false)

        let request = UNNotificationRequest(
            identifier: "goal_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    // MARK: - Manage Notifications

    /// Cancels a specific notification by identifier
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancels all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Gets all pending notifications
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }

    /// Clears delivered notifications from notification center
    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    // MARK: - Notification Actions

    /// Registers notification actions (swipe actions)
    func registerNotificationActions() {
        // Purchase alert actions
        let confirmAction = UNNotificationAction(
            identifier: "CONFIRM_PURCHASE",
            title: "Confirm Purchase",
            options: []
        )

        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_BUDGET",
            title: "Review Budget",
            options: .foreground
        )

        let purchaseCategory = UNNotificationCategory(
            identifier: "PURCHASE_ALERT",
            actions: [confirmAction, reviewAction],
            intentIdentifiers: [],
            options: []
        )

        // Savings opportunity actions
        let contributeAction = UNNotificationAction(
            identifier: "CONTRIBUTE_TO_GOAL",
            title: "Add to Goal",
            options: .foreground
        )

        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE",
            title: "Not Now",
            options: []
        )

        let savingsCategory = UNNotificationCategory(
            identifier: "SAVINGS_OPPORTUNITY",
            actions: [contributeAction, ignoreAction],
            intentIdentifiers: [],
            options: []
        )

        // Register categories
        notificationCenter.setNotificationCategories([purchaseCategory, savingsCategory])
    }

    // MARK: - Allocation Reminders

    /// Schedules a pre-payday reminder (1 day before paycheck)
    func schedulePrePaydayReminder(
        paycheckDate: Date,
        estimatedAmount: Double
    ) async throws {
        // Calculate trigger date (1 day before paycheckDate at 6 PM)
        let calendar = Calendar.current
        guard let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: paycheckDate) else {
            return
        }

        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: oneDayBefore)
        triggerComponents.hour = 18 // 6 PM

        let content = UNMutableNotificationContent()
        content.title = "💰 Payday Tomorrow"
        content.body = "Your paycheck arrives tomorrow. Get ready to allocate \(formatCurrency(estimatedAmount))."
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "type": "pre_payday_reminder",
            "paycheckDate": paycheckDate.timeIntervalSince1970,
            "estimatedAmount": estimatedAmount
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "pre_payday_\(paycheckDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        print("📅 [Notifications] Scheduled pre-payday reminder for \(oneDayBefore)")
    }

    /// Schedules allocation day notification (morning of payday)
    func scheduleAllocationDayNotification(
        paycheckDate: Date,
        allocations: [ScheduledAllocation]
    ) async throws {
        // Trigger at 9 AM on payday
        let calendar = Calendar.current
        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: paycheckDate)
        triggerComponents.hour = 9

        // Build allocation summary
        let totalAmount = allocations.reduce(0) { $0 + $1.scheduledAmount }
        let bucketSummary = allocations.map { "\(formatCurrency($0.scheduledAmount)) → \($0.bucketType.displayName)" }
            .prefix(3)
            .joined(separator: ", ")

        let content = UNMutableNotificationContent()
        content.title = "Time to Allocate Your Income"
        content.body = bucketSummary + (allocations.count > 3 ? "..." : "")
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "ALLOCATION_DAY"

        content.userInfo = [
            "type": "allocation_day",
            "paycheckDate": paycheckDate.timeIntervalSince1970,
            "totalAmount": totalAmount,
            "allocationIds": allocations.map { $0.id }
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "allocation_day_\(paycheckDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        print("📅 [Notifications] Scheduled allocation day notification for \(paycheckDate)")
    }

    /// Shows completion confirmation (local notification, immediate)
    func showCompletionConfirmation(
        allocatedAmount: Double,
        bucketCount: Int
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Allocation Complete ✓"
        content.body = "Great work! You allocated \(formatCurrency(allocatedAmount)) across \(bucketCount) bucket\(bucketCount == 1 ? "" : "s")."
        content.sound = .default

        content.userInfo = [
            "type": "allocation_complete",
            "allocatedAmount": allocatedAmount
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "completion_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
    }

    /// Schedules follow-up reminder if allocation not completed
    func scheduleFollowUpReminder(
        paycheckDate: Date,
        allocations: [ScheduledAllocation],
        delayDays: Int = 2
    ) async throws {
        // Trigger N days after payday at 6 PM
        let calendar = Calendar.current
        guard let followUpDate = calendar.date(byAdding: .day, value: delayDays, to: paycheckDate) else {
            return
        }

        var triggerComponents = calendar.dateComponents([.year, .month, .day], from: followUpDate)
        triggerComponents.hour = 18 // 6 PM

        let totalAmount = allocations.reduce(0) { $0 + $1.scheduledAmount }

        let content = UNMutableNotificationContent()
        content.title = "Don't Forget Your Allocations"
        content.body = "You have \(formatCurrency(totalAmount)) in pending allocations from your last paycheck."
        content.sound = .default
        content.badge = 1

        content.userInfo = [
            "type": "allocation_follow_up",
            "paycheckDate": paycheckDate.timeIntervalSince1970,
            "allocationIds": allocations.map { $0.id }
        ]

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "follow_up_\(paycheckDate.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        try await notificationCenter.add(request)
        print("📅 [Notifications] Scheduled follow-up reminder for \(followUpDate)")
    }

    /// Cancels allocation notifications for a specific payday
    func cancelAllocationNotifications(for paycheckDate: Date) {
        let timestamp = paycheckDate.timeIntervalSince1970
        let identifiers = [
            "pre_payday_\(timestamp)",
            "allocation_day_\(timestamp)",
            "follow_up_\(timestamp)"
        ]

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ [Notifications] Cancelled allocation notifications for \(paycheckDate)")
    }

    /// Schedules all notifications for upcoming allocations
    func scheduleAllocationNotifications(
        scheduledAllocations: [ScheduledAllocation],
        config: AllocationScheduleConfig
    ) async throws {
        guard config.isActive && config.notificationsEnabled else {
            print("⚠️ [Notifications] Allocation notifications disabled in config")
            return
        }

        // Group by paycheck date
        let groupedAllocations = scheduledAllocations.groupedByPaycheck()

        for group in groupedAllocations {
            // Only schedule for future dates
            guard group.paycheckDate > Date() else { continue }

            // Only schedule for pending allocations
            let pendingAllocations = group.allocations.filter { $0.status.isPending }
            guard !pendingAllocations.isEmpty else { continue }

            // Pre-payday reminder
            if config.sendPrePaydayReminder {
                try await schedulePrePaydayReminder(
                    paycheckDate: group.paycheckDate,
                    estimatedAmount: config.paycheckSchedule.estimatedAmount
                )
            }

            // Payday notification
            if config.sendPaydayNotification {
                try await scheduleAllocationDayNotification(
                    paycheckDate: group.paycheckDate,
                    allocations: pendingAllocations
                )
            }

            // Follow-up reminder
            if config.sendFollowUpReminder {
                try await scheduleFollowUpReminder(
                    paycheckDate: group.paycheckDate,
                    allocations: pendingAllocations,
                    delayDays: config.followUpDelayDays
                )
            }
        }

        print("✅ [Notifications] Scheduled notifications for \(groupedAllocations.count) upcoming paydays")
    }

    /// Cancels all allocation-related notifications
    func cancelAllAllocationNotifications() {
        Task {
            let pending = await getPendingNotifications()
            let allocationIdentifiers = pending
                .filter { request in
                    guard let type = request.content.userInfo["type"] as? String else { return false }
                    return type.contains("payday") || type.contains("allocation")
                }
                .map { $0.identifier }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: allocationIdentifiers)
            print("🗑️ [Notifications] Cancelled \(allocationIdentifiers.count) allocation notifications")
        }
    }

    // MARK: - Helper

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}

// MARK: - Notification Delegate

/// Delegate to handle notification responses
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    // Called when notification is received while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner and play sound even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    // Called when user taps on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            handleNotificationTap(userInfo: userInfo)

        case "CONFIRM_PURCHASE":
            // User confirmed purchase from notification
            handleConfirmPurchase(userInfo: userInfo)

        case "REVIEW_BUDGET":
            // User wants to review budget
            handleReviewBudget(userInfo: userInfo)

        case "CONTRIBUTE_TO_GOAL":
            // User wants to contribute to goal
            handleContributeToGoal(userInfo: userInfo)

        case "IGNORE":
            // User dismissed
            break

        default:
            break
        }

        completionHandler()
    }

    // MARK: - Action Handlers

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        // Post notification to app to handle navigation
        NotificationCenter.default.post(
            name: .notificationTapped,
            object: nil,
            userInfo: ["type": type, "data": userInfo]
        )
    }

    private func handleConfirmPurchase(userInfo: [AnyHashable: Any]) {
        // Log confirmation
        print("User confirmed purchase from notification")

        // Could trigger analytics or update budget immediately
        NotificationCenter.default.post(
            name: .purchaseConfirmed,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleReviewBudget(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .reviewBudgetRequested,
            object: nil,
            userInfo: userInfo
        )
    }

    private func handleContributeToGoal(userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: .contributeToGoalRequested,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let notificationTapped = Notification.Name("notificationTapped")
    static let purchaseConfirmed = Notification.Name("purchaseConfirmed")
    static let reviewBudgetRequested = Notification.Name("reviewBudgetRequested")
    static let contributeToGoalRequested = Notification.Name("contributeToGoalRequested")
    static let allocationReminderTapped = Notification.Name("allocationReminderTapped")
    static let allocationCompleted = Notification.Name("allocationCompleted")
    static let allocationSkipped = Notification.Name("allocationSkipped")
}
