---
description: Add or improve tests for existing code
---

Context: Read CLAUDE.md and PROGRESS.md

**What should I test?**

Please specify what code needs testing (e.g., "auth controller", "ProfileEdit component", "user API endpoints"), then I'll follow this process:

**Testing process:**

1. **Assess current state:**
   - Check existing tests for the target
   - Run tests: `npm test -- [target]`
   - Check coverage: `npm test -- --coverage [target]`
   - Identify gaps in test coverage

2. **Plan test cases:**
   - Happy path scenarios
   - Error conditions
   - Edge cases
   - Boundary conditions
   - Integration points with other code

3. **Write tests:**
   - Follow testing patterns from existing tests
   - Use descriptive test names (should read like documentation)
   - Test one thing per test case
   - Use appropriate assertions
   - Mock external dependencies
   - Include both positive and negative test cases

4. **Run and verify:**
   - Run new tests: `npm test`
   - Check that coverage improved
   - Verify tests actually fail when code is broken (mutation testing)
   - Run full suite to ensure no conflicts

5. **Update PROGRESS.md:**
   - Add to "Completed This Session":
     - What was tested
     - Coverage before and after
     - Number of test cases added
   - Update test coverage table if it exists
   - Update "Last Updated" timestamp

**Test quality standards:**
- Aim for 80% coverage minimum
- Cover happy path, error cases, and edge cases
- Use meaningful test descriptions
- Tests should be fast (<100ms each)
- Tests should be independent (no shared state)

**Response format:**
- Summary of test coverage improvements
- List of test cases added
- Coverage metrics before/after
- Any issues discovered during testing
