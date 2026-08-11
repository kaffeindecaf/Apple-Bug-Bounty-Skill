# W0lfSword Reference AI — iOS Exploit Development Swarm

> **λ-neural knowledge mesh for autonomous vulnerability discovery, kernel exploitation, sandbox escape, and iOS security reverse engineering.**
>
> Curated from a 10-repository deep audit of the W0lfSword exploit ecosystem (August 2026).
> Designed as a **drop-in brain module** for AI coding agents — Claude Code, Cursor, Codex, OpenCode, and any MCP-capable copilot.

## Quick Start

```bash
git clone https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill.git
cd Apple-Bug-Bounty-Skill
```

Then pick your agent:

### Claude Code

```bash
claude                              # Auto-discovers .claude/instructions.md
claude "Analyze this kernel panic for IOSurface race conditions"
```

### Cursor

```bash
# Open this workspace in Cursor, then reference skills inline:
# @skills/ios-kernel-exploit.md    — kernel exploit context
# @skills/ios-sandbox-escape.md    — sandbox escape context
# @skills/ios-security-pentesting.md — bug bounty / reversing
# @skills/ios-misc-tooling.md      — build, deploy, tooling
```

### OpenAI Codex

```bash
codex                                                # Auto-discovers .codex.md
codex --instructions .codex.md "Find all SSV bypass techniques"
```

### OpenCode

```bash
opencode                                                     # Auto-loads opencode.json
opencode "Load ios-kernel-exploit skill and analyze this kernel panic"
```

---

## Directory Map

```
Apple-Bug-Bounty-Skill/
│
├── SKILL.md                            # Master router — research-first protocol, dynamic routing
│
├── skills/                             # 7 Agent Skill Modules
│   ├── ios-kernel-exploit.md           # Mem: KASLR/PAC/SMR/IOKit/OOB/Checkm8
│   ├── ios-sandbox-escape.md           # Mem: MAC-fw/ext-patch/SSV/vnode/TCC
│   ├── ios-security-pentesting.md      # Mem: AMFI/CoreTrust/Frida/bounty-meta
│   ├── ios-misc-tooling.md             # Mem: Theos/build/deploy/debug/devices
│   ├── ios-bootchain-exploit.md        # Mem: Checkm8/IMG4/DeviceTree/trust-cache
│   ├── ios-code-injection.md           # Mem: ROP/dylib-inject/shellcode/PAC-forge
│   └── ios-research-methodology.md     # Mem: audit-protocol/bug-classes/learning-path
│
├── projects/                           # 10 reference exploit repos
│   ├── bad_query/                     # forcequitOS — container traversal (26-27)
│   ├── darksword-kexploit/            # opa334 — clean DarkSword CLI
│   ├── DarkSword-RCE/                 # htimesnine — WebKit→GPU→kernel chain
│   ├── excalibur/                     # 34306 — GUI + Remote ROP + MIG bypass
│   ├── FilzaJailedDS/                 # 34306 — original tweak + exploit
│   ├── kfd/                           # felix-pb — PUAF (PhysPuppet/Smith/Landa)
│   ├── opainject/                     # opa334 — ROP dylib injection
│   ├── TrollStore/                    # opa334 — CoreTrust perma-sign
│   ├── usbliter8-fun/                 # wh1te4ever — Checkm8 iOS 15.6+27
│   └── usbliter8-fun2/                # 34306 — iOS 27 jailbreak
│
├── docs/                              # Deep research artifacts
│   ├── researchdeepseek.md            # 31 bounty findings (8 HIGH, 14 MEDIUM, 9 LOW)
│   └── ios-exploit-skill.md           # Legacy monolithic skill (superseded)
│
├── .claude/instructions.md            # Claude Code auto-load prompt
├── .cursorrules                       # Cursor workspace rules
├── .codex.md                          # Codex agent instructions
└── opencode.json                      # OpenCode skill registry
```

---

## Dynamic Skill System — Research-First Swarm

Skills are not isolated. Each one knows which other skills to load when a conversation drifts across domains. The master `SKILL.md` enforces a **research-first protocol**: if a user mentions a URL, GitHub repo, CVE, or unknown tool, the agent pauses, fetches the source, and analyzes it before answering.

### Routing Matrix (7 Skills + Master Router)

| Skill File | Tokens | Domain & Trigger Phrases |
|-----------|--------|--------------------------|
| `SKILL.md` | ~4K | Master router — loads on every session. Enforces research-first, routes to sub-skills. |
| `skills/ios-kernel-exploit.md` | ~8K | Kernel exploitation — "PAC bypass," "IOSurface race," "socket spray," "SMR pointer," "KASLR" |
| `skills/ios-sandbox-escape.md` | ~8K | Sandbox escape — "SSV write," "TCC.db," "vnode redirect," "MIG bypass," "extension patch" |
| `skills/ios-security-pentesting.md` | ~9K | Security testing — "bug bounty," "Frida hook," "AMFI flag," "CoreTrust," "TrollStore" |
| `skills/ios-misc-tooling.md` | ~11K | Tooling & workflow — "Theos build," "deploy to device," "kernelcache extract," "SSH iOS" |
| `skills/ios-bootchain-exploit.md` | ~10K | Bootchain — "Checkm8," "SecureROM," "IMG4," "PWN DFU," "trust cache," "DeviceTree" |
| `skills/ios-code-injection.md` | ~9K | Code injection — "ROP chain," "dylib injection," "shellcode," "PAC forge," "remote thread" |
| `skills/ios-research-methodology.md` | ~8K | Research — "how to find bugs," "audit protocol," "learning path," "getting started" |

### Cross-Reference Rules

Every skill has `cross_reference_rules` in its YAML frontmatter. Examples:
- `ios-kernel-exploit` → if sandbox escape comes up → load `ios-sandbox-escape`
- `ios-sandbox-escape` → if kernel offsets are needed → load `ios-kernel-exploit`
- `ios-code-injection` → if trust cache / AMFI needed → load `ios-bootchain-exploit`
- `ios-research-methodology` → if a specific bug class is found → load the domain skill

### YAML Frontmatter (Machine-Readable)

Every skill file carries structured metadata including cross-reference rules and the research-first flag:

```yaml
---
name: ios-kernel-exploit
version: 3.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf]
token_budget: 8192
cross_reference_rules:
  - If sandbox escape or SSV bypass is discussed → load ios-sandbox-escape
  - If bootchain/Checkm8 patches are discussed → load ios-bootchain-exploit
  - If ROP or code injection is needed → load ios-code-injection
research_first: true
triggers:
  - kernel exploit
  - PAC bypass
  - IOSurface race
  - KASLR bypass
related_skills:
  - sandbox-escape
  - bootchain-exploit
  - code-injection
  - misc-tooling
---
```

---

## Exploit Technique Coverage

| Project              | Method                        | iOS Range | Kernel R/W   | Sandbox Escape      | SSV Bypass       |
| -------------------- | ----------------------------- | --------- | ------------ | ------------------- | ---------------- |
| **W0lfSword** (meta) | DarkSword + ext-patch + vnode | 15–26     | ✓ ICMPv6 OOB | ✓ Extension borrow  | ✓ Vnode swap     |
| `bad_query`          | Container path traversal      | 26–27     | —            | ✓ containermanagerd | —                |
| `darksword-kexploit` | DarkSword CLI                 | 15–26     | ✓ ICMPv6 OOB | —                   | —                |
| `DarkSword-RCE`      | WebKit → GPU → XNU            | 18.4      | ✓ ICMPv6 OOB | ✓ GPU msg OOB       | —                |
| `excalibur`          | DarkSword + Remote ROP        | multi     | ✓ ICMPv6 OOB | ✓ Ext + MIG         | ✓ Vnode redirect |
| `FilzaJailedDS`      | Original tweak package        | 15–17     | ✓ ICMPv6 OOB | ✓ Extension patch   | ✓ Vnode swap     |
| `kfd`                | PUAF methods                  | 16.x      | ✓ PUAF       | —                   | —                |
| `opainject`          | ROP dylib injection           | 14–17     | —            | —                   | —                |
| `TrollStore`         | CoreTrust bypass              | 15–17     | —            | —                   | —                |
| `usbliter8-fun`      | Checkm8 bootchain             | 15.6+27   | ✓ SecureROM  | ✓ Kernel patch      | ✓ Kernel patch   |
| `usbliter8-fun2`     | Checkm8 jailbreak             | 27.0b2    | ✓ SecureROM  | ✓ NOP sandbox hooks | ✓ DeviceTree rw  |

---

## Research Cortex — 31 Anomalies Found

From `docs/researchdeepseek.md` — a comprehensive deep audit:

| Severity     | Count | Sampling                                                                                                                                                                                                                        |
| ------------ | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **HIGH**     | 8     | Thread-safety race in `kread`, borrow dangling pointer UaF, mutex deadlock, offset validation gap, root vnode chain, `free_thread` spin, `khexdump` PAC strip, `sandbox_escape` retry loop stall                                |
| **MEDIUM**   | 14    | `S()`/`K()` macro overflow, no `free_thread` yield, `inp_listnext` walk depth, `kwrite_zone_element` size, extension class string leak, `bsd_flags` write through, `smr_base` statically hardcoded, `kcall` gadget verification |
| **LOW**      | 9     | `khexdump` format leak, `offset.h` duplicates, `zip` main-thread block, socket spray exhaustion threshold, `check_sandbox` test coverage, `TweakLog` rotation racing, comment stale offsets                                     |

### Fixes Shipped (PRs Merged)

- **W0lfSword** — 7 fixes (mutex, validation, rootvnode, khexdump, offsets, free_thread yield, offsets.h)
- **bad_query** — 3 fixes (NULL guard, max_inode bound, stopAccessing leak)
- **darksword-kexploit** — 2 fixes (mutex, free_thread yield)

---

## Setup & Agent Wiring

### Prerequisites

- **Git** ≥ 2.40
- **Python 3.10+** (for XPF, TSS proxy, activation scripts)
- **clang + ldid** (if building exploits locally)
- **Theos** (optional, for tweak compilation)
- **libimobiledevice** (optional, for USB device interaction)

### Agent-Specific Configuration

<details>
<summary><b>Claude Code</b></summary>

```
File: .claude/instructions.md
Auto-loaded on session start. Configures Claude as an iOS exploit
research assistant with full knowledge-base routing.

Key directives:
— Auto-routes kernel questions → ios-kernel-exploit skill
— Auto-routes sandbox questions → ios-sandbox-escape skill
— Auto-routes bug bounty / reversing → ios-security-pentesting skill
— Auto-routes build/deploy questions → ios-misc-tooling skill
```

</details>

<details>
<summary><b>Cursor</b></summary>

```
File: .cursorrules
Auto-ingested on workspace open. Registers skill paths as context
references so @-mention auto-completion surfaces skills.

Key behavior:
— @skills/ios-kernel-exploit → loads kernel exploit context
— @skills/ios-sandbox-escape → loads sandbox escape context
— @docs/researchdeepseek.md → loads full research document
```

</details>

<details>
<summary><b>OpenAI Codex</b></summary>

```
File: .codex.md
Auto-loaded via codex --instructions or codex.yaml config.

Key directives:
— Defines 4 "agent personality" presets
— Maps natural language intents to skill file paths
— Sets context injection rules for codex chat window
```

</details>

<details>
<summary><b>OpenCode</b></summary>

```
File: opencode.json
Registered as a skill plugin. Skills map 1:1 to opencode's skill
context injection system.

Key behavior:
— opencode loads opencode.json at startup
— Skills are registered in the agent skill registry
— Can be invoked via "Load ios-kernel-exploit skill"
— Cross-skill routing via related_skills metadata
```

</details>

---

## Contribution

This is a curated reference knowledge mesh. To extend:

```bash
# Add a new reference project
cd projects/
git submodule add https://github.com/author/new-exploit.git

# Add a new skill
cp skills/_template.md skills/ios-new-domain.md
# Edit with domain expertise, YAML frontmatter, agent triggers

# Validate agent compatibility
python3 scripts/validate_skills.py   # (coming soon)
```

---

## External Resources

- **Apple XNU source:** https://github.com/apple-oss-distributions/xnu
- **Apple KDK:** https://developer.apple.com/download/all/?q=kernel
- **Theos build system:** https://github.com/theos/theos
- **libimobiledevice:** https://github.com/libimobiledevice/libimobiledevice
- **Frida instrumentation:** https://frida.re
- **Objection runtime:** https://github.com/sensepost/objection
- **IPSW Downloads:** https://ipsw.me
- **The iPhone Wiki:** https://www.theiphonewiki.com

---

> `λ(swarm).neural → [kernel|sandbox|pentest|tooling].context_inject(trigger) → exploit_knowledge.activation()`
>
> _Curated by **kaffeindecaf** · github.com/kaffeindecaf · August 2026 · MIT License_
