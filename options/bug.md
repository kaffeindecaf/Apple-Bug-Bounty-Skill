---
name: options-bug
version: 1.0.0
trigger: --bug
description: Bug checker. Scans code for bugs using 10 bug classes, writes findings to foundbugs.md, chains with --fix to resolve them.
chains_to: --fix
---

# --bug: Bug Checker

Scan the target for bugs using the 10 bug classes from `ios-research-methodology.md`. Write findings to `foundbugs.md`. When done, tell the user to run `--fix`.

## Phase 1: Scan

Run the systematic audit protocol against the target:

1. **Thread-safety** — global variables without mutex protection
2. **Offset validation** — wrong version block loaded, no sanity check
3. **Dangling pointers** — borrowed memory freed before use
4. **Resource exhaustion** — no bounds on allocation/spray counts
5. **Retry logic gaps** — no retry on transient failures
6. **Macro bugs** — sign extension, wrong comparison values
7. **Busy-wait loops** — spin without yield/sleep
8. **TOCTOU** — time-of-check-to-time-of-use race windows
9. **Hardcoded paths/versions** — assumes stable layout
10. **Information leaks** — sensitive data in logs/debug output

## Phase 2: Write foundbugs.md

Write findings to a file named `foundbugs.md` in the target directory (or current directory if no target specified).

### File Format

```markdown
# Found Bugs — [Project Name]
Scanned: [date]
Files analyzed: [count]
Bug classes checked: 10

---

## CRITICAL

### [BUG-001] [Title]
**Class:** [thread-safety | offset-validation | etc.]
**File:** [path:line]
**Severity:** CRITICAL
**Description:** [what the bug is, how it manifests]
**Impact:** [what breaks, what an attacker gains]
**Fix:** [concrete fix — code change or config change]

---

### [BUG-002] [Title]
...same format...

---

## HIGH

### [BUG-003] [Title]
...same format...

---

## MEDIUM

### [BUG-004] [Title]
...same format...

---

## LOW

### [BUG-005] [Title]
...same format...

---

## Summary

| Severity | Count |
|----------|-------|
| CRITICAL | [n] |
| HIGH     | [n] |
| MEDIUM   | [n] |
| LOW      | [n] |
| **TOTAL** | **[n]** |

---

## Next Step

Run: `--fix` to fix these bugs one at a time.
```

### Rules

- Every bug must have a concrete file path and line number
- Every bug must have a concrete fix (not "consider fixing this" — give the exact code change)
- CRITICAL bugs cause crashes, panics, or data corruption
- HIGH bugs cause silent failures or exploitable conditions
- MEDIUM bugs degrade performance or reliability
- LOW bugs are code quality, documentation, or edge-case issues
- If no bugs found, write `foundbugs.md` with a clean scan report

## Phase 3: Prompt for --fix

After writing `foundbugs.md`, output:

```
Bugs written to foundbugs.md. [n] found ([c] critical, [h] high, [m] medium, [l] low).

Next: run --fix to start fixing the critical bugs.
```
