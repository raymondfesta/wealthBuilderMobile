import Foundation

/// Status of a scheduled allocation event
enum AllocationStatus: String, Codable {
    case upcoming = "Upcoming"           // Future allocation not yet due
    case reminderSent = "Reminder Sent"  // Notification sent, awaiting completion
    case completed = "Completed"         // User marked as complete
    case skipped = "Skipped"            // User chose to skip this payday

    var displayName: String {
        self.rawValue
    }

    var icon: String {
        switch self {
        case .upcoming:
            return "clock"
        case .reminderSent:
            return "bell.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .skipped:
            return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .upcoming:
            return "#007AFF" // Blue
        case .reminderSent:
            return "#FF9500" // Orange
        case .completed:
            return "#34C759" // Green
        case .skipped:
            return "#8E8E93" // Gray
        }
    }

    var isPending: Bool {
        return self == .upcoming || self == .reminderSent
    }

    var isActionable: Bool {
        return self == .upcoming || self == .reminderSent
    }
}

/// Represents a single scheduled allocation event for a specific bucket on a specific payday
struct ScheduledAllocation: Codable, Identifiable {
    let id: String
    let paycheckDate: Date           // When the paycheck arrives
    let bucketType: AllocationBucketType
    var scheduledAmount: Double      // Original planned amount
    var status: AllocationStatus
    var createdAt: Date
    var updatedAt: Date

    // Tracking
    var reminderSentAt: Date?        // When notification was sent
    var linkedExecutionId: String?   // References AllocationExecution if completed

    init(
        id: String = UUID().uuidString,
        paycheckDate: Date,
        bucketType: AllocationBucketType,
        scheduledAmount: Double,
        status: AllocationStatus = .upcoming,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.paycheckDate = paycheckDate
        self.bucketType = bucketType
        self.scheduledAmount = scheduledAmount
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Marks the allocation as completed and links to execution record
    mutating func markCompleted(executionId: String) {
        self.status = .completed
        self.linkedExecutionId = executionId
        self.updatedAt = Date()
    }

    /// Marks the allocation as skipped (user chose not to allocate this time)
    mutating func markSkipped() {
        self.status = .skipped
        self.updatedAt = Date()
    }

    /// Records that reminder notification was sent
    mutating func markReminderSent() {
        self.status = .reminderSent
        self.reminderSentAt = Date()
        self.updatedAt = Date()
    }

    /// Whether this allocation is due today
    var isDueToday: Bool {
        Calendar.current.isDateInToday(paycheckDate)
    }

    /// Whether this allocation is overdue
    var isOverdue: Bool {
        paycheckDate < Date() && status.isPending
    }

    /// Days until paycheck (negative if past)
    var daysUntilPaycheck: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: paycheckDate).day ?? 0
    }

    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d" // "Friday, Nov 15"
        return formatter.string(from: paycheckDate)
    }

    /// Short formatted date (e.g., "Nov 15")
    var shortFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: paycheckDate)
    }
}

// MARK: - Grouping Helper

/// Groups scheduled allocations by paycheck date for display
struct PaycheckAllocationGroup: Identifiable {
    let paycheckDate: Date
    let allocations: [ScheduledAllocation]

    var id: String {
        "\(paycheckDate.timeIntervalSince1970)"
    }

    /// Total scheduled amount across all buckets for this payday
    var totalScheduledAmount: Double {
        allocations.reduce(0) { $0 + $1.scheduledAmount }
    }

    /// Number of buckets in this payday
    var bucketCount: Int {
        allocations.count
    }

    /// Whether all allocations are completed
    var isFullyCompleted: Bool {
        allocations.allSatisfy { $0.status == .completed }
    }

    /// Whether any allocation is pending
    var hasPendingAllocations: Bool {
        allocations.contains { $0.status.isPending }
    }

    /// Number of completed allocations
    var completedCount: Int {
        allocations.filter { $0.status == .completed }.count
    }

    /// Progress percentage (0-100)
    var progressPercentage: Double {
        guard !allocations.isEmpty else { return 0 }
        return (Double(completedCount) / Double(allocations.count)) * 100
    }

    /// Formatted date string
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d" // "Friday, Nov 15"
        return formatter.string(from: paycheckDate)
    }

    /// Status summary for this payday
    var statusSummary: String {
        if isFullyCompleted {
            return "All allocations completed"
        } else if hasPendingAllocations {
            return "\(completedCount) of \(bucketCount) completed"
        } else {
            return "Skipped"
        }
    }
}

// MARK: - Extension for Array Grouping

extension Array where Element == ScheduledAllocation {
    /// Groups allocations by paycheck date
    func groupedByPaycheck() -> [PaycheckAllocationGroup] {
        let grouped = Dictionary(grouping: self) { $0.paycheckDate }
        return grouped.map { PaycheckAllocationGroup(paycheckDate: $0.key, allocations: $0.value) }
            .sorted { $0.paycheckDate < $1.paycheckDate }
    }

    /// Filters to only upcoming allocations (future dates)
    func upcoming() -> [ScheduledAllocation] {
        filter { $0.paycheckDate >= Date() && $0.status.isPending }
    }

    /// Filters to completed allocations
    func completed() -> [ScheduledAllocation] {
        filter { $0.status == .completed }
    }

    /// Filters allocations for a specific date range
    func withinDateRange(_ dateRange: ClosedRange<Date>) -> [ScheduledAllocation] {
        filter { dateRange.contains($0.paycheckDate) }
    }
}
