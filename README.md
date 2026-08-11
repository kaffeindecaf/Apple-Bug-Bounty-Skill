# W0lfSword Reference AI — iOS Exploit Development Knowledge Base

> **Purpose:** Complete reference for iOS kernel exploit development, sandbox escape, security testing, and tooling.  
> **Curated from:** W0lfSword project + 10 reference repositories deep audit (August 2026)  
> **Skills:** 4 specialized AI agent skills for different exploit domains  
> **Projects:** 10 reference repositories with source code examples  
> **Docs:** Deep analytical research and bug bounty methodology

---

## 📂 Directory Structure

```
referenceforAI/
├── README.md                       # This file
├── skills/                         # 4 AI agent skills (load these in your sessions)
│   ├── ios-kernel-exploit.md       # Kernel exploitation (DarkSword, PAC, SMR, Checkm8)
│   ├── ios-sandbox-escape.md       # Sandbox escape & SSV bypass (extensions, vnode, TCC)
│   ├── ios-security-pentesting.md  # Security testing & bug bounty (AMFI, CoreTrust, reversing)
│   └── ios-misc-tooling.md         # Tooling & workflow (Theos, deploy, logging, devices)
├── projects/                       # Reference source code repos
│   ├── bad_query/                  # forcequitOS — container path traversal sandbox escape
│   ├── darksword-kexploit/         # opa334 — standalone DarkSword kernel exploit CLI
│   ├── DarkSword-RCE/              # htimesnine — WebKit→kernel full exploit chain (JS)
│   ├── excalibur/                  # 34306 — full-featured GUI exploit app + Remote ROP
│   ├── FilzaJailedDS/              # 34306 — original Filza + DarkSword tweak
│   ├── kfd/                        # felix-pb — physical UaF methods (PhysPuppet/Smith/Landa)
│   ├── opainject/                  # opa334 — runtime dylib injection via ROP chain
│   ├── TrollStore/                 # opa334 — CoreTrust perma-sign IPA installer
│   ├── usbliter8-fun/              # wh1te4ever — Checkm8 bootchain patches (iOS 15.6+27.0)
│   └── usbliter8-fun2/             # 34306 — iOS 27 jailbreak with full sandbox bypass
└── docs/                           # Research & methodology
    ├── researchdeepseek.md         # 31 bug bounty findings + deep exploit explanations
    └── ios-exploit-skill.md        # Original combined skill (now split into 4 above)
```

---

## 🧠 AI Skills — When to Use Each

| Skill | Load When... | Key Topics |
|-------|-------------|------------|
| `ios-kernel-exploit` | Kernel R/W, PAC/SMR, socket spray, IOSurface, checkm8, offsets | Physical OOB, ICMP6 filter corruption, pe_v1/pe_v2, USBLoader8 |
| `ios-sandbox-escape` | Sandbox bypass, SSV writes, TCC, entitlements, path traversal | Extension patching, vnode redirect, containermanagerd, APFS fsnode |
| `ios-security-pentesting` | Bug bounty, reversing, Frida, AMFI, code signing, YARA | Apple bounty tiers, CoreTrust, TLS pinning, jailbreak detection |
| `ios-misc-tooling` | Build, deploy, debug, device management, CI/CD | Theos, ldid, SSH, libimobiledevice, kernelcache extraction |

**Usage:** In your AI session, reference the skill file path and ask the AI to load it:
```
Load the skill at skills/ios-kernel-exploit.md before analyzing this kernel panic.
```

---

## 📊 Project Techniques Matrix

| Project | Technique | iOS | Kernel R/W? | Sandbox Escape? | SSV Bypass? |
|---------|-----------|-----|------------|-----------------|-------------|
| **W0lfSword** (parent) | DarkSword + sandbox + SSV | 15-26 | Yes (ICMPv6) | Extension patch + borrow | Vnode swap |
| bad_query | Container path traversal | 26-27 | No | Yes (containermanagerd) | No |
| darksword-kexploit | DarkSword CLI (clean) | 15-26 | Yes (ICMPv6) | No | No |
| DarkSword-RCE | WebKit → GPU → Kernel | 18.4 | Yes (ICMPv6) | GPU process msg OOB | No |
| excalibur | DarkSword + Remote ROP | multi | Yes (ICMPv6) | Extension patch + MIG bypass | Vnode redirect |
| FilzaJailedDS | Original tweak | 15-17 | Yes (ICMPv6) | Extension patch | Vnode swap |
| kfd | PUAF (PhysPuppet/Smith/Landa) | 16.x | Yes (PUAF) | No | No |
| opainject | ROP chain injection | 14-17 | No | No | No |
| TrollStore | CoreTrust bypass | 15-17 | No | No | No |
| usbliter8-fun | Checkm8 bootchain | 15.6+27 | Yes (debug) | Kernel patch | Kernel patch |
| usbliter8-fun2 | Checkm8 jailbreak | 27.0b2 | Yes (debug) | Kernel sandbox hooks NOP'd | DeviceTree rw flag |

---

## 🔍 Key Research Findings

### Bug Bounty Coverage

From `docs/researchdeepseek.md` — 31 total findings:
- **8 HIGH:** Thread-safety race in kread, borrow dangling pointers, mutex deadlock, offset validation gap...
- **14 MEDIUM:** S()/K() macro bugs, no retry in sandbox_escape, free_thread spin, rootvnode chain...
- **9 LOW:** khexdump leak, offset.h duplicates, zip main-thread block, socket spray exhaustion...

### Exploit Architecture Deep Dive

The `docs/researchdeepseek.md` contains comprehensive explanations of:
- DarkSword kernel exploit (ICMPv6 socket spray + IOSurface physical OOB race)
- Sandbox escape via extension set patching (CrazyMind90 technique)
- SSV bypass via vnode data pointer swap
- USBLoader8/Checkm8 boot chain
- WebKit-to-kernel full chain (DarkSword-RCE)
- Remote ROP + MIG filter bypass (excalibur)

### Applied Fixes

PRs submitted to fix the most critical bugs found:
- **W0lfSword:** 7 fixes (mutex, validation, rootvnode, khexdump, offsets, free_thread yield, offsets.h)
- **bad_query:** 3 fixes (NULL guard, max_inode bound, stopAccessing leak)
- **darksword-kexploit:** 2 fixes (mutex, free_thread yield)

---

## 🛠 Quick Start

```bash
# Clone this knowledge base
git clone https://github.com/kaffeindecaf/W0lfSword-reference-AI.git

# Explore the projects
ls projects/

# Read a skill
cat skills/ios-kernel-exploit.md

# Check research findings
cat docs/researchdeepseek.md

# Navigate to a reference project
cd projects/excalibur/
```

---

## 📝 Contribution

This is a curated reference collection. To add a new project:
```bash
cd projects/
git clone https://github.com/author/new-ios-exploit.git
```

To add a new skill:
```bash
cp skills/_template.md skills/ios-new-skill.md
# Edit the skill with the domain knowledge
```

---

## 📚 External Resources

- **Apple XNU source:** https://github.com/apple-oss-distributions/xnu
- **Apple KDK:** https://developer.apple.com/download/all/?q=kernel (debug symbols)
- **Theos:** https://github.com/theos/theos
- **libimobiledevice:** https://github.com/libimobiledevice/libimobiledevice
- **Frida:** https://frida.re
- **Objection:** https://github.com/sensepost/objection

---

*Curated by kaffeindecaf — github.com/kaffeindecaf | August 2026*
