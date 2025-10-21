-- AppleScript to add files to Xcode project
-- Run this with: osascript add_files_to_xcode.applescript

tell application "Xcode"
	activate

	-- Wait for Xcode to be ready
	delay 2

	display dialog "This will help you add the new files to your Xcode project.

Please follow these steps:

1. In the Project Navigator (left sidebar), locate these folders
2. Right-click each folder and select 'Add Files to FinancialAnalyzer...'

Files to add:
• Models: Budget.swift, Goal.swift
• Services: BudgetManager.swift, NotificationService.swift, AlertRulesEngine.swift, SpendingPatternAnalyzer.swift
• Views: ProactiveGuidanceDemoView.swift, ProactiveGuidanceView.swift

3. IMPORTANT: Uncheck 'Copy items if needed'
4. Click Add

Ready?" buttons {"Cancel", "I've Added Them"} default button "I've Added Them"

	if button returned of result is "I've Added Them" then
		display dialog "Great! Now:

1. Press Cmd+Shift+K to Clean Build Folder
2. Press Cmd+R to Build and Run

The Demo tab should now appear!" buttons {"OK"} default button "OK"
	end if
end tell
