---
name: ios-research-methodology
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf]
token_budget: 8192
covers: [research methodology, bug hunting, code audit, reverse engineering, offset discovery, learning path, getting started]
platforms: [iOS 15.0-27.0, arm64/arm64e, any Apple platform]
triggers:
  - research
  - methodology
  - how to find bugs
  - how to audit
  - how to reverse
  - how to discover offsets
  - learning path
  - getting started
  - beginner
  - tutorial
  - systematic code review
  - thread safety analysis
  - bug class
  - vulnerability class
  - CVE research
  - patch diff
  - binary diff
  - ASTG
related_skills:
  - ios-kernel-exploit
  - ios-sandbox-escape
  - ios-security-pentesting
  - ios-bootchain-exploit
  - ios-code-injection
  - ios-misc-tooling
cross_reference_rules:
  - If a specific bug class is found → load the domain skill (kernel, sandbox, bootchain, etc.)
  - If tooling is needed for the research → load ios-misc-tooling
  - If bug bounty report writing → load ios-security-pentesting
research_first: true
---

# iOS Exploit Research Methodology

> **Skill type:** Meta — research methodology, bug hunting, and learning path
> **Platforms:** iOS 15.0-27.0, any Apple platform
> **Based on:** W0lfSword audit methodology, 10-repository deep analysis
> **Last updated:** 2026-08-11

---

## When to Use This Skill

Use when the task involves:
- Learning how to approach iOS exploit research from scratch
- Systematic code audit and bug hunting methodology
- Understanding vulnerability classes and how to find them
- Building a research pipeline (discovery → validation → exploitation → reporting)
- Deciding which tools and techniques to apply to a new target
- Understanding the exploit development learning path
- Setting up a research environment for iOS security

---

## RESEARCH-FIRST DIRECTIVE

This skill IS about research methodology, so the directive doubles down: if the user asks about a specific bug, CVE, exploit, or target that you have not personally analyzed, **you must research that target before giving methodological advice.** Fetch the repo, read the advisory, understand the bug class first. Then apply the methodology described here.

If the conversation drifts into a specific domain (kernel, sandbox, bootchain, etc.), immediately load the corresponding skill file.

---

## 1. The Audit Methodology

### 1.1 Systematic Code Review Protocol

This methodology produced 31 findings from 10 repositories. Here is the exact protocol:

**Phase 1: Architecture Reconnaissance (1-2 hours)**
```
1. Read the top-level README and any documentation
2. Map the directory structure — understand what each directory contains
3. Identify the build system (Theos, Xcode, Makefile, CMake, SPM)
4. Trace the main execution path from entry point
5. Identify the key exploit primitives (what is the bug? how is it triggered?)
6. Draw the memory/control flow diagram (proc → proc_ro → ucred → ...)
```

**Phase 2: Deep Source Audit (4-8 hours)**
```
For each source file:
  1. Identify ALL global variables — are they mutex-protected?
  2. Trace every function's callers — what is the context?
  3. Check return values — are errors handled?
  4. Look for hardcoded values — version numbers, offsets, iOS build IDs
  5. Check pointer dereferences — are NULL checks present?
  6. Check array accesses — are bounds validated?
  7. Check thread safety — any shared state without synchronization?
  8. Check memory management — malloc/free pairing, refcounts
```

**Phase 3: Cross-Project Comparison (2-4 hours)**
```
For each reference project:
  1. How does it solve the same problem differently?
  2. What does it do better than the main project?
  3. What bugs does it have that the main project fixed?
  4. What techniques does it use that are not in the main project?
```

### 1.2 Bug Classes to Hunt For

Ranked by frequency found in the W0lfSword audit:

| Rank | Bug Class | Example Finding | Detection Method |
|------|-----------|----------------|-----------------|
| 1 | **Thread-safety** (missing mutex on shared state) | BB-015: kread without mutex | Grep for global vars, check if pthread_mutex used near them |
| 2 | **Offset validation** (wrong version block loaded) | BB-031: off_p_pid returns garbage | Check offsets_init() — does it validate after loading? |
| 3 | **Dangling pointers** (borrowed memory freed) | BB-018: borrowed sandbox extensions | Trace pointer lifetimes — is the source still alive when read? |
| 4 | **Resource exhaustion** (no bounds on allocation) | BB-030: 27,000 socket() calls | Check loops that allocate — is there a limit? |
| 5 | **Retry logic gaps** (no retry on transient failure) | BB-020: sandbox_escape no retry | Look for operations that can fail transiently — are they retried? |
| 6 | **Macro bugs** (sign extension, wrong comparison) | BB-016: S() sign-extends | Audit every macro — does it handle edge cases? |
| 7 | **Busy-wait loops** (spin without yield) | BB-021: free_thread no yield | Grep for while(1) loops — do they yield or sleep? |
| 8 | **TOCTOU** (time-of-check-to-time-of-use) | BB-019: vnode race after get | Trace check → use — is there a window? |
| 9 | **Hardcoded paths/versions** (assumes stable layout) | BB-028: launchd parent chain | Grep for "/private/var", "17", "18" — are they version-guarded? |
| 10 | **Information leaks** (debug output to logs) | BB-022: khexdump outputs raw data | Check logging — does it print sensitive memory contents? |

### 1.3 Severity Classification Framework

```
HIGH:
  - Causes kernel panic (DoS / crash)
  - Silently corrupts data (wrong offsets, no validation)
  - Dangling pointer dereference (UaF in kernel)
  - Race condition in exploit primitive (unreliable exploit)

MEDIUM:
  - Resource exhaustion (slow path, memory waste)
  - Missing retry (exploit fails but doesn't crash)
  - Wrong-but-not-fatal values (sign extension edge cases)
  - Hardcoded assumptions that break on new iOS versions
  - Busy-wait without yield (degrades performance)

LOW:
  - Information leak (non-sensitive data in logs)
  - Code duplication (maintenance burden)
  - Comment/documentation issues
  - Suboptimal but functional code patterns
```

---

## 2. Research Pipeline

### 2.1 Discovery Phase

**Where to find new targets:**
- GitHub search: `ios kernel exploit`, `IOSurface`, `xnu`, `kexploit`
- Apple open source: https://github.com/apple-oss-distributions/xnu
- The iPhone Wiki: https://www.theiphonewiki.com
- Security conference talks: BlackHat, DEF CON, POC, Zer0Con, TyphoonCon, Objective by the Sea
- Apple Security Research: https://security.apple.com
- CVE feeds: NVD, MITRE, CVE Details, Apple security updates
- Twitter/X: follow iOS security researchers (s1guza, i41nbeer, p0sixninja, etc.)
- HackerOne disclosed reports (filter by "Apple")

**How to evaluate a new target:**
1. Is the source available? Public repo? Open source?
2. What iOS versions does it target? (wider range = more valuable)
3. What is the attack vector? (local app, WebKit, physical, network)
4. What is the prerequisite? (kernel R/W, entitlements, jailbreak, checkm8)
5. Is it maintained? (recent commits, active issues)
6. Does it have documentation? (README, wiki, comments)

### 2.2 Validation Phase

**For a new exploit technique:**
```
1. Identify the claimed iOS version and device model
2. Check the build system — can you reproduce the build?
3. Check for hardware dependencies (RP2350, JTAG, special cable)
4. Read the exploit flow — does it logically make sense?
5. Check for a PoC/test case — does it exist? can you run it?
6. Check for crash logs / panic logs — are they provided?
7. Cross-reference with known CVEs — is this a variant of something known?
```

**For a new offset:**
```c
// Always validate at runtime:
int validate_offset(uint64_t proc, uint64_t off, const char *name) {
    uint32_t pid = kread32(proc + off);
    if (pid != getpid()) {
        fprintf(stderr, "Offset %s (0x%llx): expected PID %d, got %u\n",
                name, off, getpid(), pid);
        return -1;
    }
    return 0;
}
```

### 2.3 Exploitation Phase

**Escalation Ladder (in order of increasing difficulty):**
1. **Information leak** — KASLR bypass, kernel slide discovery
2. **Kernel R/W** — via IOSurface, PUAF, socket spray, or other bug class
3. **Post-exploitation** — PAC strip, SMR decode, thread hijacking, kcall
4. **Sandbox escape** — extension patching, path traversal, MIG bypass
5. **Persistence** — SSV bypass, trust cache injection, launch daemon install
6. **Code signing bypass** — AMFI disable, entitlement injection

### 2.4 Reporting Phase

For Apple Security Bounty submissions, see `ios-security-pentesting.md` Section 2.2.

---

## 3. Learning Path

### 3.1 Prerequisites

Before attempting iOS exploit development, you need:
- **C programming** — all kernel exploits are written in C/ObjC
- **Arm64 assembly** — PAC instructions, ADRP/LDR pairs, gadget hunting
- **Operating systems** — virtual memory, page tables, MMU, TLB
- **XNU kernel** — proc, thread, vnode, inpcb structs, MAC framework
- **Build chain** — Theos, clang, ldid, dpkg-deb (see `ios-misc-tooling.md`)

### 3.2 Stage-by-Stage Progression

```
Stage 1 — Environment Setup (Week 1)
  - Install Theos, ldid, clang
  - Set up SSH to a jailbroken test device
  - Build and deploy a "Hello World" tweak
  - Read ios-misc-tooling.md cover to cover

Stage 2 — Basic Reversing (Week 2-3)
  - Extract kernelcache from IPSW
  - Find kernel base (Mach-O magic 0xFEEDFACF)
  - Read kernel struct offsets from KDK
  - Read ios-kernel-exploit.md Sections 1-2

Stage 3 — First Exploit (Week 4-6)
  - Study darksword-kexploit (cleanest codebase)
  - Understand socket spray + IOSurface race
  - Run the exploit on a test device
  - Read researchdeepseek.md for deep analysis

Stage 4 — Bug Hunting (Week 7-10)
  - Apply the audit methodology (Section 1.1)
  - Find your first bug in an existing exploit
  - Write a fix and submit a PR
  - Read ios-research-methodology.md again

Stage 5 — Novel Research (Ongoing)
  - Pick an unexplored attack surface (new IOKit driver, new daemon, new syscall)
  - Apply the vulnerability classes (Section 1.2)
  - Build a PoC, validate, and report
```

### 3.3 Recommended Reading Order

1. `ios-misc-tooling.md` — set up your environment first
2. `ios-kernel-exploit.md` — understand the core exploitation primitives
3. `ios-sandbox-escape.md` — learn the privilege escalation chain
4. `ios-code-injection.md` — learn runtime manipulation
5. `ios-bootchain-exploit.md` — learn boot-level persistence
6. `ios-security-pentesting.md` — learn reporting and bounty methodology
7. `ios-research-methodology.md` — return here to systematize your approach

---

## 4. Tools Reference

### 4.1 Essential Tools

| Tool | Purpose | Source |
|------|---------|--------|
| Theos | iOS tweak build system | https://github.com/theos/theos |
| KDK | Kernel Debug Kit (debug symbols) | https://developer.apple.com/download/all/?q=kernel |
| joker | Kernelcache extractor/analyzer | GitHub: joker tool |
| XPF | XNU pattern finder (offset discovery) | Included in repo at `projects/*/XPF` |
| img4tool | IMG4 firmware image manipulation | Included in tools |
| bspatch | Binary patching | Pre-installed on macOS |
| ldid | Ad-hoc code signing | Included in Theos |
| Frida | Dynamic instrumentation | https://frida.re |
| Objection | Automated runtime exploration | https://github.com/sensepost/objection |
| Ghidra / IDA Pro | Binary analysis | https://ghidra-sre.org |
| libimobiledevice | USB device management | https://github.com/libimobiledevice |
| kerneldiff | Kernel binary diffing | GitHub: various forks |

### 4.2 Research Automation

```bash
# Quick repo evaluation script:
function eval_repo() {
    local url="$1"
    local name=$(basename "$url" .git)
    git clone --depth 1 "$url" "/tmp/$name"
    echo "=== $name ==="
    echo "Build system: $(ls /tmp/$name/{Makefile,*.xcodeproj,CMakeLists.txt,Package.swift} 2>/dev/null | head -1)"
    echo "Languages: $(find /tmp/$name -name '*.m' -o -name '*.c' -o -name '*.swift' -o -name '*.py' | sed 's/.*\.//' | sort -u | tr '\n' ' ')"
    echo "Files: $(find /tmp/$name -type f | wc -l)"
    echo "iOS mentions: $(grep -rli 'iOS\|ios\|IPHONEOS' /tmp/$name 2>/dev/null | wc -l) files"
    echo "CVEs: $(grep -rli 'CVE-' /tmp/$name 2>/dev/null | wc -l) files"
    echo ""
    rm -rf "/tmp/$name"
}
```

---

## 5. Common Pitfalls in Research

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Trusting old offsets | Exploit crashes, kernel panics | Validate every offset at runtime with real PID check |
| Not checking prerequisites | Exploit fails silently | Verify entitlements, kernel version, device model |
| Single-version testing | Exploit works on one device, fails on another | Test on minimum and maximum claimed iOS versions |
| Ignoring thread safety | Random, non-reproducible crashes | Always check for shared state without synchronization |
| Not reading the build system | Can't reproduce the exploit | Check Makefile, Theos config, Xcode project — what flags? |
| Skipping the README | Miss critical usage notes | Always read the README first — it often has version-specific notes |
| Assuming offsets are portable | Crash on different iOS build | Use XPF/KPF for automated discovery, not hardcoded offsets |

---

## 6. Quick Reference

```
Audit protocol:    Architecture → Deep Source → Cross-Compare → Report
Bug classes:       10 classes ranked by frequency (Section 1.2)
Severity:          HIGH (panic/corrupt/UaF) → MEDIUM (exhaust/missing retry) → LOW (info leak/dupe)
Learning stages:   Setup → Reversing → First Exploit → Bug Hunting → Novel Research (5 stages)
Research pipeline: Discovery → Validation → Exploitation → Reporting
Escalation ladder: Info Leak → K-R/W → Post-Exploit → Sandbox → Persistence → Code Sign
```

---

## 7. Contribute Back

**Found something critical?** A new bug class nobody has documented? A systematic methodology that found 50+ bugs across multiple projects? A research automation script that cuts audit time by 80%? Contribute it back — every researcher who loads this skill benefits from your methodology.

**Found something useful?** A new evaluation heuristic for repos, an updated tool reference, a corrected learning path stage, a pitfall you discovered the hard way.

```bash
git add skills/ios-research-methodology.md
git commit -m "feat: new research methodology for iOS exploit discovery"
gh pr create --repo kaffeindecaf/Apple-Bug-Bounty-Skill \
  --title "Research methodology improvement" \
  --body "## What was found\n\n## How it improves the audit process\n\n## Results (bugs found, time saved, etc.)"
```

Repository: https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill

Every contribution sharpens every agent that loads this skill.
