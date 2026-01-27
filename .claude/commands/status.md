---
description: Review and update PROGRESS.md
---

**Status review process:**

1. **Read current PROGRESS.md**

2. **Review each section:**
   - "Current State": Is this accurate?
   - "In Progress": Still being worked on?
   - "Next Up": Still the right priorities?
   - "Completed This Session": From today only or needs cleanup?
   - "Known Issues": Any resolved that should be removed?
   - "Blocked/Waiting": Still blocked or can proceed?

3. **Show me:**
   - What's in each section
   - Items that might need to be moved
   - Anything that looks outdated
   - Suggestions for reprioritization

4. **Ask for updates:**
   - "Should I add any new priorities?"
   - "Should I remove or reprioritize anything?"
   - "Any new issues to document?"
   - "Any blockers resolved?"

5. **Make requested updates:**
   - Move items between sections as directed
   - Add new items
   - Update priorities
   - Clean up completed items
   - Update "Last Updated" timestamp

**Response format:**
- Current status summary
- Suggested changes
- Questions for me
- Updated PROGRESS.md after I provide input
```

---

# Usage Examples

## Example 1: Starting Your Day

**You type:**
```
/continue
```

**Claude Code does:**
1. Reads CLAUDE.md (understands project context)
2. Reads PROGRESS.md (sees Priority 1: Fix profile photo upload crashes)
3. Implements the fix:
   - Adds file size validation
   - Adds automatic compression
   - Tests with various file sizes
   - Updates PROGRESS.md
4. Reports completion and asks if you want it to continue

**You type:**
```
Looks good. Continue to next priority.
```

**Claude Code does:**
1. Moves to Priority 2: Add password reset flow
2. Implements the feature
3. Updates PROGRESS.md
4. Continues...

## Example 2: Fixing a Bug

**You type:**
```
/fix The app crashes when uploading images over 5MB
```

**Claude Code does:**
1. Reads context files
2. Investigates the upload code
3. Finds missing file size validation
4. Implements fix with validation and compression
5. Writes test to verify fix
6. Updates PROGRESS.md
7. Reports what caused it and how it was fixed

## Example 3: Adding a Feature

**You type:**
```
/feature Add the ability for users to reset their password via email
```

**Claude Code does:**
1. Reads CLAUDE.md (sees you use SendGrid for emails, JWT for auth)
2. Implements:
   - Backend: Token generation, email sending, token validation, password update
   - Frontend: Request reset screen, enter new password screen
3. Writes comprehensive tests
4. Updates PROGRESS.md
5. Notes that this feature is now working

## Example 4: Mid-Session Check

**You type:**
```
/status
```

**Claude Code does:**
1. Reviews PROGRESS.md
2. Shows current state of each section
3. Identifies:
   - Priority 3 is blocked (waiting on Firebase)
   - Priority 4 can be moved up
   - Two items in "Completed This Session" from 3 days ago (should archive)
4. Asks: "Should I reprioritize and clean this up?"

**You respond:**
```
Yes, archive old completed items and move priority 4 to priority 3
```

**Claude Code:**
Updates PROGRESS.md accordingly

## Example 5: Code Review

**You type:**
```
/review Authentication module
```

**Claude Code does:**
1. Examines all auth-related code
2. Finds:
   - Critical: JWT secret hardcoded (should be in env)
   - Important: No rate limiting on login endpoint
   - Minor: Some functions could be simplified
3. Provides detailed recommendations
4. Adds critical and important issues to PROGRESS.md
5. Suggests priority order for fixes

## Example 6: Quick Session

**You type:**
```
/continue
```

**30 minutes later, you type:**
```
Good work so far but I need to stop for a meeting. Update PROGRESS.md with what you've completed and what's still in progress.