//
//  UserStatus.swift
//  FinancialAnalyzer
//
//  User status from backend (source of truth for journey state)
//

import Foundation

/// User status response from backend
struct UserStatusResponse: Codable {
    let userId: String
    let email: String
    let onboardingCompleted: Bool
    let onboardingCompletedAt: String?
    let connectedAccountsCount: Int
    let createdAt: String
}

/// Plaid items response with onboarding status
struct PlaidItemsWithStatusResponse: Codable {
    let items: [PlaidItemInfo]
    let onboardingCompleted: Bool
    let onboardingCompletedAt: String?
}

struct PlaidItemInfo: Codable {
    let itemId: String
    let institutionName: String?
    let createdAt: String?
}

// MARK: - Allocation Plan Models

/// Response from GET /api/user/allocation-plan
struct AllocationPlanResponse: Codable {
    let allocations: [StoredAllocation]
    let paycheckSchedule: StoredPaycheckSchedule?
    let hasPlan: Bool
}

/// Stored allocation from backend
struct StoredAllocation: Codable {
    let id: String
    let bucketType: String
    let percentage: Double
    let targetAmount: Double?
    let linkedAccountId: String?
    let linkedAccountName: String?
    let isCustomized: Bool
    let presetTier: String?
    let createdAt: String
    let updatedAt: String

    /// Converts to AllocationBucket model
    func toAllocationBucket() -> AllocationBucket? {
        guard let type = AllocationBucketType(rawValue: bucketType) else { return nil }

        let bucket = AllocationBucket(
            type: type,
            allocatedAmount: 0, // Will be calculated by caller
            percentageOfIncome: percentage,
            explanation: ""
        )
        bucket.targetAmount = targetAmount
        if let tier = presetTier, let presetTier = PresetTier(rawValue: tier) {
            bucket.selectedPresetTier = presetTier
        }
        return bucket
    }
}

/// Stored paycheck schedule from backend
struct StoredPaycheckSchedule: Codable {
    let id: String?
    let frequency: String
    let estimatedAmount: Double?
    let nextPaycheckDate: String?
    let isConfirmed: Bool
    let detectedEmployer: String?

    /// Converts to PaycheckSchedule model
    func toPaycheckSchedule() -> PaycheckSchedule? {
        guard let freq = PaycheckFrequency(rawValue: frequency) else { return nil }

        // Parse next paycheck date to create anchor dates
        var anchorDates: [DateComponents] = []
        if let dateStr = nextPaycheckDate {
            let formatter = ISO8601DateFormatter()
            if let date = formatter.date(from: dateStr) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.day, .weekday], from: date)
                anchorDates = [components]
            }
        }

        // Use default anchor if none provided
        if anchorDates.isEmpty {
            anchorDates = [DateComponents(weekday: 6)] // Friday default
        }

        return PaycheckSchedule(
            frequency: freq,
            estimatedAmount: estimatedAmount ?? 0,
            confidence: isConfirmed ? .manual : .medium,
            isUserConfirmed: isConfirmed,
            anchorDates: anchorDates
        )
    }
}

// MARK: - Request Models

/// Request body for POST /api/user/allocation-plan
struct SaveAllocationPlanRequest: Codable {
    let allocations: [AllocationToSave]
    let paycheckSchedule: PaycheckScheduleToSave?
}

/// Allocation to save to backend
struct AllocationToSave: Codable {
    let bucketType: String
    let percentage: Double
    let targetAmount: Double?
    let linkedAccountId: String?
    let linkedAccountName: String?
    let isCustomized: Bool
    let presetTier: String
}

/// Paycheck schedule to save to backend
struct PaycheckScheduleToSave: Codable {
    let frequency: String
    let estimatedAmount: Double?
    let nextPaycheckDate: String?
    let isConfirmed: Bool
    let detectedEmployer: String?
}
