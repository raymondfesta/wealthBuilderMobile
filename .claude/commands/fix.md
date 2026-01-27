---
description: Debug and fix a specific issue
---

First, read CLAUDE.md and PROGRESS.md to understand the project context and current state.

**What issue should I fix?** $ARGUMENTS

After reading the context files, follow this process:

1. **Investigate:** Reproduce the issue, check "Known Issues" in PROGRESS.md, review related code and recent git history

2. **Diagnose:** Add logging if needed, check for common issues (null checks, async timing, type mismatches), explain your hypothesis

3. **Fix:** Make minimal changes following existing patterns, add error handling if missing

4. **Test:** Write a test that fails before the fix and passes after, run the full test suite, test manually

5. **Update PROGRESS.md** with:
   - What the issue was, what caused it, and how you fixed it under "Completed This Session"
   - Remove from "Known Issues" if it was listed
   - Update "Current State" if the fix changes it
   - Update the "Last Updated" timestamp

Do not consider this task complete until PROGRESS.md has been updated.