# TransactionAnalyzer Implementation Plan - TASK 1 (Updated)

**Project:** Capium iOS App  
**Objective:** Fix critical calculation errors in transaction analysis logic  
**Priority:** 🔴 CRITICAL - Pre-Launch Blocker  
**Document Version:** 2.0  
**Updated:** January 22, 2026

---

## Changes from Version 1.0

| Change | Old | New |
|--------|-----|-----|
| File paths | `Sources/FinancialAnalyzer/Models/` | `FinancialAnalyzer/Models/` |
| Task 1C | Refactor FinancialSummary as compatibility layer | **Delete** FinancialSummary entirely |
| New Task | — | Task 1D: Delete deprecated `Sources/` directory |
| Scope | Keep FinancialSummary | Full migration to FinancialSnapshot |

---

## Quick Reference: All TASK 1 File Changes

| Sub-Task | File Path | Action | Priority |
|----------|-----------|--------|----------|
| 1A.1 | `FinancialAnalyzer/Models/BankAccount.swift` | Refactor | High |
| 1A.2 | `FinancialAnalyzer/Models/BucketCategory.swift` | Refactor | High |
| 1A.3 | `FinancialAnalyzer/Models/Transaction.swift` | Refactor | High |
| 1B.1 | `FinancialAnalyzer/Models/MonthlyFlow.swift` | **Create** | High |
| 1B.2 | `FinancialAnalyzer/Models/FinancialPosition.swift` | **Create** | High |
| 1B.3 | `FinancialAnalyzer/Models/FinancialSnapshot.swift` | **Create** | High |
| 1C | `FinancialAnalyzer/Models/FinancialSummary.swift` | **Delete** | High |
| 1D.1 | `Sources/` directory | **Delete** | Medium |
| 1D.2 | `Package.swift` | **Delete** | Medium |

**Files NOT Changed:**
- `FinancialAnalyzer/Models/Budget.swift` - No changes needed
- `FinancialAnalyzer/Models/Goal.swift` - No changes needed

---

## TASK 1: Model Files (Refactor + Create + Delete)

**Priority:** High  
**Estimated Time:** 60 minutes  
**Location:** `FinancialAnalyzer/Models/`

This task is split into four sub-tasks:
- **1A:** Refactor existing model files
- **1B:** Create new model files  
- **1C:** Delete FinancialSummary (and identify consumers)
- **1D:** Delete deprecated SPM scaffolding

---

### TASK 1A: Refactor Existing Models

#### 1A.1 Refactor `BankAccount.swift`

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

**Note:** Plaid's liabilities API provides these fields for credit/loan accounts. The Plaid decoding path may need a separate update if the field names differ.

**Acceptance Criteria:**
- [ ] Properties `minimumPayment` and `apr` exist
- [ ] Init accepts new parameters with defaults
- [ ] Codable encoding/decoding includes new fields
- [ ] Compiles without errors

---

#### 1A.2 Refactor `BucketCategory.swift`

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

#### 1A.3 Refactor `Transaction.swift`

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

// UPDATE both convenience init(from decoder:) paths to decode categoryConfidence:
let categoryConfidence = try? container.decode(Double.self, forKey: .categoryConfidence)

// Pass to self.init():
self.init(
    // ... existing params ...
    categoryConfidence: categoryConfidence
)
```

**Note:** This change requires `TransactionAnalyzer.categorizeToBucket()` to accept a `transaction` parameter. This will be implemented in TASK 2. Until then, this will cause a compile error (expected).

**Acceptance Criteria:**
- [ ] Property `categoryConfidence` exists
- [ ] `bucketCategory` passes `self` to analyzer (compile error expected until TASK 2)
- [ ] Init accepts new parameter with default
- [ ] Both Codable paths handle new field

---

### TASK 1B: Create New Model Files

#### 1B.1 Create `MonthlyFlow.swift`

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

#### 1B.2 Create `FinancialPosition.swift`

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

#### 1B.3 Create `FinancialSnapshot.swift`

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
    
    /// Total essential expenses
    var monthlyEssentialExpenses: Double {
        monthlyFlow.totalEssentialExpenses
    }
    
    /// Monthly income
    var monthlyIncome: Double {
        monthlyFlow.income
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
- [ ] All convenience accessors match old FinancialSummary properties
- [ ] `isValidForAllocation` correctly validates snapshot
- [ ] `empty` static property provides safe default

---

### TASK 1C: Delete FinancialSummary

**File:** `FinancialAnalyzer/Models/FinancialSummary.swift`

**Action:** Delete this file entirely (Option B - Full Migration)

**Before Deleting - Identify Consumers:**

Run this command to find all files that reference `FinancialSummary`:

```bash
grep -r "FinancialSummary" --include="*.swift" FinancialAnalyzer/
```

**Expected Consumers to Update (in later tasks):**

| File | Type | Update Required |
|------|------|-----------------|
| `TransactionAnalyzer.swift` | Service | Change return type to `FinancialSnapshot` |
| `AlertRulesEngine.swift` | Service | Change parameter type to `FinancialSnapshot` |
| `SpendingPatternAnalyzer.swift` | Service | May reference summary properties |
| Various View files | Views | Update to use `FinancialSnapshot` |
| Various ViewModel files | ViewModels | Update stored properties |

**Steps:**

1. **DO NOT DELETE YET** - Wait until TASK 2 creates replacement functionality
2. Run grep command above and document all consumers
3. Delete file after all consumers are updated (end of TASK 6)

**Temporary Workaround (if needed for compilation):**

If you need the project to compile during migration, create a typealias temporarily:

```swift
// In FinancialSnapshot.swift, add at bottom:
typealias FinancialSummary = FinancialSnapshot
```

Then remove this typealias when all consumers are migrated.

**Acceptance Criteria:**
- [ ] All consumers of FinancialSummary identified
- [ ] File deleted after all consumers migrated
- [ ] No references to `FinancialSummary` remain in codebase
- [ ] No references to `availableToSpend` remain in codebase

---

### TASK 1D: Delete Deprecated SPM Scaffolding

**Action:** Delete the following deprecated files/directories:

| Path | Reason |
|------|--------|
| `Sources/` directory | Deprecated SPM scaffolding, not referenced by Xcode project |
| `Package.swift` | SPM manifest, not used |
| `Tests/` directory | If SPM-only tests, not used |

**Steps:**

```bash
# From project root:
rm -rf Sources/
rm -f Package.swift
rm -rf Tests/  # Only if this is SPM-only, verify first
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

## TASK 1 Execution Order

Execute sub-tasks in this order to minimize compile errors:

```
1. TASK 1D - Delete SPM scaffolding (cleans up confusion)
2. TASK 1B - Create new model files (no dependencies)
3. TASK 1A - Refactor existing models (may cause temporary compile errors)
4. TASK 1C - Delete FinancialSummary (WAIT until after TASK 2-6)
```

**Important:** After TASK 1A.3 (Transaction.swift), the project will have a compile error until TASK 2 updates `TransactionAnalyzer.categorizeToBucket()` to accept the new `transaction` parameter.

---

## TASK 1 Complete Checklist

### Files Created
- [ ] `FinancialAnalyzer/Models/MonthlyFlow.swift`
- [ ] `FinancialAnalyzer/Models/FinancialPosition.swift`
- [ ] `FinancialAnalyzer/Models/FinancialSnapshot.swift`

### Files Refactored
- [ ] `FinancialAnalyzer/Models/BankAccount.swift` - Added `minimumPayment`, `apr`
- [ ] `FinancialAnalyzer/Models/BucketCategory.swift` - Renamed "Available to Spend" → "Disposable Income"
- [ ] `FinancialAnalyzer/Models/Transaction.swift` - Added `categoryConfidence`, updated `bucketCategory`

### Files Deleted
- [ ] `Sources/` directory (deprecated)
- [ ] `Package.swift` (deprecated)
- [ ] `FinancialAnalyzer/Models/FinancialSummary.swift` (after all consumers migrated)

### Files Unchanged
- [ ] `FinancialAnalyzer/Models/Budget.swift` - Verified no changes needed
- [ ] `FinancialAnalyzer/Models/Goal.swift` - Verified no changes needed

### Verification Commands

```bash
# Verify no "Available to Spend" references
grep -r "Available to Spend" --include="*.swift" FinancialAnalyzer/
# Expected: 0 results

# Verify new files exist
ls -la FinancialAnalyzer/Models/MonthlyFlow.swift
ls -la FinancialAnalyzer/Models/FinancialPosition.swift
ls -la FinancialAnalyzer/Models/FinancialSnapshot.swift
# Expected: All files exist

# Verify Sources directory deleted
ls Sources/
# Expected: "No such file or directory"
```

---

## Next Steps

After completing TASK 1, proceed to:

- **TASK 2:** Rewrite `TransactionAnalyzer.swift` to use new models
- **TASK 3:** Update `SpendingPatternAnalyzer.swift`
- **TASK 4:** Update `BudgetManager.swift`
- **TASK 5:** Update `AlertRulesEngine.swift`
- **TASK 6:** Update all view consumers, then delete `FinancialSummary.swift`

---

**END OF TASK 1 UPDATED PLAN**
