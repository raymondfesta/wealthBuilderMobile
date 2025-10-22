# Allocation Buckets - Quick Reference Guide

## For Developers Working on Phase 3+

### What Are Allocation Buckets?

Allocation buckets divide monthly income into 4 financial priorities:
1. **Essential Spending** (51%) - Rent, groceries, utilities, transportation
2. **Emergency Fund** (20%) - Safety net savings
3. **Discretionary Spending** (19%) - Entertainment, dining, shopping
4. **Investments** (10%) - Long-term wealth building

Percentages are AI-recommended based on user's financial data.

---

## Quick Start

### 1. Generate Allocations (BudgetManager)

```swift
let budgetManager = BudgetManager()

try await budgetManager.generateAllocationBuckets(
    monthlyIncome: 5000,
    monthlyExpenses: 3200,
    currentSavings: 12000,
    totalDebt: 5000,
    categoryBreakdown: [
        "Groceries": 450,
        "Rent": 1500,
        "Utilities": 150,
        "Entertainment": 200,
        "Dining": 300
    ],
    transactions: allTransactions,
    accounts: allAccounts
)

// Result: budgetManager.allocationBuckets contains 4 AllocationBucket objects
```

### 2. Display in SwiftUI

```swift
struct AllocationView: View {
    @StateObject var budgetManager: BudgetManager

    var body: some View {
        ForEach(budgetManager.allocationBuckets) { bucket in
            HStack {
                Image(systemName: bucket.icon)
                    .foregroundColor(Color(hex: bucket.color))

                VStack(alignment: .leading) {
                    Text(bucket.displayName)
                        .font(.headline)
                    Text("$\(bucket.allocatedAmount, specifier: "%.2f")")
                        .font(.title2)
                    Text("\(bucket.percentageOfIncome, specifier: "%.0f")% of income")
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
```

### 3. Check User Journey State

```swift
enum UserJourneyState {
    case noAccountsConnected
    case accountsConnected
    case analysisComplete
    case allocationPlanning  // NEW - Show allocation UI here
    case planCreated
}

// In your ViewModel
func showAllocationPlan() {
    userState = .allocationPlanning
    // Trigger UI to display AllocationPlanView
}
```

---

## Model Reference

### AllocationBucket

```swift
@MainActor
final class AllocationBucket: Identifiable, ObservableObject {
    @Published var id: String
    @Published var type: AllocationBucketType
    @Published var allocatedAmount: Double
    @Published var percentageOfIncome: Double
    @Published var linkedBudgetCategories: [String]
    @Published var explanation: String  // AI-generated
    @Published var targetAmount: Double?  // Emergency fund only
    @Published var monthsToTarget: Int?   // Emergency fund only

    var displayName: String { type.displayName }
    var icon: String { type.icon }
    var color: String { type.color }
}
```

### AllocationBucketType

```swift
enum AllocationBucketType: String, Codable {
    case essentialSpending
    case emergencyFund
    case discretionarySpending
    case investments

    var icon: String {
        // Returns SF Symbol name like "house.fill"
    }

    var color: String {
        // Returns hex color like "#007AFF"
    }

    var defaultCategoryMappings: [String] {
        // Returns categories for this bucket type
    }
}
```

---

## Common Use Cases

### Use Case 1: Show Allocation Summary

```swift
func displaySummary() {
    let total = budgetManager.allocationBuckets
        .reduce(0) { $0 + $1.allocatedAmount }

    print("Total allocated: $\(total)")

    for bucket in budgetManager.allocationBuckets {
        print("\(bucket.displayName): $\(bucket.allocatedAmount) (\(bucket.percentageOfIncome)%)")
    }
}
```

### Use Case 2: Find Emergency Fund

```swift
func getEmergencyFund() -> AllocationBucket? {
    return budgetManager.allocationBuckets.first {
        $0.type == .emergencyFund
    }
}

if let emergency = getEmergencyFund() {
    print("Emergency fund target: $\(emergency.targetAmount ?? 0)")
    print("Months to reach target: \(emergency.monthsToTarget ?? 0)")
}
```

### Use Case 3: Get Linked Categories

```swift
func categoriesForBucket(_ bucketType: AllocationBucketType) -> [String] {
    guard let bucket = budgetManager.allocationBuckets.first(where: { $0.type == bucketType }) else {
        return []
    }
    return bucket.linkedBudgetCategories
}

// Example
let essentialCategories = categoriesForBucket(.essentialSpending)
// Returns: ["Groceries", "Rent", "Utilities", "Transportation"]
```

### Use Case 4: Update Allocation

```swift
func adjustAllocation(bucket: AllocationBucket, newAmount: Double, newPercentage: Double) {
    bucket.updateAllocation(amount: newAmount, percentage: newPercentage)
    budgetManager.saveContext()  // Triggers cache save
}
```

---

## API Integration

### Endpoint Details

**URL**: `http://localhost:3000/api/ai/allocation-recommendation`
**Method**: POST
**Timeout**: 60 seconds

### Request Example

```bash
curl -X POST http://localhost:3000/api/ai/allocation-recommendation \
  -H "Content-Type: application/json" \
  -d '{
    "monthlyIncome": 5000,
    "monthlyExpenses": 3000,
    "currentSavings": 10000,
    "totalDebt": 2000,
    "categoryBreakdown": {
      "Groceries": 400,
      "Rent": 1500
    }
  }'
```

### Response Structure

```json
{
  "allocations": {
    "essentialSpending": {
      "amount": 2550,
      "percentage": 51,
      "categories": ["Groceries", "Rent"],
      "explanation": "Covers your core living expenses..."
    },
    "emergencyFund": {
      "amount": 1000,
      "percentage": 20,
      "targetAmount": 19200,
      "monthsToTarget": 10,
      "explanation": "Build safety net..."
    },
    "discretionarySpending": {
      "amount": 950,
      "percentage": 19,
      "categories": ["Entertainment"],
      "explanation": "Enjoy life while staying on track..."
    },
    "investments": {
      "amount": 500,
      "percentage": 10,
      "explanation": "Start building wealth..."
    }
  },
  "summary": {
    "totalAllocated": 5000,
    "basedOn": "Analysis of spending patterns..."
  }
}
```

---

## Cache Behavior

### Automatic Caching

Allocations are automatically cached to UserDefaults:

```swift
// Save (automatic)
budgetManager.allocationBuckets = newBuckets
// → Triggers saveAllocationBucketsToCache()

// Load (automatic on init)
let manager = BudgetManager()
// → Calls loadAllocationBucketsFromCache() in init()
```

### Manual Cache Operations

```swift
// Force refresh from API
try await budgetManager.generateAllocationBuckets(...)

// Check if cached data exists
let hasCachedData = !budgetManager.allocationBuckets.isEmpty

// Clear cache
UserDefaults.standard.removeObject(forKey: "cached_allocation_buckets")
budgetManager.allocationBuckets = []
```

---

## Error Handling

### Common Errors

```swift
do {
    try await budgetManager.generateAllocationBuckets(...)
} catch BudgetError.invalidAllocationRequest {
    print("Invalid input parameters")
} catch BudgetError.networkError {
    print("Network connection failed")
} catch BudgetError.allocationGenerationFailed {
    print("Backend API returned error")
} catch {
    print("Unexpected error: \(error)")
}
```

### Error Types

| Error | Cause | Solution |
|-------|-------|----------|
| `invalidAllocationRequest` | Bad input params | Validate data before calling |
| `networkError` | Network failure | Check internet connection |
| `allocationGenerationFailed` | Backend API error | Check backend logs |

---

## UI Color Helpers

### SwiftUI Color Extension

```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255
        g = Double((int >> 8) & 0xFF) / 255
        b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// Usage
let bucketColor = Color(hex: bucket.color)
```

---

## Logging & Debugging

### Enable Detailed Logs

All BudgetManager allocation operations log with `💰 [BudgetManager]` prefix:

```
💰 [BudgetManager] Generating allocation buckets...
💰 [BudgetManager] Input: income=$5000, expenses=$3000, savings=$10000, debt=$2000
💰 [BudgetManager] Calling http://localhost:3000/api/ai/allocation-recommendation...
💰 [BudgetManager] Response status: 200
💰 [BudgetManager] Successfully received allocation recommendations
💰 [BudgetManager] Created Essential Spending bucket: $2550 (51%)
💰 [BudgetManager] Created Emergency Fund bucket: $1000 (20%), target=$19200
💰 [BudgetManager] Created Discretionary Spending bucket: $950 (19%)
💰 [BudgetManager] Created Investments bucket: $500 (10%)
💰 [BudgetManager] Saved 4 allocation buckets to cache
💰 [BudgetManager] Successfully generated 4 allocation buckets
```

### Debug Allocations

```swift
func debugAllocations() {
    print("=== Allocation Buckets Debug ===")
    for bucket in budgetManager.allocationBuckets {
        print("\(bucket.type.rawValue):")
        print("  Amount: $\(bucket.allocatedAmount)")
        print("  Percentage: \(bucket.percentageOfIncome)%")
        print("  Categories: \(bucket.linkedBudgetCategories.joined(separator: ", "))")
        if let target = bucket.targetAmount {
            print("  Target: $\(target)")
        }
        print("")
    }
}
```

---

## Testing Tips

### Mock BudgetManager

```swift
class MockBudgetManager: BudgetManager {
    override func generateAllocationBuckets(...) async throws {
        // Create test allocations
        let testBuckets = [
            AllocationBucket(
                type: .essentialSpending,
                allocatedAmount: 2500,
                percentageOfIncome: 50,
                linkedCategories: ["Groceries", "Rent"],
                explanation: "Test explanation"
            )
        ]
        self.allocationBuckets = testBuckets
    }
}
```

### Test Data

```swift
let testAllocations = [
    AllocationBucket(
        type: .essentialSpending,
        allocatedAmount: 2550,
        percentageOfIncome: 51,
        linkedCategories: ["Groceries", "Rent", "Utilities"],
        explanation: "Core living expenses"
    ),
    AllocationBucket(
        type: .emergencyFund,
        allocatedAmount: 1000,
        percentageOfIncome: 20,
        linkedCategories: [],
        explanation: "Safety net",
        targetAmount: 19200,
        monthsToTarget: 10
    )
]
```

---

## Best Practices

### ✅ DO

- Call `generateAllocationBuckets()` after analyzing transactions
- Cache allocations for offline access
- Show AI explanations to users
- Handle loading states (isProcessing)
- Respect the 60-second timeout
- Use cache-first approach for instant UI

### ❌ DON'T

- Call API on every screen load (use cache)
- Modify allocation amounts without calling `updateAllocation()`
- Ignore error handling
- Store access tokens in allocations (use Keychain)
- Hardcode allocation percentages
- Skip displaying AI explanations

---

## Migration Notes

If updating from earlier versions:

1. **No breaking changes** - New feature only
2. **Existing budgets unaffected** - Allocations are separate
3. **Cache key added**: `cached_allocation_buckets`
4. **New state added**: `UserJourneyState.allocationPlanning`
5. **BudgetManager init changed**: Now accepts `baseURL` parameter (defaults to localhost)

---

## Performance Tips

### Lazy Loading

```swift
// Load allocations in background
Task {
    if budgetManager.allocationBuckets.isEmpty {
        try? await budgetManager.generateAllocationBuckets(...)
    }
}
```

### Batch Updates

```swift
// Update multiple allocations efficiently
budgetManager.allocationBuckets = modifiedBuckets
// Single cache write instead of multiple
```

### Memory Management

```swift
// AllocationBucket is a class - be careful with references
@StateObject var bucket: AllocationBucket  // ✅ Good
@State var bucket: AllocationBucket        // ❌ Avoid
```

---

## Support & Documentation

- **Full Implementation Guide**: See `PHASE_2_ALLOCATION_IMPLEMENTATION.md`
- **Architecture Overview**: See `CLAUDE.md`
- **API Documentation**: See backend `/api/ai/allocation-recommendation` endpoint
- **Testing Guide**: See `PHASE_2_CHECKLIST.md`

---

## Phase 3 Preview

Coming soon in Phase 3:
- AllocationPlanView SwiftUI interface
- Interactive percentage adjustment
- Visual bucket representations
- Budget creation from allocations
- Emergency fund goal creation
- Category customization UI

---

**Last Updated**: October 21, 2025
**Version**: Phase 2 Complete
**Status**: Production-Ready
