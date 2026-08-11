---
name: options-fix
version: 1.0.0
trigger: --fix
description: Fixes bugs from foundbugs.md one at a time. Starts with CRITICAL, then HIGH, MEDIUM, LOW. Asks before continuing to the next severity tier.
chained_from: --bug
---

# --fix: Bug Fixer

Read `foundbugs.md` in the current directory. Fix bugs one at a time. Start with CRITICAL, then ask before moving to HIGH, then MEDIUM, then LOW.

## Phase 1: Read foundbugs.md

Parse the bug report. Count bugs per severity tier. Determine the order.

## Phase 2: Fix CRITICAL Bugs (One at a Time)

For each CRITICAL bug:

1. **Open the file** at the specified line
2. **Show the bug** — paste the relevant code with the problematic line highlighted
3. **Apply the fix** — edit the file with the fix from the report
4. **Confirm** — show the diff, state what changed
5. **Move to next** — if more CRITICAL bugs remain, fix the next one

After ALL CRITICAL bugs are fixed, output:

```
CRITICAL bugs fixed: [n]/[n] done.

Next: [h] HIGH bugs remaining. Continue?
```

Wait for user confirmation before moving to HIGH.

## Phase 3: Fix HIGH Bugs

Same process as CRITICAL. One at a time. Show bug, apply fix, confirm diff.

After all HIGH bugs:

```
HIGH bugs fixed: [n]/[n] done.

Next: [m] MEDIUM bugs remaining. Continue?
```

## Phase 4: Fix MEDIUM Bugs

Same process.

## Phase 5: Fix LOW Bugs

Same process.

## Phase 6: Update foundbugs.md

After each tier is fixed, update `foundbugs.md` to mark bugs as `[FIXED]`. Rewrite the summary table with remaining counts.

```
### [BUG-001] [Title] [FIXED]
```

## Rules

1. Fix ONLY the bug in focus — do not touch unrelated code
2. Preserve code style — match indentation, naming, conventions of the surrounding code
3. After each fix, verify the fix compiles/applies correctly (read the line back)
4. If a fix would break something else, say so and propose an alternative
5. If the bug report's fix is wrong, correct it and note the correction
6. Pause between severity tiers — never auto-proceed without user confirmation
7. If there are 10+ bugs in a tier, fix 5 at a time, then ask to continue
8. If `foundbugs.md` does not exist, say: "No foundbugs.md found. Run --bug first to scan for bugs."

## Multi-Turn Workflow

Large projects may have many bugs. The --fix process is designed to work across multiple prompts:

```
Turn 1: --fix → fixes CRITICAL bugs → asks "Continue with HIGH?"
Turn 2: --fix → fixes HIGH bugs → asks "Continue with MEDIUM?"
Turn 3: --fix → fixes MEDIUM bugs → asks "Continue with LOW?"
Turn 4: --fix → fixes LOW bugs → "All bugs fixed. foundbugs.md updated."
```
