---
name: options-new
version: 1.0.0
trigger: --new
description: Audit mode. Analyzes a target, finds issues, recommends skills, ranks findings critical-to-low. Works with new projects or unknown repos.
---

# --new: Audit & Discovery Mode

Use when:
- You have a new project and want the agent to analyze it end-to-end
- You don't know which skill to load
- You want a systematic audit of code, structure, security, and exploit potential

## Phase 1: Reconnaissance

### 1.1 Initial Scan
Scan the target (URL, repo, directory, or binary). Answer:
- What is this? (one-line description)
- What does it build? (app, tweak, daemon, library, tool)
- What is the build system? (Theos, Xcode, Makefile, CMake, SPM)
- What language(s)? (C, ObjC, Swift, Python, JS, Shell)
- How many files? Lines of code?
- What iOS versions does it target?

### 1.2 Dependency Map
Map the dependency graph:
- What frameworks does it link? (IOKit, IOSurface, Foundation, UIKit)
- What entitlements does it use? (list all from entitlements.plist)
- What external repos does it reference? (git submodules, vendored deps)
- What tools does it require? (Theos, ldid, clang, XPF, bspatch, img4tool)

## Phase 2: Security Audit

### 2.1 Bug Class Scan
Run the 10 bug classes from `ios-research-methodology.md` against the target:

1. Thread-safety (missing mutex on shared state)
2. Offset validation (wrong version block loaded)
3. Dangling pointers (borrowed memory freed)
4. Resource exhaustion (no bounds on allocation)
5. Retry logic gaps (no retry on transient failure)
6. Macro bugs (sign extension, wrong comparison)
7. Busy-wait loops (spin without yield)
8. TOCTOU (time-of-check-to-time-of-use)
9. Hardcoded paths/versions (assumes stable layout)
10. Information leaks (debug output to logs)

### 2.2 Exploit Surface Map
For each attack surface found, note:
- What privilege level is needed to reach it?
- What can an attacker achieve?
- Is it patched in any iOS version?
- What skill covers this?

## Phase 3: Skill Recommendation

Based on the audit, recommend which skills to load:
```
Recommended skills for this project:
1. ios-kernel-exploit     — ICMPv6 socket spray + IOSurface race detection
2. ios-sandbox-escape     — sandbox extension patching found
3. ios-code-injection     — ROP chain injection utility
```

## Phase 4: Findings Report

Output findings ranked by severity:

```
CRITICAL (causes kernel panic or data corruption):
  [F-001] Thread-safety race in kread — no mutex on shared controlData
    File: kexploit/krw.m:42
    Fix: add pthread_mutex around setTargetKaddr + getsockopt/setsockopt
    PR template: git add kexploit/krw.m && commit "fix: add mutex to kread critical section"

HIGH (silent failure, wrong behavior, exploitable):
  [F-002] Missing xpaci() on arm64e — PAC bits corrupt pointer dereference
    File: kexploit/kbase.m:89
    Fix: wrap kread64 result with xpaci() before use

MEDIUM (performance, reliability, maintenance):
  [F-003] Busy-wait in free_thread without yield
    File: kexploit/phys.c:156
    Fix: add pthread_yield_np() in spin loop

LOW (code quality, documentation, edge cases):
  [F-004] Hardcoded "iPhone14,5" device check — fails on other models
    File: kexploit/offsets.m:23
    Fix: use hw.machine sysctl instead of hardcoded string
```

## Phase 5: Next Steps

For each finding, provide:
1. Exact file path and line number
2. The fix (code or config change)
3. Verification method (test, command, check)
4. Priority (do this first, second, later)

## Interaction with Other Options

- `--new --verbose`: Exhaustive audit. Every file, every function, every variable.
- `--new --adhd`: Findings only, ranked. No explanations. Just files, lines, and fixes.
- `--new --thinking`: Deep audit with multiple hypotheses per finding. Why the bug exists, what the developer was thinking, what the fix changes.
