# Allocation Planner Testing Guide

This guide provides comprehensive test scenarios for the redesigned "Build Your Plan" allocation feature with sliders, preset values, account linking, and auto-adjustment feedback.

## Prerequisites

1. Backend running: `cd backend && npm run dev`
2. Connect bank accounts using Plaid Sandbox (user_custom recommended for rich data)
3. Complete "Analyze My Finances" to generate allocation recommendations
4. Navigate to "Build Your Plan" allocation screen

---

## Test Scenarios

### 1. Preset Selector (Discretionary/Investment/Debt Buckets)

**Feature**: Segmented control offering Low/Recommended/High preset values.

**Test Steps**:
1. Locate the Discretionary Spending bucket card
2. Verify you see a segmented control with "Low | Recommended | High"
3. Tap "Low" preset
   - ✅ Amount should update to low tier value
   - ✅ Other buckets should auto-rebalance
   - ✅ Toast notification should appear showing adjustments
   - ✅ Auto-adjusted buckets should show orange badge
4. Tap "High" preset
   - ✅ Amount should increase to high tier value
   - ✅ Rebalancing should occur again
5. Repeat for Investment bucket and Debt bucket (if present)

**Expected Behavior**:
- Preset values come from backend API (check console logs for "Preset Options:")
- Selecting a preset triggers rebalancing automatically
- Toast shows which buckets were adjusted and by how much
- Orange "AUTO-ADJUSTED" badge appears on affected buckets

**Edge Cases**:
- [ ] High preset + already high discretionary → Should cap at 50% max
- [ ] All buckets at minimum → High preset should fail gracefully

---

### 2. Emergency Fund Duration Picker

**Feature**: Interactive picker for 3/6/12 month emergency fund targets.

**Test Steps**:
1. Locate the Emergency Fund bucket card
2. Verify you see duration option cards: "3 MONTHS", "6 MONTHS", "12 MONTHS"
3. Check for "RECOMMENDED" badge on 6-month option (for stable income)
4. Tap "3 MONTHS" card
   - ✅ Card should highlight with blue border
   - ✅ Shortfall amount should update (if emergency fund < target)
   - ✅ Monthly contribution options (Low/Rec/High) should appear
   - ✅ "Time to Goal" should calculate correctly
5. Tap "12 MONTHS" card
   - ✅ Target amount should increase significantly
   - ✅ Shortfall should increase (unless already at goal)
   - ✅ Allocated amount should update to recommended tier
   - ✅ Other buckets should auto-rebalance
   - ✅ Toast notification should appear

**Expected Behavior**:
- Duration picker only appears for Emergency Fund bucket
- Recommended duration varies by income stability (6/9/12 months)
- Changing duration triggers rebalancing
- "GOAL MET" badge appears if current emergency fund ≥ target

**Edge Cases**:
- [ ] Current emergency fund > 12-month target → "GOAL MET" on all durations
- [ ] Monthly income too low → Verify shortfall calculation doesn't cause overflow

---

### 3. Investment Growth Projections

**Feature**: Comparison table showing 10/20/30 year growth projections.

**Test Steps**:
1. Locate the Investment bucket card
2. Scroll down to "Investment Growth Projection" section
3. Verify projection table shows:
   - ✅ 10/20/30 year columns
   - ✅ Monthly contribution amount
   - ✅ Total contributions over time
   - ✅ Investment growth (difference between total and contributions)
   - ✅ Final balance at each milestone
4. Change preset tier (Low → High)
   - ✅ Projection values should recalculate
   - ✅ Higher contribution → Higher final balance

**Expected Behavior**:
- Projections use 7% annual return assumption
- Selected tier row is highlighted
- ROI calculation shows growth vs contributions
- All currency values formatted correctly

**Edge Cases**:
- [ ] $0 monthly contribution → Projection shows $0 growth
- [ ] Very high contribution → Verify no number overflow

---

### 4. Account Linking with Auto-Detection

**Feature**: Link bank accounts to buckets with smart suggestions.

**Test Steps**:
1. Locate any bucket card and tap "Link Accounts" button
2. Account Linking Detail Sheet should appear
3. Verify "Suggested Accounts" section shows:
   - ✅ Auto-detected accounts with confidence badges (HIGH/GOOD/POSSIBLE)
   - ✅ Account name, type, and current balance
   - ✅ Reason for suggestion (e.g., "Savings account detected")
4. Tap a suggested account
   - ✅ Account should move to "Linked Accounts" section
   - ✅ Green checkmark should appear
   - ✅ "AUTO-LINKED" badge should show
5. Tap "Add Manually" to link an account without suggestion
   - ✅ Account should show "MANUALLY LINKED" badge
6. Tap linked account again to unlink
   - ✅ Account should return to available list
7. Close sheet
   - ✅ Bucket card should show linked account count
   - ✅ Current balance from linked accounts should display

**Expected Behavior**:
- Emergency Fund → Suggests savings/HYSA accounts (high confidence)
- Discretionary → Suggests checking accounts (medium confidence)
- Investments → Suggests brokerage/401k accounts (high confidence)
- Debt → Suggests credit card accounts (high confidence)
- Account links persist after app restart (UserDefaults)

**Edge Cases**:
- [ ] No accounts connected → "No accounts available" message
- [ ] All accounts already linked → "All accounts linked" message
- [ ] Link same account to multiple buckets → Should allow (balance counted once)

---

### 5. Auto-Adjustment Feedback (Toast + Badges)

**Feature**: Toast notification and persistent badges showing auto-rebalancing.

**Test Steps**:
1. Adjust Discretionary Spending slider
2. Verify toast notification appears:
   - ✅ Slides in from top
   - ✅ Shows "Auto-Adjusted" header with icon
   - ✅ Lists adjusted buckets with amounts (e.g., "Investments: -$150")
   - ✅ Auto-dismisses after 4 seconds
3. Check affected bucket cards:
   - ✅ Orange "AUTO-ADJUSTED" badge appears
   - ✅ Badge has "X" button to dismiss
4. Tap "X" on badge
   - ✅ Badge disappears
   - ✅ Does not reappear until next adjustment
5. Make another adjustment while toast is visible
   - ✅ Toast updates with new adjustments
   - ✅ Doesn't stack multiple toasts

**Expected Behavior**:
- Toast only appears when other buckets are auto-adjusted
- No toast if change is too small (< $0.01)
- Badge persists until user acknowledges (survives app restart)
- Toast shows up to 3-4 adjustments (truncates if more)

**Edge Cases**:
- [ ] Adjust essential spending (locked) → No toast (nothing to rebalance)
- [ ] Only one modifiable bucket exists → No rebalancing possible
- [ ] All other buckets at minimum → Rebalancing limited

---

### 6. Rebalancing Priority Logic (5 Buckets)

**Feature**: Smart rebalancing with priority order including debt bucket.

**Priority Order**: Discretionary → Investments → Debt Paydown → Emergency Fund

**Test Steps**:
1. Ensure debt bucket is visible (requires user to have debt)
2. Increase Emergency Fund allocation significantly
3. Check console logs for rebalancing order:
   ```
   ↳ Rebalancing 3 modifiable bucket(s):
      • Discretionary: $800 → $650 (-$150)
      • Investments: $500 → $450 (-$50)
      • Debt Paydown: $300 → $250 (-$50)
   ```
4. Verify rebalancing tries Discretionary first, then Investments, then Debt
5. Emergency Fund should be last resort (only adjusted if others at minimum)

**Expected Behavior**:
- Essential Spending never rebalanced (locked)
- Discretionary adjusted first (most flexible)
- Emergency Fund preserved as much as possible
- Rebalancing respects minimum percentages

**Edge Cases**:
- [ ] Discretionary at 0% → Skip to Investments
- [ ] All buckets at recommended minimum → Proportional distribution
- [ ] Reduce Emergency Fund → Extra money distributed by priority

---

### 7. Edge Case Warnings

**Feature**: Warning banners for budget health issues.

**Test Steps**:
1. Set Essential Spending to 85% of income (if possible)
   - ✅ Orange warning banner should appear: "High Essential Spending"
   - ✅ Message suggests reviewing essential categories
2. Set Discretionary to 3% of income
   - ✅ Blue info banner should appear: "Low Discretionary Spending"
   - ✅ Message reminds about quality of life
3. Set Emergency Fund to 2% of income
   - ✅ Red warning banner should appear: "Low Emergency Fund Allocation"
   - ✅ Message suggests increasing for financial security

**Expected Behavior**:
- Warnings appear above bucket cards
- Multiple warnings can stack
- Warnings update in real-time as allocations change
- Color-coded by severity (red > orange > blue)

**Edge Cases**:
- [ ] All thresholds triggered → All 3 banners visible
- [ ] Fix warning → Banner disappears immediately

---

### 8. Debt Paydown Bucket (Conditional Display)

**Feature**: 5th bucket appears only if user has debt.

**Test Steps**:
1. Check if debt bucket is visible
   - If present: User has debt from Plaid transactions
   - If absent: User has no debt
2. If debt bucket visible:
   - ✅ Shows "Debt Paydown" title with credit card icon
   - ✅ Has preset selector (Low/Rec/High)
   - ✅ Shows payoff timeline (extracted from AI explanation)
   - ✅ Shows interest saved estimate
   - ✅ Included in rebalancing priority (#3 in order)

**Expected Behavior**:
- Backend conditionally creates bucket based on `totalDebt > 0`
- Bucket appears between Investments and Emergency Fund
- Priority is Discretionary → Investments → **Debt** → Emergency Fund
- Validation bar shows 5 dots instead of 4

**Edge Cases**:
- [ ] Pay off all debt → Backend should remove bucket on next refresh
- [ ] Acquire debt → Backend should add bucket

---

### 9. Persistence (UserDefaults Storage)

**Feature**: Allocation preferences saved and restored.

**Test Steps**:
1. Link an account to Emergency Fund
2. Change Discretionary preset to "Low"
3. Set Emergency Fund duration to 12 months
4. Kill app completely (swipe up from app switcher)
5. Relaunch app
6. Navigate back to "Build Your Plan"
   - ✅ Account link should be restored
   - ✅ Discretionary should still show "Low" selected
   - ✅ Emergency Fund should show 12-month option selected

**Expected Behavior**:
- All preferences persist across app restarts
- Stored in UserDefaults with encryption
- Cleared when "Clear All Data" is used
- Survives backend restart (iOS-only storage)

**Edge Cases**:
- [ ] Clear backend tokens → iOS preferences should persist
- [ ] Reset app data → All preferences cleared

---

### 10. Validation Bar (5 Buckets)

**Feature**: Visual indicator of allocation completeness.

**Test Steps**:
1. Observe validation bar at bottom of screen
2. Verify it shows:
   - ✅ Colored dots for each bucket (4 or 5 depending on debt)
   - ✅ Total allocated amount
   - ✅ Target income amount
   - ✅ Percentage (should be ~100%)
   - ✅ Checkmark icon (green) when valid, exclamation (orange) when invalid
3. Under-allocate (e.g., 95%)
   - ✅ Orange exclamation icon
   - ✅ Percentage shows 95%
4. Over-allocate (e.g., 105%)
   - ✅ Orange exclamation icon
   - ✅ Percentage shows 105%
5. Exactly 100%
   - ✅ Green checkmark icon
   - ✅ "Create My Financial Plan" button enabled

**Expected Behavior**:
- Updates in real-time as buckets change
- Animates smoothly (spring animation)
- Dots fade if bucket amount is $0
- Valid when within 0.1% of 100%

**Edge Cases**:
- [ ] Floating point errors → Automatic rounding to 100% on save
- [ ] Negative bucket value → Shows as invalid immediately

---

## Automated Testing Checklist

### Unit Tests (Recommended)
- [ ] `AccountLinkingService.suggestAccountsForBucket()` - confidence scores
- [ ] `AllocationEditorViewModel.updateBucket()` - returns adjustments
- [ ] `AllocationEditorViewModel.detectHighEssentialSpending()` - threshold detection
- [ ] `AllocationPlanStorage.saveAccountLinks()` - persistence
- [ ] `AllocationBucket.linkAccount()` - auto-persistence

### Integration Tests
- [ ] Full allocation flow: Analyze → Generate → Edit → Save
- [ ] Account linking flow: Link → Save → Restart → Verify
- [ ] Preset selection flow: Select → Rebalance → Toast → Badge

### Accessibility Tests
- [ ] VoiceOver can navigate all controls
- [ ] Segmented control announces tier selection
- [ ] Duration picker announces months
- [ ] Toast notification is announced
- [ ] Badges have accessibility labels

---

## Console Log Checklist

When testing, verify these console logs appear:

### Allocation Editor
```
💰 [AllocationEditor] Initialized with 4 buckets, total: $5000
💰 [AllocationEditor] 'Discretionary' changed: $800 → $600 (Δ-$200)
   ↳ Rebalancing 2 modifiable bucket(s):
      • Investments: $500 → $600 (+$100)
      • Emergency Fund: $500 → $600 (+$100)
   ✅ Total allocation: $5000 (100%)
   📊 Recorded 2 auto-adjustment(s)
```

### Account Linking
```
🔗 [AccountLinking] Analyzing 8 account(s) for bucket: emergencyFund
🔗 [AccountLinking] Generated 3 suggestion(s):
   - Chase Savings HYSA (HIGH confidence)
   - Ally HYSA (HIGH confidence)
   - Vanguard Money Market (GOOD confidence)
```

### Persistence
```
💾 [Storage] Saved 2 account link(s) for emergencyFund
💾 [Storage] Saved preset tier 'low' for discretionarySpending
💾 [Storage] Saved emergency fund duration: 12 months
📦 [AllocationBucket] Loaded 2 account link(s) for emergencyFund
```

### Reset
```
🗑️ [Reset] ===== STARTING COMPLETE DATA WIPE =====
🗑️ [Storage] Cleared all allocation plan data
✅ [Reset] ===== DATA WIPE COMPLETE =====
```

---

## Known Issues / Limitations

1. **Account balance not updating in real-time**: Requires manual refresh from Plaid
2. **Investment projections use fixed 7% return**: Not adjustable by user
3. **Preset values are static**: Backend returns fixed tiers, no dynamic adjustment
4. **Toast notification doesn't queue**: Multiple rapid changes may show only last adjustment
5. **Debt bucket disappears if debt = 0**: Expected behavior, but may surprise users

---

## Success Criteria

All features should work seamlessly:
- ✅ Preset selectors update allocation and trigger rebalancing
- ✅ Emergency duration picker updates target and monthly contribution
- ✅ Account linking persists and shows correct balances
- ✅ Auto-adjustment feedback (toast + badges) appears reliably
- ✅ Rebalancing follows correct priority order
- ✅ Edge case warnings appear at appropriate thresholds
- ✅ All data persists across app restarts
- ✅ Validation bar accurately reflects allocation status
- ✅ "Create My Financial Plan" saves successfully

---

## Testing Completion

After completing all test scenarios:

1. **Manual Test Pass**: [ ] Date: ___________
2. **Edge Cases Verified**: [ ] Date: ___________
3. **Persistence Confirmed**: [ ] Date: ___________
4. **Accessibility Pass**: [ ] Date: ___________
5. **Ready for Demo**: [ ] Date: ___________

**Notes**:
_Use this space to document any issues found during testing_

---

## Next Steps After Testing

1. Fix any bugs discovered during testing
2. Add unit tests for critical paths
3. Create user-facing documentation
4. Record demo video of full flow
5. Submit for code review
