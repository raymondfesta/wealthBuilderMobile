# Implement from Plan

Execute a detailed implementation plan document systematically.

## Document
$ARGUMENTS

## Instructions

You are executing a structured implementation plan. Follow this workflow:

### Phase 1: Analysis
1. **Read the implementation plan document** specified above
2. **Identify and list:**
   - All files that need to be created or modified (with their paths)
   - The dependency order (which files must be changed first)
   - Success criteria and verification steps
   - Any test data or expected outcomes
3. **Summarize the plan** in 2-3 sentences before starting

### Phase 2: Execution
For each task in the plan:

1. **Announce the task** you're starting (e.g., "Starting Task 2: Rewrite TransactionAnalyzer.swift")
2. **Check prerequisites** - verify any dependent files/changes are complete
3. **Implement the changes** exactly as specified in the plan
4. **Verify the change** compiles/works before moving on
5. **Report completion** with a brief summary of what was done

### Phase 3: Validation
After all tasks are complete:

1. **Run all verification commands** listed in the plan (grep searches, file checks, etc.)
2. **Run tests** if test code is provided or referenced
3. **Report any discrepancies** between expected and actual results
4. **Provide a final summary** with:
   - ✅ Completed tasks
   - ⚠️ Any issues encountered
   - 📝 Remaining manual steps (if any)

### Phase 4: Update Project Context Files
After validation passes, update the project's persistent context files:

#### Update PROGRESS.md 
- Mark completed tasks from this implementation plan as done
- Add any new tasks or follow-ups that emerged during implementation
- Update the "Current State" or "Last Session" section with:
  - What was accomplished
  - Any issues encountered and how they were resolved
  - Suggested next steps
- Move completed items to a "Recently Completed" section if one exists

#### Update CLAUDE.md 
- **Architecture section**: Add any new files, models, or services created
- **Patterns section**: Document any new patterns established (e.g., new helper functions, coding conventions)
- **Dependencies section**: Note any new dependencies or file relationships
- **Known issues**: Remove issues that were fixed; add any new ones discovered
- **Do NOT add**: Temporary implementation details, task-specific notes, or anything that won't be relevant to future sessions

If these files don't exist, suggest creating them with the relevant information from this implementation.

### Execution Rules
- **Follow the plan precisely** - don't improvise unless something is clearly wrong
- **Stop and ask** if the plan is ambiguous or conflicts with existing code
- **Preserve existing functionality** unless explicitly told to remove it
- **Commit logically** - suggest commit points after major milestones

### If No Document Path Provided
Ask the user: "Please provide the path to your implementation plan document, or paste the plan contents directly."