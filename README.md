# Apple-Bug-Bounty-Skill

iOS exploit development knowledge base. Built from a deep audit of the W0lfSword exploit chain and 11 reference repositories (August 2026). Designed for use with AI coding agents — Claude Code, Cursor, OpenAI Codex, and OpenCode.

---

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
├── SKILL.md                            # Master router — research-first, dynamic routing
│
├── skills/                             # 10 specialized skill modules
│   ├── ios-kernel-exploit.md           # KASLR, PAC, SMR, IOSurface, socket spray
│   ├── ios-sandbox-escape.md           # MAC framework, ext-patch, SSV, vnode, TCC
│   ├── ios-security-pentesting.md      # AMFI, CoreTrust, Frida, bug bounty
│   ├── ios-misc-tooling.md             # Theos, deploy, kernelcache, device mgmt
│   ├── ios-bootchain-exploit.md        # Checkm8, IMG4, DeviceTree, trust cache
│   ├── ios-code-injection.md           # ROP, dylib injection, shellcode, PAC forge
│   ├── ios-webkit-exploit.md           # JSC, JIT, OffscreenCanvas, WebKit chain
│   ├── ios-puaf-exploit.md             # PhysPuppet, Smith, Landa PUAF methods
│   ├── ios-coretrust-bypass.md         # CoreTrust, perma-sign, TrollStore internals
│   └── ios-research-methodology.md     # Audit protocol, bug classes, learning path
│
├── projects/                           # 11 reference exploit repos
│   ├── W0lfSword/                      # The exploit chain (audited meta-project)
│   ├── bad_query/                      # forcequit — container traversal (26-27)
│   ├── darksword-kexploit/             # opa334 — clean DarkSword CLI
│   ├── DarkSword-RCE/                  # htimesnine — WebKit→GPU→kernel chain
│   ├── excalibur/                      # 34306 — GUI + Remote ROP + MIG bypass
│   ├── FilzaJailedDS/                  # 34306 — original tweak + exploit
│   ├── kfd/                            # felix-pb — PUAF (PhysPuppet/Smith/Landa)
│   ├── opainject/                      # opa334 — ROP dylib injection
│   ├── TrollStore/                     # opa334 — CoreTrust perma-sign
│   ├── usbliter8-fun/                  # wh1te4ever — Checkm8 iOS 15.6+27
│   └── usbliter8-fun2/                 # 34306 — iOS 27 jailbreak
│
├── docs/                               # Research artifacts
│   ├── researchdeepseek.md             # 31 bounty findings (8 HIGH, 14 MED, 9 LOW)
│   └── ios-exploit-skill.md            # Legacy monolithic skill (superseded)
│
├── .claude/instructions.md             # Claude Code config
├── .cursorrules                        # Cursor workspace rules
├── .codex.md                           # Codex agent instructions
└── opencode.json                       # OpenCode skill registry
```

---

## Skill System

10 specialized skill modules, each with YAML frontmatter, trigger words, cross-reference rules, and a research-first directive. The master `SKILL.md` routes questions to the correct skill and enforces that agents research external sources before answering.

### Routing Matrix

| Skill | Tokens | Domain |
|-------|--------|--------|
| `SKILL.md` | ~4K | Master router — loads on every session |
| `skills/ios-kernel-exploit.md` | ~8K | Kernel exploitation — PAC, SMR, IOSurface, socket spray, Checkm8 offsets |
| `skills/ios-sandbox-escape.md` | ~8K | Sandbox escape — SSV, TCC, vnode, containermanagerd, MIG bypass |
| `skills/ios-security-pentesting.md` | ~9K | Security testing — Frida, AMFI, bug bounty, SSL pinning, jailbreak detection |
| `skills/ios-misc-tooling.md` | ~11K | Tooling — Theos, deploy, kernelcache, libimobiledevice, device management |
| `skills/ios-bootchain-exploit.md` | ~10K | Bootchain — Checkm8, SecureROM, IMG4, PWN DFU, trust cache |
| `skills/ios-code-injection.md` | ~9K | Code injection — ROP chains, dylib injection, PAC forging, remote threads |
| `skills/ios-webkit-exploit.md` | ~9K | WebKit — JSC type confusion, JIT bypass, OffscreenCanvas dlopen, GPU IPC |
| `skills/ios-puaf-exploit.md` | ~8K | PUAF — PhysPuppet, Smith, Landa, kfd library, page table exploitation |
| `skills/ios-coretrust-bypass.md` | ~8K | CoreTrust — perma-sign, CMS signature, fastPathSign, TrollStore |
| `skills/ios-research-methodology.md` | ~8K | Methodology — audit protocol, bug classes, learning path |

### Cross-Reference Rules

Skills reference each other. When a conversation drifts from one domain to another, the active skill tells the agent to load the neighboring skill. For example:

- `ios-kernel-exploit` → if sandbox escape comes up → load `ios-sandbox-escape`
- `ios-webkit-exploit` → if kernel exploit stage is discussed → load `ios-kernel-exploit`
- `ios-code-injection` → if trust cache or AMFI is needed → load `ios-bootchain-exploit`
- `ios-puaf-exploit` → if DarkSword/IOSurface alternative is discussed → load `ios-kernel-exploit`

### Research-First Protocol

Every skill has `research_first: true` in its metadata. If a user mentions a URL, GitHub repo, CVE number, or unknown tool, the agent pauses, fetches the source, and analyzes it before answering.

---

## Exploit Technique Coverage

| Project | Author | Method | iOS | Kernel R/W | Sandbox Escape | SSV Bypass |
|---------|--------|--------|-----|------------|----------------|------------|
| W0lfSword | kaffeindecaf | DarkSword + ext-patch + vnode | 15–26 | ICMPv6 OOB | Extension borrow | Vnode swap |
| bad_query | forcequit | Container path traversal | 26–27 | -- | containermanagerd | -- |
| darksword-kexploit | opa334 | DarkSword CLI | 15–26 | ICMPv6 OOB | -- | -- |
| DarkSword-RCE | htimesnine | WebKit → GPU → Kernel | 18.4 | ICMPv6 OOB | GPU msg OOB | -- |
| excalibur | 34306 | DarkSword + Remote ROP | multi | ICMPv6 OOB | Ext + MIG | Vnode redirect |
| FilzaJailedDS | 34306 | Original tweak package | 15–17 | ICMPv6 OOB | Extension patch | Vnode swap |
| kfd | felix-pb | PUAF methods | 16.x | PUAF | -- | -- |
| opainject | opa334 | ROP dylib injection | 14–17 | -- | -- | -- |
| TrollStore | opa334 | CoreTrust bypass | 14–17 | -- | -- | -- |
| usbliter8-fun | wh1te4ever | Checkm8 bootchain | 15.6+27 | SecureROM | Kernel patch | Kernel patch |
| usbliter8-fun2 | 34306 | Checkm8 jailbreak | 27.0b2 | SecureROM | NOP sandbox hooks | DeviceTree rw |

---

## Research Findings — 31 Anomalies Found

From `docs/researchdeepseek.md`:

| Severity | Count | Sampling |
|----------|-------|----------|
| HIGH | 8 | Thread-safety race in kread, borrow dangling pointers, mutex deadlock, offset validation gap |
| MEDIUM | 14 | S()/K() macro overflow, no free_thread yield, smr_base hardcoded, kcall gadget verification |
| LOW | 9 | khexdump format leak, offset.h duplicates, socket spray exhaustion, TweakLog rotation racing |

### Fixes Shipped

- W0lfSword — 7 fixes (mutex, validation, rootvnode, khexdump, offsets, free_thread yield, offsets.h)
- bad_query — 3 fixes (NULL guard, max_inode bound, stopAccessing leak)
- darksword-kexploit — 2 fixes (mutex, free_thread yield)

---

## Setup

### Prerequisites

- Git 2.40+
- Python 3.10+ (XPF, TSS proxy, activation scripts)
- clang + ldid (if building exploits locally)
- Theos (optional, for tweak compilation)
- libimobiledevice (optional, for USB device interaction)

### Agent Configuration

<details>
<summary><b>Claude Code</b></summary>

File: `.claude/instructions.md` — auto-loaded on session start. Configures Claude with the 10-skill registry, research-first protocol, and dynamic cross-referencing.
</details>

<details>
<summary><b>Cursor</b></summary>

File: `.cursorrules` — auto-ingested on workspace open. Registers all 10 skill paths as `@`-mention references. The master `SKILL.md` handles routing.
</details>

<details>
<summary><b>OpenAI Codex</b></summary>

File: `.codex.md` — loaded via `codex --instructions .codex.md`. Defines skill dispatch rules and the research-first behavioral directive.
</details>

<details>
<summary><b>OpenCode</b></summary>

File: `opencode.json` — full skill registry with trigger words, cross-reference rules, and agent compatibility metadata. Loaded automatically.
</details>

---

## Contribution

To add a new project:

```bash
cd projects/
git submodule add https://github.com/author/new-exploit.git
```

To add a new skill — create a markdown file in `skills/` with YAML frontmatter, trigger words, cross-reference rules, and the `research_first: true` flag. Then register it in `SKILL.md`, `opencode.json`, and each agent config file.

---

## External Resources

- Apple XNU source: https://github.com/apple-oss-distributions/xnu
- Apple KDK: https://developer.apple.com/download/all/?q=kernel
- Theos build system: https://github.com/theos/theos
- libimobiledevice: https://github.com/libimobiledevice/libimobiledevice
- Frida instrumentation: https://frida.re
- Objection runtime: https://github.com/sensepost/objection
- IPSW Downloads: https://ipsw.me
- The iPhone Wiki: https://www.theiphonewiki.com

---

## Credits

This knowledge base was built from the work of the following researchers and developers:

| Project | Author |
|---------|--------|
| W0lfSword (exploit chain) | kaffeindecaf |
| bad_query (forcequitOS) | Taj C (forcequit) |
| darksword-kexploit | Lars Froder (opa334) |
| DarkSword-RCE | htimesnine |
| excalibur | seo (34306) |
| FilzaJailedDS | seo (34306) |
| kfd | Felix Poulin-Belanger (felix-pb) |
| opainject | Lars Froder (opa334) |
| TrollStore | Lars Froder (opa334) |
| usbliter8-fun | wh1te4ever |
| usbliter8-fun2 | wh1te4ever |

Additional credits: Google TAG (DarkSword chain analysis), Linus Henze (original CoreTrust bug, installd bypass), @alfiecg_dev (CVE-2023-41991 patchdiffing), CrazyMind90 (sandbox extension patching technique), khanhduytran0, tihmstar, m1stadev/doronz88, Lakr233, Duy Tran.

Curated by kaffeindecaf — github.com/kaffeindecaf — August 2026 — MIT License
