---
description: Implement a new feature
---

Context: Read CLAUDE.md and PROGRESS.md

**What feature should I implement?**

Please describe the feature you want me to build, then I'll follow this process:

**Feature implementation process:**

1. **Planning:**
   - Review existing patterns in codebase for similar features
   - Identify files that need to be created or modified
   - Consider edge cases and error conditions
   - Check if this conflicts with anything in "In Progress" or "Known Issues"

2. **Implementation:**
   - Follow architecture patterns from CLAUDE.md
   - Create necessary files in appropriate directories
   - Implement core functionality
   - Add proper TypeScript types
   - Include error handling for failure cases
   - Add loading states for async operations
   - Make UI user-friendly with clear feedback

3. **Testing:**
   - Write unit tests for business logic
   - Write integration tests if it involves API calls
   - Write component tests for UI parts
   - Aim for 80% coverage of new code
   - Run test suite: `npm test`
   - Test manually in the app:
     - Happy path
     - Error conditions
     - Edge cases
     - Different screen sizes (if mobile UI)

4. **Code quality:**
   - Follow code style from CLAUDE.md
   - No `any` types in TypeScript
   - Proper error messages (user-friendly, not technical)
   - Code comments for complex logic
   - Consistent naming conventions

5. **Update PROGRESS.md:**
   - Add to "Completed This Session" with:
     - Feature description
     - Files created/modified
     - Test coverage added
   - Update "Current State" to reflect new capability
   - If there's follow-up work needed, add to "Next Up"
   - If you discovered issues, add to "Known Issues"
   - Update "Last Updated" timestamp

6. **Documentation:**
   - Update API documentation if backend changes
   - Add code comments for complex parts
   - Note any new environment variables needed

**Response format:**
- Explain implementation approach
- Show key code snippets
- Report test results
- Summarize what was added
- Note any follow-up work needed