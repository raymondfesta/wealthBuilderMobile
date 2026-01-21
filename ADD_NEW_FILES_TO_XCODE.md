# Quick Guide: Add New Files to Xcode Project

## Files to Add (11 total: 4 from Phase 1-3 + 5 from Phase 4 + 1 from Phase 5 + 1 from Phase 9)

### Step 1: Add to Models Group (3 files)

1. Open Xcode project: `FinancialAnalyzer.xcodeproj`
2. In left sidebar, **right-click "Models" folder**
3. Select **"Add Files to FinancialAnalyzer..."**
4. Navigate to `/Users/rfesta/Desktop/wealth-app/FinancialAnalyzer/Models/`
5. Select these 3 files (Cmd+Click to select multiple):
   - `PresetOptions.swift`
   - `EmergencyFundDurationOption.swift`
   - `InvestmentProjection.swift`
6. **UNCHECK** "Copy items if needed" (files already in correct location)
7. Click **"Add"**

---

### Step 2: Add to Services Group (2 files)

1. In left sidebar, **right-click "Services" folder**
2. Select **"Add Files to FinancialAnalyzer..."**
3. Navigate to `/Users/rfesta/Desktop/wealth-app/FinancialAnalyzer/Services/`
4. Select these 2 files (Cmd+Click to select multiple):
   - `AccountLinkingService.swift`
   - `AllocationPlanStorage.swift`
5. **UNCHECK** "Copy items if needed"
6. Click **"Add"**

---

### Step 3: Add to Views/Components Group (6 files)

1. In left sidebar, **right-click "Views" folder**
2. If "Components" subfolder doesn't exist:
   - Select **"New Group"**
   - Name it **"Components"**
3. **Right-click "Components" folder** (or create it first)
4. Select **"Add Files to FinancialAnalyzer..."**
5. Navigate to `/Users/rfesta/Desktop/wealth-app/FinancialAnalyzer/Views/Components/`
6. Select these 6 files (Cmd+Click to select multiple):
   - `AllocationPresetSelector.swift`
   - `EmergencyFundDurationPicker.swift`
   - `InvestmentProjectionView.swift`
   - `AccountLinkingDetailSheet.swift`
   - `DebtPaydownCard.swift`
   - `RebalanceToast.swift`
7. **UNCHECK** "Copy items if needed"
8. Click **"Add"**

---

### Step 4: Clean & Build

1. **Clean Build Folder:**
   - Menu: `Product` → `Clean Build Folder`
   - Or: `Shift + Cmd + K`

2. **Build Project:**
   - Menu: `Product` → `Build`
   - Or: `Cmd + B`

3. **Verify Success:**
   - Build should succeed with no errors
   - You may see warnings about MainActor (safe to ignore for now)

---

## What Each File Does

### Phase 1-3: Data Models and Services

**PresetOptions.swift**
- Defines Low/Recommended/High preset values for allocation buckets
- Used by backend response to provide slider options

**EmergencyFundDurationOption.swift**
- 3/6/12 month duration options for emergency fund
- Includes shortfall calculation and monthly contribution presets

**InvestmentProjection.swift**
- 10/20/30 year growth projections using compound interest
- Shows potential future value based on monthly contributions

**AccountLinkingService.swift**
- Auto-links bank accounts to allocation buckets
- Smart detection based on account names and types
- Calculates bucket balances from linked accounts

**AllocationPlanStorage.swift** (Phase 9)
- Persists allocation plan preferences to UserDefaults
- Saves account links, preset selections, emergency duration
- Auto-saves when user makes changes

### Phase 4: UI Components

**AllocationPresetSelector.swift**
- Segmented control UI for Low/Recommended/High preset selection
- Shows selected amount and percentage
- Used for discretionary and investment buckets

**EmergencyFundDurationPicker.swift**
- Interactive picker for 3/6/12 month emergency fund targets
- Displays shortfall, monthly contribution options, and time to goal
- Shows "Goal Met" badge when target is reached

**InvestmentProjectionView.swift**
- Comparison table showing 10/20/30 year growth projections
- Highlights selected tier (Low/Rec/High)
- Shows ROI and total gain calculations

**AccountLinkingDetailSheet.swift**
- Modal sheet for managing account-to-bucket links
- Shows suggested accounts with confidence badges (HIGH/GOOD/POSSIBLE)
- Displays auto-linked vs manually-linked accounts

**DebtPaydownCard.swift**
- Specialized bucket card for debt paydown
- Shows payoff timeline and interest saved
- Preset selector for payment levels

### Phase 5: Auto-Adjustment Feedback

**RebalanceToast.swift**
- Toast notification showing auto-rebalancing feedback
- Displays which buckets were adjusted and by how much
- Auto-dismisses after 4 seconds with slide-in/out animation
- Includes view modifier for easy integration

---

## Troubleshooting

**Files appear in red?**
- File path is incorrect
- Remove file, re-add with correct path

**"Duplicate symbol" error?**
- File was added twice
- Check Build Phases → Compile Sources
- Remove duplicate

**Still can't find type?**
- Verify file is in Compile Sources build phase
- Clean build folder and rebuild

---

## After Build Succeeds

The iOS app will compile successfully and be ready for:
- Phase 4: UI Components (preset selectors, duration picker)
- Phase 5: Auto-adjustment feedback
- Remaining phases...

---

## Current Project Structure

```
FinancialAnalyzer/
├── Models/
│   ├── AllocationBucket.swift (UPDATED)
│   ├── BankAccount.swift
│   ├── Budget.swift
│   ├── Goal.swift
│   ├── Transaction.swift
│   ├── FinancialHealthMetrics.swift
│   ├── PresetOptions.swift ← NEW (Phase 1-3)
│   ├── EmergencyFundDurationOption.swift ← NEW (Phase 1-3)
│   └── InvestmentProjection.swift ← NEW (Phase 1-3)
├── Services/
│   ├── PlaidService.swift
│   ├── BudgetManager.swift (UPDATED)
│   ├── NotificationService.swift
│   ├── FinancialHealthCalculator.swift
│   ├── AccountLinkingService.swift ← NEW (Phase 1-3)
│   └── AllocationPlanStorage.swift ← NEW (Phase 9)
├── Views/
│   ├── AllocationBucketCard.swift (UPDATED)
│   ├── AllocationPlannerView.swift
│   ├── DashboardView.swift
│   └── Components/
│       ├── AllocationPresetSelector.swift ← NEW (Phase 4)
│       ├── EmergencyFundDurationPicker.swift ← NEW (Phase 4)
│       ├── InvestmentProjectionView.swift ← NEW (Phase 4)
│       ├── AccountLinkingDetailSheet.swift ← NEW (Phase 4)
│       ├── DebtPaydownCard.swift ← NEW (Phase 4)
│       └── RebalanceToast.swift ← NEW (Phase 5)
...
```
