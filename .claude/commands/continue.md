---
description: Continue from last session with full context
---

Read CLAUDE.md for project context and PROGRESS.md for current state.

Work on the highest priority task in the "Next Up" section of PROGRESS.md.

**Steps to follow:**

1. **Before starting:**
   - Review the priority task details
   - Check related files mentioned in the task
   - Add today's date to "Completed This Session" section if not present

2. **During implementation:**
   - Follow patterns established in CLAUDE.md
   - Write code according to style standards
   - Add comprehensive error handling
   - If you discover new bugs, add them to "Known Issues" in PROGRESS.md
   - If blocked, move task to "Blocked/Waiting" with explanation

3. **Testing:**
   - Write tests for new functionality
   - Run the test suite: `npm test`
   - Verify manually in the running app
   - Test edge cases and error conditions

4. **When complete:**
   - Move the task from "Next Up" to "Completed This Session"
   - Add checkmark ✓ and brief description of what was implemented
   - Update "Current State" section to reflect new functionality
   - Note any test coverage improvements
   - Update "Last Updated" timestamp at top of file

5. **Before finishing your response:**
   - Summarize what you completed
   - Show the PROGRESS.md changes you made
   - Ask if I want you to continue to next priority

**Autonomous operation:**
- Make implementation decisions based on existing patterns
- Don't ask for permission on routine coding decisions
- Fix obvious bugs you encounter
- Add standard error handling without asking
- Follow the code style guide in CLAUDE.md

**Ask for guidance only on:**
- Major architectural changes
- New dependencies
- Security-sensitive code
- Database schema changes