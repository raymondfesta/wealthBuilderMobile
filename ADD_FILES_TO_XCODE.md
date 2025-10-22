# How to Add Files to Xcode Project

## The Issue

The following files exist on disk but are not part of the Xcode project, causing build errors:

```
FinancialAnalyzer/Models/AllocationBucket.swift
FinancialAnalyzer/Views/AllocationBucketCard.swift
FinancialAnalyzer/Views/AllocationPlannerView.swift
FinancialAnalyzer/Views/AllocationBucketDetailView.swift (NEW - Phase 4)
```

## Build Error You're Seeing

```
error: cannot find type 'AllocationBucket' in scope
```

This happens because Xcode doesn't know about these files even though they exist in the filesystem.

## Solution: Add Files to Xcode (Step-by-Step)

### Option 1: Drag and Drop (Easiest)

1. **Open Xcode** with your project
2. In the **Project Navigator** (left sidebar), locate the appropriate folder:
   - For `AllocationBucket.swift` → Navigate to **FinancialAnalyzer > Models**
   - For the three View files → Navigate to **FinancialAnalyzer > Views**
3. Open **Finder** and navigate to `/Users/rfesta/Desktop/wealth-app/FinancialAnalyzer/`
4. **Drag the files** from Finder into the appropriate Xcode folder
5. In the dialog that appears:
   - ☐ **UNCHECK** "Copy items if needed" (files are already in the right place)
   - ☑ **CHECK** "FinancialAnalyzer" under "Add to targets"
   - Click **Finish**

### Option 2: Add Files Menu

1. **Open Xcode** with your project
2. Right-click on **FinancialAnalyzer** folder in Project Navigator
3. Select **"Add Files to 'FinancialAnalyzer'..."**
4. Navigate to and select all four files:
   - `FinancialAnalyzer/Models/AllocationBucket.swift`
   - `FinancialAnalyzer/Views/AllocationBucketCard.swift`
   - `FinancialAnalyzer/Views/AllocationPlannerView.swift`
   - `FinancialAnalyzer/Views/AllocationBucketDetailView.swift`
5. In the dialog at the bottom:
   - ☐ **UNCHECK** "Copy items if needed"
   - ☑ **CHECK** "Create groups" (should be selected by default)
   - ☑ **CHECK** "FinancialAnalyzer" under "Add to targets"
6. Click **Add**

## Verification Steps

After adding files:

1. **Check Project Navigator**: Files should appear in their folders
2. **Build the project**: Press **Cmd+B**
3. **Look for errors**: The "cannot find type" errors should be gone
4. **Run in simulator**: Press **Cmd+R**

## Files to Add (Checklist)

- [ ] `FinancialAnalyzer/Models/AllocationBucket.swift`
- [ ] `FinancialAnalyzer/Views/AllocationBucketCard.swift`
- [ ] `FinancialAnalyzer/Views/AllocationPlannerView.swift`
- [ ] `FinancialAnalyzer/Views/AllocationBucketDetailView.swift` (NEW)

## Common Mistakes to Avoid

❌ **DON'T** check "Copy items if needed" - This creates duplicates
❌ **DON'T** forget to select the target - Files won't be compiled

✅ **DO** keep original file references
✅ **DO** select the FinancialAnalyzer target

## Quick Test

After adding files, run:

```bash
cd /Users/rfesta/Desktop/wealth-app
xcodebuild -scheme FinancialAnalyzer -sdk iphonesimulator clean build
```

Expected output: `** BUILD SUCCEEDED **`
