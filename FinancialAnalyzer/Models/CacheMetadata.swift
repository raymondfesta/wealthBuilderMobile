//
//  CacheMetadata.swift
//  FinancialAnalyzer
//
//  Tracks cache freshness for smart refresh decisions
//

import Foundation

/// Metadata about cached data freshness
struct CacheMetadata: Codable {
    /// When accounts were last refreshed
    let accountsRefreshedAt: Date?

    /// When transactions were last refreshed
    let transactionsRefreshedAt: Date?

    /// When balances were last refreshed
    let balancesRefreshedAt: Date?

    /// Number of accounts in cache
    let accountCount: Int

    /// Number of transactions in cache
    let transactionCount: Int

    /// Date range of cached transactions
    let transactionStartDate: Date?
    let transactionEndDate: Date?

    // MARK: - Computed Properties

    /// Age of account data in seconds
    var accountsAge: TimeInterval? {
        guard let refreshed = accountsRefreshedAt else { return nil }
        return Date().timeIntervalSince(refreshed)
    }

    /// Age of transaction data in seconds
    var transactionsAge: TimeInterval? {
        guard let refreshed = transactionsRefreshedAt else { return nil }
        return Date().timeIntervalSince(refreshed)
    }

    /// Age of balance data in seconds
    var balancesAge: TimeInterval? {
        guard let refreshed = balancesRefreshedAt else { return nil }
        return Date().timeIntervalSince(refreshed)
    }

    /// Human-readable age string
    var ageDescription: String {
        guard let age = balancesAge ?? accountsAge else {
            return "Never"
        }

        let minutes = Int(age / 60)
        let hours = Int(age / 3600)
        let days = Int(age / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(days)d ago"
        }
    }

    /// Whether we have any cached data
    var hasData: Bool {
        accountCount > 0
    }

    // MARK: - Initializers

    init(
        accountsRefreshedAt: Date? = nil,
        transactionsRefreshedAt: Date? = nil,
        balancesRefreshedAt: Date? = nil,
        accountCount: Int = 0,
        transactionCount: Int = 0,
        transactionStartDate: Date? = nil,
        transactionEndDate: Date? = nil
    ) {
        self.accountsRefreshedAt = accountsRefreshedAt
        self.transactionsRefreshedAt = transactionsRefreshedAt
        self.balancesRefreshedAt = balancesRefreshedAt
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.transactionStartDate = transactionStartDate
        self.transactionEndDate = transactionEndDate
    }

    /// Empty metadata
    static let empty = CacheMetadata()
}
