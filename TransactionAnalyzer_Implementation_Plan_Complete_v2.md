# TransactionAnalyzer Implementation Plan (Complete)

**Project:** Capium iOS App  
**Objective:** Fix critical calculation errors in transaction analysis logic  
**Priority:** 🔴 CRITICAL - Pre-Launch Blocker  
**Estimated Time:** 4-6 hours  
**Document Version:** 2.0  
**Created:** January 21, 2026  
**Updated:** January 22, 2026

---

## Document Changelog (v2.0)

| Change | Original (v1.0) | Updated (v2.0) |
|--------|-----------------|----------------|
| File paths | `Sources/FinancialAnalyzer/` | `FinancialAnalyzer/` |
| Task 1C | Refactor FinancialSummary as compatibility layer | **Delete** FinancialSummary entirely |
| New Task 1D | — | Delete deprecated `Sources/` directory |
| Task 6 scope | Backward compatibility with FinancialSummary | Full migration to FinancialSnapshot |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Architecture Overview](#3-architecture-overview)
4. [Implementation Tasks](#4-implementation-tasks)
   - Task 1: Model Files (Refactor + Create + Delete)
   - Task 2: Rewrite TransactionAnalyzer.swift
   - Task 3: Update SpendingPatternAnalyzer.swift
   - Task 4: Update BudgetManager.swift
   - Task 5: Update AlertRulesEngine.swift
   - Task 6: Migrate All Consumers to FinancialSnapshot
5. [Testing & Validation](#5-testing--validation)
6. [Verification Checklist](#6-verification-checklist)
7. [Appendix: Test Data](#7-appendix-test-data)

---

## 1. Executive Summary

### What's Wrong

The current `TransactionAnalyzer.swift` has 5 critical calculation errors:

| Issue | Impact | Severity |
|-------|--------|----------|
| All negative amounts classified as income | +45% income inflation | 🔴 Critical |
| Investment contributions counted as expenses | +58% expense inflation | 🔴 Critical |
| Wrong "Available to Spend" formula | Mixing flow vs position | 🔴 Critical |
| No investment contribution detection | Design spec not implemented | 🔴 Critical |
| Internal transfers not filtered | Double-counting risk | 🟠 High |

### What Needs to Happen

1. **Create** `isInvestmentContribution()` helper function
2. **Fix** `categorizeToBucket()` to exclude investment transfers from income
3. **Remove** `availableToSpend` calculation entirely
4. **Replace** with proper `disposableIncome` calculation
5. **Separate** MonthlyFlow from FinancialPosition
6. **Delete** FinancialSummary and migrate all consumers to FinancialSnapshot
7. **Delete** deprecated `Sources/` directory

### Success Criteria

After implementation:
- Income only includes actual income (payroll, dividends, interest)
- Expenses exclude investment contributions
- Disposable Income = Income - Essential Expenses - Debt Minimums
- No "Available to Spend" anywhere in codebase
- No "FinancialSummary" anywhere in codebase (fully migrated)
- All downstream files use `FinancialSnapshot`

### Quick Reference: All File Changes

| Task | File Path | Action | Priority |
|------|-----------|--------|----------|
| 1A.1 | `FinancialAnalyzer/Models/BankAccount.swift` | Refactor | High |
| 1A.2 | `FinancialAnalyzer/Models/BucketCategory.swift` | Refactor | High |
| 1A.3 | `FinancialAnalyzer/Models/Transaction.swift` | Refactor | High |
| 1B.1 | `FinancialAnalyzer/Models/MonthlyFlow.swift` | **Create** | High |
| 1B.2 | `FinancialAnalyzer/Models/FinancialPosition.swift` | **Create** | High |
| 1B.3 | `FinancialAnalyzer/Models/FinancialSnapshot.swift` | **Create** | High |
| 1C | `FinancialAnalyzer/Models/FinancialSummary.swift` | **Delete** | High |
| 1D | `Sources/` directory, `Package.swift` | **Delete** | Medium |
| 2 | `FinancialAnalyzer/Services/TransactionAnalyzer.swift` | **Replace** | 🔴 Critical |
| 3 | `FinancialAnalyzer/Services/SpendingPatternAnalyzer.swift` | Update | High |
| 4 | `FinancialAnalyzer/Services/BudgetManager.swift` | Update | Medium |
| 5 | `FinancialAnalyzer/Services/AlertRulesEngine.swift` | Update | Medium |
| 6 | Various Views/ViewModels | Migrate to FinancialSnapshot | Medium |

**Files NOT Changed:**
- `FinancialAnalyzer/Models/Budget.swift` - No changes needed
- `FinancialAnalyzer/Models/Goal.swift` - No changes needed

---

## 2. Problem Statement

### Current Calculation Logic (WRONG)

```swift
// In TransactionAnalyzer.categorizeToBucket():
if amount < 0 {
    return .income  // ❌ Catches ALL inflows including investments
}

// In TransactionAnalyzer.calculateSummary():
case .invested:
    expensesTotal += transaction.amount  // ❌ Investments aren't expenses

// Available to Spend calculation:
let availableToSpend = totalCashAvailable - estimatedRemainingExpenses  // ❌ Wrong formula
```

### Correct Calculation Logic (TARGET)

```swift
// Income should ONLY include:
// - Payroll deposits
// - Interest payments
// - Dividend payments
// - Actual income (not transfers or contributions)

// Expenses should EXCLUDE:
// - Investment contributions (401k, IRA, brokerage)
// - Internal transfers between accounts
// - Savings transfers

// Disposable Income formula:
disposableIncome = monthlyIncome - essentialExpenses - debtMinimums
```

### Reference Formula (from Transfer_Rule_Feature_-_Application_Logic.txt)

```
Disposable Income = Total Fixed Income - Total Fixed Expenses - Minimum Debt Payments
```

---

## 3. Architecture Overview

### File Dependency Graph

```
TransactionAnalyzer.swift (CORE - fix first)
    │
    ├── SpendingPatternAnalyzer.swift (uses bucketCategory)
    │       │
    │       └── BudgetManager.swift (uses generated budgets)
    │
    ├── AlertRulesEngine.swift (uses availableToSpend → disposableIncome)
    │
    └── FinancialSnapshot.swift (NEW - replaces FinancialSummary)
            │
            └── Views/ViewModels (consume FinancialSnapshot)
```

### New Model Structure

```
FinancialSnapshot
    ├── MonthlyFlow
    │       ├── income: Double
    │       ├── essentialExpenses: ExpenseBreakdown
    │       ├── debtMinimums: Double
    │       └── disposableIncome: Double (computed)
    │
    ├── FinancialPosition
    │       ├── emergencyCash: Double
    │       ├── debtBalances: [DebtAccount]
    │       ├── investmentBalances: Double
    │       └── monthlyInvestmentContributions: Double
    │
    └── AnalysisMetadata
            ├── monthsAnalyzed: Int
            ├── transactionsAnalyzed: Int
            ├── overallConfidence: Double
            └── lastUpdated: Date
```

---

## 4. Implementation Tasks

### Recommended Execution Order

```
Phase 1 - Foundation (TASK 1):
  1D → 1B → 1A → (hold 1C until Phase 3)

Phase 2 - Core Logic (TASKS 2-5):
  2 → 3 → 4 → 5

Phase 3 - Migration (TASK 6 + 1C):
  6 → 1C (delete FinancialSummary last)
```

---

### TASK 1: Model Files (Refactor + Create + Delete)

**Priority:** High  
**Estimated Time:** 60 minutes  
**Location:** `FinancialAnalyzer/Models/`

---

#### TASK 1A: Refactor Existing Models

##### 1A.1 Refactor `BankAccount.swift`

**File:** `FinancialAnalyzer/Models/BankAccount.swift`

**Problem:** Missing `minimumPayment` and `apr` properties needed for debt calculations.

**Changes Required:**

```swift
// ADD these properties after `limit: Double?` (around line 11):
var minimumPayment: Double?
var apr: Double?

// UPDATE init() to include new parameters:
init(
    id: String,
    itemId: String,
    name: String,
    officialName: String? = nil,
    type: String,
    subtype: String? = nil,
    mask: String? = nil,
    currentBalance: Double? = nil,
    availableBalance: Double? = nil,
    limit: Double? = nil,
    isoCurrencyCode: String? = nil,
    lastSyncDate: Date? = nil,
    minimumPayment: Double? = nil,  // ADD
    apr: Double? = nil              // ADD
) {
    // ... existing assignments ...
    self.minimumPayment = minimumPayment  // ADD
    self.apr = apr                        // ADD
}

// UPDATE CodingKeys enum to include new properties:
enum CodingKeys: String, CodingKey {
    // ... existing keys ...
    case minimumPayment
    case apr
}

// UPDATE encode(to:) method:
try container.encodeIfPresent(minimumPayment, forKey: .minimumPayment)
try container.encodeIfPresent(apr, forKey: .apr)

// UPDATE convenience init(from decoder:) in standard format section:
let minimumPayment = try? container.decode(Double.self, forKey: .minimumPayment)
let apr = try? container.decode(Double.self, forKey: .apr)

// Pass to self.init():
self.init(
    // ... existing params ...
    minimumPayment: minimumPayment,
    apr: apr
)
```

**Note:** Plaid's liabilities API provides these fields for credit/loan accounts.

**Acceptance Criteria:**
- [ ] Properties `minimumPayment` and `apr` exist
- [ ] Init accepts new parameters with defaults
- [ ] Codable encoding/decoding includes new fields
- [ ] Compiles without errors

---

##### 1A.2 Refactor `BucketCategory.swift`

**File:** `FinancialAnalyzer/Models/BucketCategory.swift`

**Problem:** `.disposable` case displays "Available to Spend" which must be removed.

**Changes Required:**

```swift
// CHANGE line 7:
// OLD:
case disposable = "Available to Spend"
// NEW:
case disposable = "Disposable Income"

// CHANGE description (around line 18-19):
// OLD:
case .disposable:
    return "Income minus expenses and debt obligations"
// NEW:
case .disposable:
    return "Monthly income minus essential expenses and minimum debt payments"
```

**Acceptance Criteria:**
- [ ] Raw value changed to "Disposable Income"
- [ ] Description updated to reflect correct formula
- [ ] No references to "Available to Spend" remain

---

##### 1A.3 Refactor `Transaction.swift`

**File:** `FinancialAnalyzer/Models/Transaction.swift`

**Problem:** Missing `categoryConfidence` property and `bucketCategory` doesn't pass full transaction context.

**Changes Required:**

```swift
// ADD property after `iso_currency_code` (around line 14):
var categoryConfidence: Double?

// UPDATE the bucketCategory computed property (around line 17-22):
// OLD:
var bucketCategory: BucketCategory {
    return TransactionAnalyzer.categorizeToBucket(
        amount: amount,
        category: category,
        categoryId: categoryId
    )
}
// NEW:
var bucketCategory: BucketCategory {
    return TransactionAnalyzer.categorizeToBucket(
        amount: amount,
        category: category,
        categoryId: categoryId,
        transaction: self
    )
}

// UPDATE init() to include categoryConfidence:
init(
    // ... existing params ...
    iso_currency_code: String? = nil,
    categoryConfidence: Double? = nil  // ADD
) {
    // ... existing assignments ...
    self.categoryConfidence = categoryConfidence  // ADD
}

// UPDATE CodingKeys enum:
enum CodingKeys: String, CodingKey {
    // ... existing keys ...
    case categoryConfidence
}

// UPDATE PlaidCodingKeys enum:
enum PlaidCodingKeys: String, CodingKey {
    // ... existing keys ...
    case categoryConfidence = "category_confidence"
}

// UPDATE encode(to:) method:
try container.encodeIfPresent(categoryConfidence, forKey: .categoryConfidence)

// UPDATE both convenience init(from decoder:) paths:
let categoryConfidence = try? container.decode(Double.self, forKey: .categoryConfidence)

// Pass to self.init():
self.init(
    // ... existing params ...
    categoryConfidence: categoryConfidence
)
```

**Note:** This change requires `TransactionAnalyzer.categorizeToBucket()` to accept a `transaction` parameter. This will cause a compile error until TASK 2 is complete (expected).

**Acceptance Criteria:**
- [ ] Property `categoryConfidence` exists
- [ ] `bucketCategory` passes `self` to analyzer
- [ ] Init accepts new parameter with default
- [ ] Both Codable paths handle new field

---

#### TASK 1B: Create New Model Files

##### 1B.1 Create `MonthlyFlow.swift`

**File:** `FinancialAnalyzer/Models/MonthlyFlow.swift`

```swift
import Foundation

/// Represents monthly cash flow (income minus expenses)
/// This is FLOW data - monthly averages, not point-in-time balances
struct MonthlyFlow: Codable, Equatable {
    /// Average monthly income from all sources
    let income: Double
    
    /// Breakdown of essential monthly expenses
    let essentialExpenses: ExpenseBreakdown
    
    /// Total minimum debt payments required monthly
    let debtMinimums: Double
    
    /// Computed: What's available to allocate after essentials
    /// Formula: Income - Essential Expenses - Debt Minimums
    var disposableIncome: Double {
        income - essentialExpenses.total - debtMinimums
    }
    
    /// Total essential expenses (convenience accessor)
    var totalEssentialExpenses: Double {
        essentialExpenses.total
    }
    
    /// Whether user has positive disposable income
    var hasPositiveDisposable: Bool {
        disposableIncome > 0
    }
    
    /// Daily budget based on disposable income (30-day month)
    var dailyDisposable: Double {
        disposableIncome / 30.0
    }
    
    /// Empty flow for initialization/error states
    static var empty: MonthlyFlow {
        MonthlyFlow(
            income: 0,
            essentialExpenses: .empty,
            debtMinimums: 0
        )
    }
}

// MARK: - Expense Breakdown

/// Breakdown of essential expenses by category
struct ExpenseBreakdown: Codable, Equatable {
    let housing: Double
    let food: Double
    let transportation: Double
    let utilities: Double
    let insurance: Double
    let subscriptions: Double
    let healthcare: Double
    let other: Double
    
    /// Confidence score for this classification (0.0 - 1.0)
    let confidence: Double
    
    /// Sum of all expense categories
    var total: Double {
        housing + food + transportation + utilities + 
        insurance + subscriptions + healthcare + other
    }
    
    /// Array of (category, amount) tuples for display
    var categories: [(String, Double)] {
        [
            ("Housing", housing),
            ("Food & Groceries", food),
            ("Transportation", transportation),
            ("Utilities", utilities),
            ("Insurance", insurance),
            ("Subscriptions", subscriptions),
            ("Healthcare", healthcare),
            ("Other Essentials", other)
        ].filter { $0.1 > 0 }
    }
    
    /// Returns confidence level as enum
    var confidenceLevel: ConfidenceLevel {
        if confidence >= 0.85 { return .high }
        if confidence >= 0.70 { return .medium }
        return .low
    }
    
    /// Empty breakdown for initialization
    static var empty: ExpenseBreakdown {
        ExpenseBreakdown(
            housing: 0, food: 0, transportation: 0, utilities: 0,
            insurance: 0, subscriptions: 0, healthcare: 0, other: 0,
            confidence: 0
        )
    }
}

// MARK: - Confidence Level

/// Confidence level for expense classification
enum ConfidenceLevel: String, Codable {
    case high
    case medium
    case low
    
    var color: String {
        switch self {
        case .high: return "green"
        case .medium: return "orange"
        case .low: return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .high: return "checkmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .low: return "xmark.circle.fill"
        }
    }
    
    var message: String {
        switch self {
        case .high:
            return "We're confident in these classifications based on clear transaction patterns."
        case .medium:
            return "Some transactions were difficult to classify. Review and adjust if needed."
        case .low:
            return "Many transactions were ambiguous. Please review carefully."
        }
    }
}
```

**Acceptance Criteria:**
- [ ] File compiles without errors
- [ ] `disposableIncome` computed property works correctly
- [ ] `ExpenseBreakdown.total` sums all categories
- [ ] `ConfidenceLevel` provides correct colors/icons

---

##### 1B.2 Create `FinancialPosition.swift`

**File:** `FinancialAnalyzer/Models/FinancialPosition.swift`

```swift
import Foundation

/// Represents current financial position (point-in-time balances)
/// This is POSITION data - current balances, not monthly flow
struct FinancialPosition: Codable, Equatable {
    /// Cash available in liquid accounts (checking + savings)
    let emergencyCash: Double
    
    /// All debt accounts with balances
    let debtBalances: [DebtAccount]
    
    /// Total investment account balances
    let investmentBalances: Double
    
    /// Monthly investment contributions (tracked separately from expenses)
    let monthlyInvestmentContributions: Double
    
    // MARK: - Computed Properties
    
    /// Total debt across all accounts
    var totalDebt: Double {
        debtBalances.reduce(0) { $0 + $1.balance }
    }
    
    /// Total minimum payments required
    var totalMinimumPayments: Double {
        debtBalances.reduce(0) { $0 + $1.minimumPayment }
    }
    
    /// Weighted average APR across all debt
    var weightedAverageAPR: Double {
        guard totalDebt > 0 else { return 0 }
        let weightedSum = debtBalances.reduce(0.0) { sum, debt in
            sum + (debt.balance * debt.apr)
        }
        return weightedSum / totalDebt
    }
    
    /// Whether user has high-interest debt (>15% APR)
    var hasHighInterestDebt: Bool {
        debtBalances.contains { $0.apr > 0.15 }
    }
    
    /// Highest APR debt account
    var highestAPRDebt: DebtAccount? {
        debtBalances.max(by: { $0.apr < $1.apr })
    }
    
    /// Emergency fund months coverage
    func emergencyFundMonths(monthlyExpenses: Double) -> Double {
        guard monthlyExpenses > 0 else { return 0 }
        return emergencyCash / monthlyExpenses
    }
    
    /// Net worth (simple: cash + investments - debt)
    var netWorth: Double {
        emergencyCash + investmentBalances - totalDebt
    }
    
    /// Empty position for initialization/error states
    static var empty: FinancialPosition {
        FinancialPosition(
            emergencyCash: 0,
            debtBalances: [],
            investmentBalances: 0,
            monthlyInvestmentContributions: 0
        )
    }
}

// MARK: - Debt Account

/// Individual debt account
struct DebtAccount: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let type: DebtType
    let balance: Double
    let apr: Double
    let minimumPayment: Double
    
    /// Monthly interest cost
    var monthlyInterestCost: Double {
        (balance * apr) / 12.0
    }
    
    /// Whether this is high-interest debt (>15% APR)
    var isHighInterest: Bool {
        apr > 0.15
    }
    
    /// Estimated months to payoff at minimum payments
    var monthsToPayoffAtMinimum: Int? {
        guard minimumPayment > monthlyInterestCost else { return nil }
        let principalPayment = minimumPayment - monthlyInterestCost
        guard principalPayment > 0 else { return nil }
        return Int(ceil(balance / principalPayment))
    }
    
    /// Create from BankAccount (for credit/loan accounts)
    init(from account: BankAccount) {
        self.id = account.id
        self.name = account.name
        self.type = DebtType(from: account.subtype ?? account.type)
        self.balance = abs(account.currentBalance ?? 0)
        self.apr = account.apr ?? 0
        self.minimumPayment = account.minimumPayment ?? Self.estimateMinimumPayment(
            balance: abs(account.currentBalance ?? 0),
            type: DebtType(from: account.subtype ?? account.type)
        )
    }
    
    /// Standard initializer
    init(id: String, name: String, type: DebtType, balance: Double, apr: Double, minimumPayment: Double) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
        self.apr = apr
        self.minimumPayment = minimumPayment
    }
    
    /// Estimate minimum payment when not provided by Plaid
    static func estimateMinimumPayment(balance: Double, type: DebtType) -> Double {
        switch type {
        case .creditCard:
            // Credit cards: typically 2-3% of balance, minimum $25
            return max(balance * 0.025, 25)
        case .studentLoan:
            // Student loans: estimate based on standard 10-year repayment
            return balance / 120
        case .autoLoan:
            // Auto loans: estimate based on 5-year term
            return balance / 60
        case .personalLoan:
            // Personal loans: estimate based on 3-year term
            return balance / 36
        case .mortgage:
            // Mortgage: estimate based on 30-year term + rough interest
            return (balance / 360) * 1.5
        case .other:
            // Default: 2% of balance, minimum $25
            return max(balance * 0.02, 25)
        }
    }
}

// MARK: - Debt Type

/// Types of debt accounts
enum DebtType: String, Codable {
    case creditCard = "credit_card"
    case studentLoan = "student_loan"
    case autoLoan = "auto_loan"
    case personalLoan = "personal_loan"
    case mortgage = "mortgage"
    case other = "other"
    
    init(from subtype: String) {
        switch subtype.lowercased() {
        case "credit card", "credit_card":
            self = .creditCard
        case "student", "student loan", "student_loan":
            self = .studentLoan
        case "auto", "auto loan", "auto_loan", "vehicle":
            self = .autoLoan
        case "personal", "personal loan", "personal_loan":
            self = .personalLoan
        case "mortgage", "home":
            self = .mortgage
        default:
            self = .other
        }
    }
    
    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .studentLoan: return "Student Loan"
        case .autoLoan: return "Auto Loan"
        case .personalLoan: return "Personal Loan"
        case .mortgage: return "Mortgage"
        case .other: return "Other Debt"
        }
    }
}
```

**Acceptance Criteria:**
- [ ] File compiles without errors
- [ ] `totalDebt` computed correctly from array
- [ ] `weightedAverageAPR` handles empty debt array
- [ ] `DebtAccount` can be created from `BankAccount`
- [ ] Minimum payment estimation works for all debt types

---

##### 1B.3 Create `FinancialSnapshot.swift`

**File:** `FinancialAnalyzer/Models/FinancialSnapshot.swift`

```swift
import Foundation

/// Complete financial snapshot combining flow and position
/// This is what gets passed to the allocation algorithm
struct FinancialSnapshot: Codable {
    let monthlyFlow: MonthlyFlow
    let position: FinancialPosition
    let analysisMetadata: AnalysisMetadata
    
    // MARK: - Convenience Accessors (for easy migration from FinancialSummary)
    
    /// Disposable income available for allocation
    var disposableIncome: Double {
        monthlyFlow.disposableIncome
    }
    
    /// Total essential expenses (monthly average)
    var monthlyEssentialExpenses: Double {
        monthlyFlow.totalEssentialExpenses
    }
    
    /// Monthly income (average)
    var monthlyIncome: Double {
        monthlyFlow.income
    }
    
    /// Alias for monthlyIncome (for migration)
    var avgMonthlyIncome: Double {
        monthlyFlow.income
    }
    
    /// Alias for monthlyEssentialExpenses (for migration)
    var avgMonthlyExpenses: Double {
        monthlyFlow.totalEssentialExpenses
    }
    
    /// Total debt
    var totalDebt: Double {
        position.totalDebt
    }
    
    /// Total invested
    var totalInvested: Double {
        position.investmentBalances
    }
    
    /// Total cash available
    var totalCashAvailable: Double {
        position.emergencyCash
    }
    
    /// Emergency fund months
    var emergencyFundMonths: Double {
        position.emergencyFundMonths(monthlyExpenses: monthlyEssentialExpenses)
    }
    
    /// Net worth
    var netWorth: Double {
        position.netWorth
    }
    
    /// Monthly net income (income - expenses, before allocation)
    var monthlyNetIncome: Double {
        monthlyFlow.income - monthlyFlow.totalEssentialExpenses
    }
    
    // MARK: - Validation
    
    /// Whether financial snapshot is valid for algorithm
    var isValidForAllocation: Bool {
        monthlyFlow.disposableIncome > 0 && 
        analysisMetadata.overallConfidence >= 0.5
    }
    
    /// Validation error message if not valid
    var validationError: String? {
        if monthlyFlow.disposableIncome <= 0 {
            return "Your expenses exceed your income. Please review your numbers before we can create an allocation plan."
        }
        if analysisMetadata.overallConfidence < 0.5 {
            return "We couldn't confidently analyze your transactions. Please connect more accounts or review the classifications."
        }
        return nil
    }
    
    // MARK: - BucketCategory Support (for migration)
    
    /// Returns value for a given bucket category (replaces FinancialSummary.bucketValue)
    func bucketValue(for category: BucketCategory) -> Double {
        switch category {
        case .income:
            return monthlyIncome
        case .expenses:
            return monthlyEssentialExpenses
        case .debt:
            return totalDebt
        case .invested:
            return totalInvested
        case .cash:
            return totalCashAvailable
        case .disposable:
            return disposableIncome
        }
    }
    
    // MARK: - Empty State
    
    /// Empty snapshot for initialization/error states
    static var empty: FinancialSnapshot {
        FinancialSnapshot(
            monthlyFlow: .empty,
            position: .empty,
            analysisMetadata: AnalysisMetadata(
                monthsAnalyzed: 0,
                accountsConnected: 0,
                transactionsAnalyzed: 0,
                overallConfidence: 0,
                analysisStartDate: Date(),
                analysisEndDate: Date(),
                lastUpdated: Date()
            )
        )
    }
}

// MARK: - Analysis Metadata

/// Metadata about the analysis
struct AnalysisMetadata: Codable {
    let monthsAnalyzed: Int
    let accountsConnected: Int
    let transactionsAnalyzed: Int
    let overallConfidence: Double
    let analysisStartDate: Date
    let analysisEndDate: Date
    let lastUpdated: Date
    
    /// Whether to show confidence warnings to user
    var shouldShowConfidenceWarning: Bool {
        overallConfidence < 0.85
    }
    
    /// Human-readable analysis period
    var analysisPeriodDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return "\(formatter.string(from: analysisStartDate)) - \(formatter.string(from: analysisEndDate))"
    }
    
    /// Days since last update
    var daysSinceUpdate: Int {
        Calendar.current.dateComponents([.day], from: lastUpdated, to: Date()).day ?? 0
    }
    
    /// Whether data is stale (>7 days old)
    var isStale: Bool {
        daysSinceUpdate > 7
    }
}
```

**Acceptance Criteria:**
- [ ] File compiles without errors
- [ ] All convenience accessors work correctly
- [ ] `isValidForAllocation` correctly validates snapshot
- [ ] `bucketValue(for:)` returns correct values for all cases
- [ ] `empty` static property provides safe default

---

#### TASK 1C: Delete FinancialSummary

**File:** `FinancialAnalyzer/Models/FinancialSummary.swift`

**Action:** Delete this file entirely after all consumers are migrated (end of TASK 6)

**Before Deleting - Identify Consumers:**

Run this command to find all files that reference `FinancialSummary`:

```bash
grep -r "FinancialSummary" --include="*.swift" FinancialAnalyzer/
```

**Expected Consumers (to be migrated in TASK 6):**

| File | Update Required |
|------|-----------------|
| `TransactionAnalyzer.swift` | Change return type to `FinancialSnapshot` |
| `AlertRulesEngine.swift` | Change parameter type to `FinancialSnapshot` |
| Various View files | Update to use `FinancialSnapshot` |
| Various ViewModel files | Update stored properties |

**Execution Timing:**
- **DO NOT DELETE** until all TASK 6 migrations are complete
- Delete as the final step of the implementation

**Acceptance Criteria:**
- [ ] All consumers of FinancialSummary identified and listed
- [ ] File deleted after all consumers migrated
- [ ] No references to `FinancialSummary` remain in codebase
- [ ] No references to `availableToSpend` remain in codebase

---

#### TASK 1D: Delete Deprecated SPM Scaffolding

**Action:** Delete the following deprecated files/directories:

| Path | Reason |
|------|--------|
| `Sources/` directory | Deprecated SPM scaffolding, not referenced by Xcode project |
| `Package.swift` | SPM manifest, not used |

**Steps:**

```bash
# From project root:
rm -rf Sources/
rm -f Package.swift
```

**Verification:**

After deletion, ensure:
1. Xcode project still builds
2. No broken file references in `.xcodeproj`
3. All active code remains in `FinancialAnalyzer/`

**Acceptance Criteria:**
- [ ] `Sources/` directory deleted
- [ ] `Package.swift` deleted
- [ ] Project builds successfully
- [ ] No orphaned file references in Xcode

---

### TASK 2: Rewrite TransactionAnalyzer.swift

**Priority:** 🔴 CRITICAL  
**Estimated Time:** 2 hours  
**Location:** `FinancialAnalyzer/Services/TransactionAnalyzer.swift`

#### 2.1 Complete File Replacement

Replace the entire contents of `TransactionAnalyzer.swift` with the following:

**File:** `FinancialAnalyzer/Services/TransactionAnalyzer.swift`

```swift
// FinancialAnalyzer/Services/TransactionAnalyzer.swift

import Foundation

/// Analyzes transactions to calculate monthly flow and financial position
/// CRITICAL: This is the core calculation engine - accuracy is paramount
struct TransactionAnalyzer {
    
    // MARK: - Main Analysis Function
    
    /// Generates a complete financial snapshot from transactions and accounts
    /// - Parameters:
    ///   - transactions: All transactions from connected accounts
    ///   - accounts: All connected bank accounts
    /// - Returns: Complete FinancialSnapshot for display and algorithm
    static func generateSnapshot(
        transactions: [Transaction],
        accounts: [BankAccount]
    ) -> FinancialSnapshot {
        
        // Filter to last 6 months
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let filteredTransactions = transactions.filter { 
            $0.date >= sixMonthsAgo && !$0.pending 
        }
        
        // Calculate analysis period
        let analysisStartDate = filteredTransactions.map { $0.date }.min() ?? Date()
        let analysisEndDate = filteredTransactions.map { $0.date }.max() ?? Date()
        let monthsAnalyzed = max(
            Calendar.current.dateComponents([.month], from: analysisStartDate, to: analysisEndDate).month ?? 1,
            1
        )
        
        // Calculate monthly flow
        let monthlyFlow = calculateMonthlyFlow(
            transactions: filteredTransactions,
            accounts: accounts,
            months: monthsAnalyzed
        )
        
        // Calculate financial position
        let position = calculateFinancialPosition(
            transactions: filteredTransactions,
            accounts: accounts,
            months: monthsAnalyzed
        )
        
        // Build metadata
        let metadata = AnalysisMetadata(
            monthsAnalyzed: monthsAnalyzed,
            accountsConnected: accounts.count,
            transactionsAnalyzed: filteredTransactions.count,
            overallConfidence: monthlyFlow.essentialExpenses.confidence,
            analysisStartDate: analysisStartDate,
            analysisEndDate: analysisEndDate,
            lastUpdated: Date()
        )
        
        return FinancialSnapshot(
            monthlyFlow: monthlyFlow,
            position: position,
            analysisMetadata: metadata
        )
    }
    
    // MARK: - Monthly Flow Calculation
    
    /// Calculate monthly cash flow from transactions
    static func calculateMonthlyFlow(
        transactions: [Transaction],
        accounts: [BankAccount],
        months: Int
    ) -> MonthlyFlow {
        guard months > 0 else {
            return MonthlyFlow(
                income: 0,
                essentialExpenses: .empty,
                debtMinimums: 0
            )
        }
        
        // Calculate monthly income (ONLY actual income, not transfers)
        let incomeTransactions = transactions.filter { transaction in
            isActualIncome(transaction) && !isInvestmentContribution(transaction)
        }
        let totalIncome = incomeTransactions.reduce(0) { $0 + abs($1.amount) }
        let monthlyIncome = totalIncome / Double(months)
        
        // Calculate essential expenses (EXCLUDE investment contributions)
        let essentialTransactions = transactions.filter { transaction in
            isEssentialExpense(transaction) && !isInvestmentContribution(transaction)
        }
        let expenseBreakdown = categorizeEssentialExpenses(
            essentialTransactions,
            months: months
        )
        
        // Calculate minimum debt payments from accounts
        let debtMinimums = calculateMinimumDebtPayments(accounts: accounts)
        
        return MonthlyFlow(
            income: monthlyIncome,
            essentialExpenses: expenseBreakdown,
            debtMinimums: debtMinimums
        )
    }
    
    // MARK: - Financial Position Calculation
    
    /// Calculate current financial position from account balances
    static func calculateFinancialPosition(
        transactions: [Transaction],
        accounts: [BankAccount],
        months: Int
    ) -> FinancialPosition {
        
        // Emergency cash (liquid depository accounts only)
        let liquidAccounts = accounts.filter { account in
            account.isDepository && account.subtype != "cd"
        }
        let emergencyCash = liquidAccounts.reduce(0) { 
            $0 + ($1.availableBalance ?? $1.currentBalance ?? 0)
        }
        
        // Debt accounts
        let debtAccounts = accounts.filter { 
            $0.isCredit || $0.isLoan 
        }.map { DebtAccount(from: $0) }
        
        // Investment balances
        let investmentAccounts = accounts.filter { $0.isInvestment }
        let investmentBalances = investmentAccounts.reduce(0) { 
            $0 + ($1.currentBalance ?? 0)
        }
        
        // Track investment contributions separately (NOT as expense)
        let investmentContributions = transactions.filter { isInvestmentContribution($0) }
        let totalContributions = investmentContributions.reduce(0) { $0 + abs($1.amount) }
        let monthlyContributions = months > 0 ? totalContributions / Double(months) : 0
        
        return FinancialPosition(
            emergencyCash: emergencyCash,
            debtBalances: debtAccounts,
            investmentBalances: investmentBalances,
            monthlyInvestmentContributions: monthlyContributions
        )
    }
    
    // MARK: - Transaction Classification Helpers
    
    /// Determines if a transaction is actual income (not a transfer or contribution)
    /// CRITICAL: This prevents investment contributions from being counted as income
    static func isActualIncome(_ transaction: Transaction) -> Bool {
        // In Plaid, negative amounts = money flowing INTO the account
        guard transaction.amount < 0 else { return false }
        
        // Check for income-related categories
        let incomeCategories = [
            "INCOME",
            "PAYROLL",
            "DIRECT_DEPOSIT",
            "INTEREST",
            "DIVIDEND",
            "TAX_REFUND",
            "UNEMPLOYMENT",
            "SOCIAL_SECURITY"
        ]
        
        if let category = transaction.category.first?.uppercased() {
            // Explicit income categories
            if incomeCategories.contains(where: { category.contains($0) }) {
                return true
            }
            
            // Exclude transfers - these are NOT income
            if category.contains("TRANSFER") {
                return false
            }
        }
        
        // Check transaction name for payroll patterns
        let incomeMerchants = [
            "payroll", "direct dep", "salary", "wages", 
            "ach deposit", "employer", "corp"
        ]
        let nameLower = transaction.name.lowercased()
        if incomeMerchants.contains(where: { nameLower.contains($0) }) {
            return true
        }
        
        // Interest and dividend payments
        if nameLower.contains("interest") || nameLower.contains("dividend") {
            return true
        }
        
        return false
    }
    
    /// Determines if a transaction is an investment contribution
    /// CRITICAL: These should NOT be counted as expenses
    static func isInvestmentContribution(_ transaction: Transaction) -> Bool {
        // Check Plaid category codes for investment transfers
        let investmentCategories = [
            "TRANSFER_OUT_INVESTMENT",
            "TRANSFER_OUT_RETIREMENT",
            "TRANSFER_IN_INVESTMENT",
            "TRANSFER_IN_RETIREMENT",
            "401K",
            "IRA",
            "CONTRIBUTION",
            "INVESTMENT"
        ]
        
        if let category = transaction.category.first?.uppercased() {
            if investmentCategories.contains(where: { category.contains($0) }) {
                return true
            }
        }
        
        // Check merchant name patterns
        let investmentMerchants = [
            "vanguard", "fidelity", "schwab", "betterment", "wealthfront",
            "robinhood", "etrade", "td ameritrade", "merrill", "401k",
            "retirement", "roth", "ira"
        ]
        let nameLower = transaction.name.lowercased()
        if investmentMerchants.contains(where: { nameLower.contains($0) }) {
            // Additional check: make sure it's a contribution, not just account activity
            let contributionTerms = ["contribution", "transfer", "deposit", "buy", "purchase"]
            if contributionTerms.contains(where: { nameLower.contains($0) }) {
                return true
            }
            // If it's FROM a checking/savings TO investment, it's a contribution
            if transaction.amount > 0 {
                return true
            }
        }
        
        // Check if transaction description indicates employee contribution
        if nameLower.contains("employee contribution") || 
           nameLower.contains("employer match") ||
           nameLower.contains("monthly contribution") {
            return true
        }
        
        return false
    }
    
    /// Determines if a transaction is an internal transfer (between user's own accounts)
    static func isInternalTransfer(_ transaction: Transaction) -> Bool {
        let transferCategories = [
            "TRANSFER_INTERNAL",
            "TRANSFER_SAME_INSTITUTION"
        ]
        
        if let category = transaction.category.first?.uppercased() {
            if transferCategories.contains(where: { category.contains($0) }) {
                return true
            }
        }
        
        let nameLower = transaction.name.lowercased()
        let transferTerms = [
            "transfer to", "transfer from", "internal transfer",
            "online transfer", "funds transfer"
        ]
        
        return transferTerms.contains(where: { nameLower.contains($0) })
    }
    
    /// Determines if a transaction is an essential expense
    private static func isEssentialExpense(_ transaction: Transaction) -> Bool {
        // Must be an outflow (positive amount in Plaid = money OUT)
        guard transaction.amount > 0 else { return false }
        
        // Must NOT be an investment contribution
        guard !isInvestmentContribution(transaction) else { return false }
        
        // Must NOT be an internal transfer
        guard !isInternalTransfer(transaction) else { return false }
        
        return true
    }
    
    /// Convenience method for other services to check if transaction should be excluded
    static func shouldExcludeFromBudget(_ transaction: Transaction) -> Bool {
        isInvestmentContribution(transaction) || isInternalTransfer(transaction)
    }
    
    // MARK: - Expense Categorization
    
    /// Categorizes essential expenses with confidence scoring
    private static func categorizeEssentialExpenses(
        _ transactions: [Transaction],
        months: Int
    ) -> ExpenseBreakdown {
        guard months > 0 else { return .empty }
        
        var housing = 0.0
        var food = 0.0
        var transportation = 0.0
        var utilities = 0.0
        var insurance = 0.0
        var subscriptions = 0.0
        var healthcare = 0.0
        var other = 0.0
        var confidenceSum = 0.0
        var confidenceCount = 0
        
        for transaction in transactions {
            let amount = abs(transaction.amount)
            let confidence = determineConfidence(for: transaction)
            
            // Categorize based on Plaid category
            let category = transaction.category.first?.uppercased() ?? ""
            
            switch true {
            case category.contains("RENT") || category.contains("MORTGAGE"):
                housing += amount
                
            case category.contains("GROCERIES") || category.contains("FOOD_AND_DRINK"):
                food += amount
                
            case category.contains("GAS_STATION") || category.contains("PUBLIC_TRANSIT") ||
                 category.contains("PARKING") || category.contains("TRANSPORTATION") ||
                 category.contains("AUTOMOTIVE"):
                transportation += amount
                
            case category.contains("ELECTRIC") || category.contains("WATER") ||
                 category.contains("GAS_UTILITY") || category.contains("INTERNET") ||
                 category.contains("PHONE") || category.contains("UTILITIES"):
                utilities += amount
                
            case category.contains("INSURANCE"):
                insurance += amount
                
            case category.contains("SUBSCRIPTION") || category.contains("STREAMING"):
                subscriptions += amount
                
            case category.contains("MEDICAL") || category.contains("HEALTHCARE") ||
                 category.contains("PHARMACY"):
                healthcare += amount
                
            default:
                // Only include in "other" if it appears to be recurring/essential
                if isRecurringEssential(transaction) {
                    other += amount
                }
            }
            
            confidenceSum += confidence
            confidenceCount += 1
        }
        
        let avgConfidence = confidenceCount > 0 ? confidenceSum / Double(confidenceCount) : 0.5
        
        return ExpenseBreakdown(
            housing: housing / Double(months),
            food: food / Double(months),
            transportation: transportation / Double(months),
            utilities: utilities / Double(months),
            insurance: insurance / Double(months),
            subscriptions: subscriptions / Double(months),
            healthcare: healthcare / Double(months),
            other: other / Double(months),
            confidence: avgConfidence
        )
    }
    
    /// Determines confidence level for a transaction's classification
    private static func determineConfidence(for transaction: Transaction) -> Double {
        var confidence = 0.5
        
        // Plaid provides category confidence
        if let plaidConfidence = transaction.categoryConfidence {
            confidence = plaidConfidence
        }
        
        // Boost confidence for clear categories
        let category = transaction.category.first?.uppercased() ?? ""
        let clearCategories = ["RENT", "MORTGAGE", "GROCERIES", "GAS_STATION", "UTILITIES"]
        if clearCategories.contains(where: { category.contains($0) }) {
            confidence = max(confidence, 0.9)
        }
        
        // Reduce confidence for ambiguous patterns
        let ambiguousTerms = ["venmo", "zelle", "cash app", "paypal", "atm"]
        let nameLower = transaction.name.lowercased()
        if ambiguousTerms.contains(where: { nameLower.contains($0) }) {
            confidence = min(confidence, 0.6)
        }
        
        return confidence
    }
    
    /// Determines if a transaction appears to be a recurring essential expense
    private static func isRecurringEssential(_ transaction: Transaction) -> Bool {
        let recurringTerms = ["monthly", "annual", "subscription", "membership", "bill pay"]
        let nameLower = transaction.name.lowercased()
        return recurringTerms.contains(where: { nameLower.contains($0) })
    }
    
    // MARK: - Debt Calculation Helpers
    
    /// Calculates total minimum debt payments from accounts
    private static func calculateMinimumDebtPayments(accounts: [BankAccount]) -> Double {
        let debtAccounts = accounts.filter { $0.isCredit || $0.isLoan }
        return debtAccounts.reduce(0) { sum, account in
            sum + (account.minimumPayment ?? estimateMinimumPayment(for: account))
        }
    }
    
    /// Estimates minimum payment if not provided by Plaid
    private static func estimateMinimumPayment(for account: BankAccount) -> Double {
        guard let balance = account.currentBalance, balance > 0 else { return 0 }
        
        if account.isCredit {
            // Credit cards: typically 2-3% of balance, minimum $25
            return max(balance * 0.025, 25)
        } else if account.isLoan {
            // Loans: estimate based on typical payment structure
            return balance * 0.02
        }
        
        return 0
    }
    
    /// Estimates APR if not provided by Plaid
    private static func estimateAPR(for account: BankAccount) -> Double {
        if account.isCredit {
            return 0.22  // Average credit card APR
        } else if account.subtype?.lowercased().contains("student") == true {
            return 0.055  // Average federal student loan
        } else if account.subtype?.lowercased().contains("auto") == true {
            return 0.065  // Average auto loan
        } else if account.subtype?.lowercased().contains("mortgage") == true {
            return 0.07   // Average mortgage rate
        }
        return 0.08  // Default estimate
    }
    
    // MARK: - Legacy Support (Bucket Category)
    
    /// Maps transaction to bucket category for backward compatibility
    static func categorizeToBucket(
        amount: Double,
        category: [String],
        categoryId: String?,
        transaction: Transaction? = nil
    ) -> BucketCategory {
        
        // If we have the full transaction, use the new classification
        if let txn = transaction {
            if isActualIncome(txn) && !isInvestmentContribution(txn) {
                return .income
            }
            if isInvestmentContribution(txn) {
                return .invested
            }
            if isInternalTransfer(txn) {
                return .cash  // Internal transfers don't affect budget
            }
        }
        
        // Fallback to category-based classification
        if amount < 0 {
            // Check if it's actually income vs transfer/contribution
            if let primaryCategory = category.first?.uppercased() {
                if primaryCategory.contains("TRANSFER") ||
                   primaryCategory.contains("INVESTMENT") ||
                   primaryCategory.contains("401K") ||
                   primaryCategory.contains("IRA") {
                    return .invested
                }
            }
            return .income
        }
        
        // Debt payments
        if let primaryCategory = category.first?.lowercased() {
            if primaryCategory.contains("credit card") ||
               primaryCategory.contains("loan payments") ||
               primaryCategory.contains("mortgage") {
                return .debt
            }
        }
        
        // Default to expenses for positive amounts
        return .expenses
    }
    
    // MARK: - Analysis Helpers (for other services)
    
    /// Gets expense breakdown by category
    static func expensesByCategory(from transactions: [Transaction]) -> [String: Double] {
        var breakdown: [String: Double] = [:]
        
        for transaction in transactions {
            guard isEssentialExpense(transaction) else { continue }
            let categoryName = transaction.category.first ?? "Uncategorized"
            breakdown[categoryName, default: 0] += transaction.amount
        }
        
        return breakdown
    }
    
    /// Gets monthly trends for a specific transaction type
    static func monthlyTrends(
        from transactions: [Transaction],
        filter: (Transaction) -> Bool
    ) -> [Date: Double] {
        var monthlyData: [Date: Double] = [:]
        let calendar = Calendar.current
        
        for transaction in transactions where filter(transaction) {
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            monthlyData[monthStart, default: 0] += abs(transaction.amount)
        }
        
        return monthlyData
    }
}
```

**Acceptance Criteria for Task 2:**
- [ ] File compiles without errors
- [ ] `isInvestmentContribution()` correctly identifies 401k, IRA, brokerage contributions
- [ ] `isActualIncome()` only returns true for payroll, dividends, interest
- [ ] `isInternalTransfer()` filters out account-to-account transfers
- [ ] NO reference to `availableToSpend` anywhere in the file
- [ ] `disposableIncome` is calculated as: income - essentials - debt minimums
- [ ] Expense categorization excludes investment contributions
- [ ] `shouldExcludeFromBudget()` helper exposed for other services

---

### TASK 3: Update SpendingPatternAnalyzer.swift

**Priority:** High  
**Estimated Time:** 30 minutes  
**Location:** `FinancialAnalyzer/Services/SpendingPatternAnalyzer.swift`

#### 3.1 Update Budget Generation

Find the `generateBudgetsFromHistory` function and update the filtering logic:

```swift
// REPLACE this section in generateBudgetsFromHistory:

// OLD CODE (around line 15-20):
for transaction in recentTransactions {
    guard transaction.amount > 0,
          transaction.bucketCategory == .expenses else { continue }

// NEW CODE:
for transaction in recentTransactions {
    // Use the new classification helpers
    guard transaction.amount > 0,
          !TransactionAnalyzer.shouldExcludeFromBudget(transaction) else { continue }
```

**Acceptance Criteria for Task 3:**
- [ ] Budget generation excludes investment contributions
- [ ] Budget generation excludes internal transfers
- [ ] Generated budgets only reflect true discretionary spending

---

### TASK 4: Update BudgetManager.swift

**Priority:** Medium  
**Estimated Time:** 20 minutes  
**Location:** `FinancialAnalyzer/Services/BudgetManager.swift`

#### 4.1 Update recordTransaction Method

```swift
// REPLACE the guard statement in recordTransaction:

// OLD CODE (around line 49):
func recordTransaction(_ transaction: Transaction) {
    guard transaction.amount > 0,
          transaction.bucketCategory == .expenses else { return }

// NEW CODE:
func recordTransaction(_ transaction: Transaction) {
    // Only record actual expenses, not investments or transfers
    guard transaction.amount > 0,
          !TransactionAnalyzer.shouldExcludeFromBudget(transaction) else { return }
```

**Acceptance Criteria for Task 4:**
- [ ] Budget tracking excludes investment contributions
- [ ] Budget tracking excludes internal transfers

---

### TASK 5: Update AlertRulesEngine.swift

**Priority:** Medium  
**Estimated Time:** 30 minutes  
**Location:** `FinancialAnalyzer/Services/AlertRulesEngine.swift`

#### 5.1 Replace `availableToSpend` Parameter

```swift
// CHANGE the function signature:

// OLD:
static func evaluatePurchase(
    amount: Double,
    merchantName: String,
    category: String,
    budgets: [Budget],
    goals: [Goal],
    transactions: [Transaction],
    availableToSpend: Double  // ❌ Remove this
) -> [ProactiveAlert]

// NEW:
static func evaluatePurchase(
    amount: Double,
    merchantName: String,
    category: String,
    budgets: [Budget],
    goals: [Goal],
    transactions: [Transaction],
    disposableIncome: Double  // ✅ Use this instead
) -> [ProactiveAlert]
```

#### 5.2 Update All Internal References

Search and replace within the file:
- `availableToSpend` → `disposableIncome`

#### 5.3 Update `generateReallocationOptions`

```swift
// CHANGE parameter name:
private static func generateReallocationOptions(
    neededAmount: Double,
    availableBudgets: [Budget],
    disposableIncome: Double  // Changed from availableToSpend
) -> [AlertAction]
```

**Acceptance Criteria for Task 5:**
- [ ] No reference to `availableToSpend` in the file
- [ ] All alerts use `disposableIncome` correctly
- [ ] Alert generation still functions correctly

---

### TASK 6: Migrate All Consumers to FinancialSnapshot

**Priority:** Medium  
**Estimated Time:** 45 minutes  
**Location:** Various files

#### 6.1 Search for All References

Run these commands to find all files that need updating:

```bash
grep -r "availableToSpend" --include="*.swift" FinancialAnalyzer/
grep -r "FinancialSummary" --include="*.swift" FinancialAnalyzer/
grep -r "calculateSummary" --include="*.swift" FinancialAnalyzer/
```

#### 6.2 Update Each Consumer

**Pattern 1: Change function calls**
```swift
// OLD:
let summary = TransactionAnalyzer.calculateSummary(transactions: txns, accounts: accts)

// NEW:
let snapshot = TransactionAnalyzer.generateSnapshot(transactions: txns, accounts: accts)
```

**Pattern 2: Update stored properties**
```swift
// OLD:
@Published var summary: FinancialSummary?

// NEW:
@Published var snapshot: FinancialSnapshot?
```

**Pattern 3: Update function parameters**
```swift
// OLD:
func analyze(summary: FinancialSummary)

// NEW:
func analyze(snapshot: FinancialSnapshot)
```

**Pattern 4: Update property access (using convenience accessors)**
```swift
// OLD:
let income = summary.avgMonthlyIncome
let available = summary.availableToSpend

// NEW (convenience accessors make this easy):
let income = snapshot.avgMonthlyIncome  // Same name!
let available = snapshot.disposableIncome  // Renamed
```

#### 6.3 Common Files to Check

These files likely reference the affected code:
- ViewModels (any `*ViewModel.swift`)
- Views that display financial data
- Any service files not already covered
- Test files

#### 6.4 After All Migrations Complete

Execute TASK 1C: Delete `FinancialSummary.swift`

```bash
rm FinancialAnalyzer/Models/FinancialSummary.swift
```

**Acceptance Criteria for Task 6:**
- [ ] `grep -r "availableToSpend" --include="*.swift" FinancialAnalyzer/` returns 0 results
- [ ] `grep -r "FinancialSummary" --include="*.swift" FinancialAnalyzer/` returns 0 results
- [ ] All consumers compile without errors
- [ ] `FinancialSummary.swift` deleted
- [ ] New `generateSnapshot()` method used everywhere

---

## 5. Testing & Validation

### Unit Test Cases

Create `TransactionAnalyzerTests.swift` in your test target:

```swift
import XCTest
@testable import FinancialAnalyzer

final class TransactionAnalyzerTests: XCTestCase {
    
    // MARK: - Income Classification Tests
    
    func testPayrollIsClassifiedAsIncome() {
        let transaction = mockTransaction(
            amount: -2500,
            name: "PAYROLL DEPOSIT - ACME CORP",
            category: ["INCOME", "PAYROLL"]
        )
        
        XCTAssertTrue(TransactionAnalyzer.isActualIncome(transaction))
        XCTAssertFalse(TransactionAnalyzer.isInvestmentContribution(transaction))
    }
    
    func test401kContributionIsNotIncome() {
        let transaction = mockTransaction(
            amount: -500,
            name: "EMPLOYEE CONTRIBUTION",
            category: ["TRANSFER_OUT_RETIREMENT"]
        )
        
        XCTAssertTrue(TransactionAnalyzer.isInvestmentContribution(transaction))
        XCTAssertFalse(TransactionAnalyzer.isActualIncome(transaction))
    }
    
    func testIRAContributionIsNotIncome() {
        let transaction = mockTransaction(
            amount: -500,
            name: "MONTHLY CONTRIBUTION",
            category: ["TRANSFER_OUT_INVESTMENT"]
        )
        
        XCTAssertTrue(TransactionAnalyzer.isInvestmentContribution(transaction))
    }
    
    func testSavingsTransferIsNotIncome() {
        let transaction = mockTransaction(
            amount: -500,
            name: "TRANSFER TO SAVINGS",
            category: ["TRANSFER_INTERNAL"]
        )
        
        XCTAssertTrue(TransactionAnalyzer.isInternalTransfer(transaction))
        XCTAssertFalse(TransactionAnalyzer.isActualIncome(transaction))
    }
    
    func testDividendIsIncome() {
        let transaction = mockTransaction(
            amount: -32,
            name: "DIVIDEND - VANGUARD TOTAL STOCK",
            category: ["DIVIDEND"]
        )
        
        XCTAssertTrue(TransactionAnalyzer.isActualIncome(transaction))
    }
    
    // MARK: - Expense Classification Tests
    
    func testInvestmentContributionNotCountedAsExpense() {
        let transactions = [
            mockTransaction(amount: -5000, name: "PAYROLL", category: ["INCOME"]),
            mockTransaction(amount: 1800, name: "RENT", category: ["RENT"]),
            mockTransaction(amount: 500, name: "401K CONTRIBUTION", category: ["TRANSFER_OUT_RETIREMENT"]),
        ]
        
        let accounts: [BankAccount] = []
        
        let snapshot = TransactionAnalyzer.generateSnapshot(
            transactions: transactions,
            accounts: accounts
        )
        
        // Expenses should NOT include the 401k contribution
        XCTAssertEqual(snapshot.monthlyEssentialExpenses, 1800, accuracy: 1)
    }
    
    // MARK: - Disposable Income Tests
    
    func testDisposableIncomeCalculation() {
        let transactions = [
            mockTransaction(amount: -5000, name: "PAYROLL", category: ["INCOME"]),
            mockTransaction(amount: 2000, name: "RENT", category: ["RENT"]),
            mockTransaction(amount: 400, name: "GROCERIES", category: ["GROCERIES"]),
        ]
        
        let accounts = [
            mockAccount(type: "credit", balance: 1000, minimumPayment: 25)
        ]
        
        let snapshot = TransactionAnalyzer.generateSnapshot(
            transactions: transactions,
            accounts: accounts
        )
        
        // Disposable = 5000 - 2000 - 400 - 25 = 2575
        XCTAssertEqual(snapshot.disposableIncome, 2575, accuracy: 1)
    }
    
    // MARK: - Helper Methods
    
    private func mockTransaction(
        amount: Double,
        name: String,
        category: [String]
    ) -> Transaction {
        Transaction(
            id: UUID().uuidString,
            accountId: "test-account",
            amount: amount,
            date: Date(),
            name: name,
            merchantName: nil,
            category: category,
            categoryId: nil,
            pending: false
        )
    }
    
    private func mockAccount(
        type: String,
        balance: Double,
        minimumPayment: Double? = nil
    ) -> BankAccount {
        BankAccount(
            id: UUID().uuidString,
            itemId: "test-item",
            name: "Test Account",
            type: type,
            subtype: nil,
            currentBalance: balance,
            availableBalance: balance,
            minimumPayment: minimumPayment,
            apr: nil
        )
    }
}
```

### Manual Testing Checklist

Test with the provided sample data (see Appendix):

- [ ] **Income Calculation:**
  - Expected: ~$6,033/month
  - Verify payroll is included
  - Verify 401k contributions are excluded
  - Verify IRA contributions are excluded
  - Verify savings transfers are excluded

- [ ] **Expense Calculation:**
  - Expected: ~$2,582/month (essentials only)
  - Verify rent is included ($1,800)
  - Verify utilities are included (~$230)
  - Verify subscriptions are included (~$37)
  - Verify investment contributions are EXCLUDED

- [ ] **Disposable Income:**
  - Expected: ~$3,401/month
  - Formula: Income - Essentials - Debt Minimums
  - NOT based on cash balance

- [ ] **Financial Position:**
  - Emergency cash: ~$14,300
  - Total debt: ~$1,850
  - Total invested: ~$81,250

---

## 6. Verification Checklist

### Code Quality Checks

- [ ] All files compile without errors
- [ ] No warnings related to the changes
- [ ] All unit tests pass
- [ ] No references to `availableToSpend` in entire codebase
- [ ] No references to `FinancialSummary` in entire codebase

### Functional Checks

Run these searches to verify cleanup is complete:

```bash
# Check for availableToSpend (should return 0 results)
grep -r "availableToSpend" --include="*.swift" FinancialAnalyzer/

# Check for FinancialSummary (should return 0 results)
grep -r "FinancialSummary" --include="*.swift" FinancialAnalyzer/

# Check for old calculateSummary method (should return 0 results)
grep -r "calculateSummary" --include="*.swift" FinancialAnalyzer/

# Check for Sources directory (should not exist)
ls Sources/
```

All commands should return: **0 results** or **No such file or directory**

### Verify New Files Exist

```bash
ls -la FinancialAnalyzer/Models/MonthlyFlow.swift
ls -la FinancialAnalyzer/Models/FinancialPosition.swift
ls -la FinancialAnalyzer/Models/FinancialSnapshot.swift
```

All files should exist.

### Data Accuracy Checks

With the test dataset:

| Metric | Old (Wrong) Value | New (Correct) Value |
|--------|-------------------|---------------------|
| Monthly Income | ~$8,775 | ~$6,033 |
| Monthly Expenses | ~$5,707 | ~$2,582 |
| "Available to Spend" | ~$17,803 | **REMOVED** |
| Disposable Income | (not calculated) | ~$3,401 |

---

## 7. Appendix: Test Data

### Test User Financial Profile

```json
{
  "accounts": [
    {
      "name": "Primary Checking",
      "type": "depository",
      "balance": 3200
    },
    {
      "name": "Bills Checking", 
      "type": "depository",
      "balance": 1850
    },
    {
      "name": "Discretionary Cash",
      "type": "depository",
      "balance": 450
    },
    {
      "name": "Emergency Buffer",
      "type": "depository",
      "balance": 2800
    },
    {
      "name": "Emergency Fund - HYSA",
      "type": "savings",
      "balance": 11500
    },
    {
      "name": "Short-Term Goals",
      "type": "savings",
      "balance": 3000
    },
    {
      "name": "401k Retirement",
      "type": "investment",
      "balance": 45800
    },
    {
      "name": "Roth IRA",
      "type": "investment",
      "balance": 21250
    },
    {
      "name": "Taxable Brokerage",
      "type": "investment",
      "balance": 14200
    },
    {
      "name": "Chase Sapphire Reserve",
      "type": "credit",
      "balance": 1850
    }
  ]
}
```

### Expected Correct Calculations

```
MONTHLY FLOW:
  Income:               $6,033  (payroll + interest + dividends)
  Essential Expenses:   $2,582  (rent + utilities + insurance + groceries)
  Debt Minimums:           $50  (credit card minimum)
  Disposable Income:    $3,401  (available to allocate)

FINANCIAL POSITION:
  Emergency Cash:      $14,300  (all depository accounts)
  Total Debt:           $1,850  (credit card)
  Total Invested:      $81,250  (401k + IRA + brokerage)
  Monthly Contributions: $2,100  (tracked separately)
```

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-21 | Initial creation |
| 2.0 | 2026-01-22 | Updated file paths to `FinancialAnalyzer/`, changed to Option B (delete FinancialSummary), added Task 1D for SPM cleanup |

---

**END OF IMPLEMENTATION PLAN**
