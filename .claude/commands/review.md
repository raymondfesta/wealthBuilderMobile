---
description: Review codebase and suggest improvements
---

Context: Read CLAUDE.md and PROGRESS.md

**What area should I review?**

Please specify the focus area (e.g., "authentication module", "mobile/src/screens", "API endpoints"), then I'll follow this process:

**Code review process:**

1. **Analysis:**
   - Examine code in the specified area
   - Check for:
     - Bugs or potential bugs
     - Performance issues
     - Security vulnerabilities
     - Code smells (duplication, complexity, etc)
     - Test coverage gaps
     - Accessibility issues (if UI code)
     - Error handling gaps

2. **Categorize findings:**
   - **Critical:** Security issues, data loss risks, crash bugs
   - **Important:** Performance problems, poor UX, missing tests
   - **Minor:** Code style, small refactors, optimizations

3. **Prioritize:**
   - Rank issues by impact on users
   - Consider effort to fix
   - Identify quick wins vs major refactors

4. **Provide recommendations:**
   - For each issue:
     - Explain what's wrong
     - Why it matters
     - Specific fix recommendation
     - Estimated effort
   - Include code examples for suggested fixes

5. **Update PROGRESS.md:**
   - Add high-priority issues to "Next Up"
   - Add medium-priority issues to "Technical Debt"
   - Add critical bugs to "Known Issues"
   - Update "Last Updated" timestamp

**Response format:**
- Summary of findings (count by category)
- Detailed list of issues with recommendations
- Suggested priority order for fixes
- PROGRESS.md updates made