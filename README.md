# Apple-Bug-Bounty-Skill

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-10-green)]()
[![Options](https://img.shields.io/badge/options-8-orange)]()
[![Agents](https://img.shields.io/badge/agents-9-purple)]()
[![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macos%20%7C%20windows-lightgrey)]()

iOS exploit development knowledge base. Built from a deep audit of the W0lfSword exploit chain and 10 reference repositories (August 2026).

> **Supported agents:** Claude Code · Cursor · OpenAI Codex · OpenCode · Windsurf · GitHub Copilot · Gemini · Qwen · Kimi

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill.git
cd Apple-Bug-Bounty-Skill
```

### 2. Run the interactive setup

**Linux / macOS:**
```bash
./setup
```

**Windows (PowerShell):**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
.\setup.ps1
```

The setup script detects which AI agents you have installed and configures them automatically. Choose one agent or all of them.

### 3. Start asking questions

Open your agent and start using the skills. No special import needed — agents auto-load their config files.

```bash
# Claude Code (auto-discovers .claude/instructions.md)
claude "How do I escape the iOS sandbox on version 26?"

# OpenCode (auto-loads opencode.json)
opencode "Load ios-kernel-exploit skill and analyze this kernel panic"

# Cursor / Windsurf (open this directory as a workspace)
cursor .    # then: @skills/ios-kernel-exploit.md
```

### 4. Use options to control output

Options go before your prompt. They stack. They work with any agent.

```bash
--adhd "How do I escape the sandbox?"      # Short, numbered steps, no fluff
--verbose "Explain the DarkSword exploit"   # Every offset, every caveat
--new --verbose "Audit this repo"           # Full audit with ranked findings
--bug "Check for thread-safety issues"      # Scan → write foundbugs.md → then --fix
--cash "What should I build next?"          # Money-focused ideas + career paths
```

### Manual setup (if you skip the setup script)

<details>
<summary>Click to expand manual instructions</summary>

#### Claude Code
```bash
claude                          # Auto-discovers .claude/instructions.md
```

#### Cursor / Windsurf
Open this directory as a workspace. Reference skills inline: `@skills/ios-kernel-exploit.md`

#### OpenAI Codex
```bash
codex                           # Auto-discovers .codex.md
```

#### OpenCode
```bash
opencode                        # Auto-loads opencode.json
```

#### Gemini / Qwen / Kimi
Import the config file from the project root into the agent's plugin settings.

</details>

---

## Options

Options go before your prompt. They stack. They modify how the agent responds, regardless of which skill is loaded.

```
--adhd "How do I escape the sandbox on iOS 26?"
--new --verbose "Audit this repo for vulnerabilities"
--bug "Check for thread-safety issues"
--cash --thinking "What should I build next?"
```

|       |                        |
|-------|------------------------|
| `--adhd`     | Action-first output. Numbered steps. No preamble. No fluff. |
| `--verbose`  | Maximum detail. Full offsets, full code, all caveats, all alternatives. |
| `--thinking` | Deep chain-of-thought. 3+ hypotheses evaluated. Higher token budget. |
| `--new`      | Audit mode — scan target, find bugs, recommend skills, rank findings. |
| `--idea`     | Project/feature ideas. Empty dir → project ideas. Code → feature ideas. |
| `--bug`      | Bug checker. 10 bug classes. Writes `foundbugs.md`. Chains to `--fix`. |
| `--fix`      | Bug fixer. Critical first. Asks before each severity tier. |
| `--cash`     | Money-focused ideas + career paths + freelancing opportunities. |

Options are processed before skill routing. `--bug` chains to `--fix`. Say `stop options` to clear.

---

## Skills

10 specialized skill modules with YAML frontmatter, trigger words, cross-reference rules, and `research_first` directives. The master `SKILL.md` routes questions and enforces that agents research external sources before answering.

| Skill | Tokens | Covers |
|-------|--------|--------|
| `ios-kernel-exploit` | 8K | PAC, SMR, IOSurface OOB, socket spray, Checkm8 offsets, KASLR |
| `ios-sandbox-escape` | 8K | MAC framework, extension patching, SSV, vnode swap, TCC, MIG bypass |
| `ios-security-pentesting` | 9K | Frida, AMFI, CoreTrust, bug bounty, SSL pinning, jailbreak detection |
| `ios-misc-tooling` | 11K | Theos, ldid, deploy, kernelcache, libimobiledevice, device management |
| `ios-bootchain-exploit` | 10K | Checkm8, SecureROM, IMG4, PWN DFU, trust cache, DeviceTree, hacktivation |
| `ios-code-injection` | 9K | ROP chains, dylib injection, shellcode, PAC forging, remote threads |
| `ios-webkit-exploit` | 9K | JSC type confusion, JIT bypass, OffscreenCanvas dlopen, GPU IPC escape |
| `ios-puaf-exploit` | 8K | PhysPuppet, Smith, Landa, kfd library, page table exploitation |
| `ios-coretrust-bypass` | 8K | CoreTrust, fastPathSign, CMS signature, perma-sign, TrollStore |
| `ios-research-methodology` | 8K | Audit protocol, 10 bug classes, 5-stage learning path, tool references |

All kernel struct offsets are centralized in `offsets.yaml` — the canonical source of truth. Skills reference it instead of hardcoding values.

### How skills work together

Skills cross-reference each other. When a conversation drifts, the active skill tells the agent to load the neighbor:

```
ios-kernel-exploit ←→ ios-sandbox-escape     (sandbox escape needs kernel R/W)
ios-kernel-exploit ←→ ios-bootchain-exploit   (Checkm8 gives kernel access)
ios-webkit-exploit →  ios-kernel-exploit      (WebKit chain leads to kernel)
ios-puaf-exploit   ←→ ios-kernel-exploit      (alternative K-R/W primitive)
ios-code-injection ←→ ios-bootchain-exploit   (ROP needs trust cache/AMFI)
ios-coretrust      ←→ ios-security-pentesting (CoreTrust is a security domain)
ios-misc-tooling   ←→ ALL                     (tooling touches everything)
ios-research       ←→ ALL                     (methodology is universal)
```

---

## Projects — Exploit Technique Coverage

| Project | Author | Technique | iOS | K-R/W | Sandbox | SSV |
|---------|--------|-----------|-----|-------|---------|-----|
| W0lfSword | kaffeindecaf | DarkSword + ext-patch + vnode | 15–26 | Yes | Yes | Yes |
| bad_query | forcequit | Container path traversal | 26–27 | --- | Yes | --- |
| darksword-kexploit | opa334 | DarkSword CLI | 15–26 | Yes | --- | --- |
| DarkSword-RCE | htimesnine | WebKit → GPU → Kernel | 18.4 | Yes | Yes | --- |
| excalibur | 34306 | DarkSword + Remote ROP | multi | Yes | Yes | Yes |
| FilzaJailedDS | 34306 | Original tweak + exploit | 15–17 | Yes | Yes | Yes |
| kfd | felix-pb | PUAF (PhysPuppet/Smith/Landa) | 16.x | Yes | --- | --- |
| opainject | opa334 | ROP dylib injection | 14–17 | --- | --- | --- |
| TrollStore | opa334 | CoreTrust bypass | 14–17 | --- | --- | --- |
| usbliter8-fun | wh1te4ever | Checkm8 bootchain | 15.6+27 | Yes | Yes | Yes |
| usbliter8-fun2 | 34306 | Checkm8 jailbreak | 27.0b2 | Yes | Yes | Yes |

---

## Research Findings

From `docs/researchdeepseek.md` — 31 findings from a systematic audit:

| Severity | Count | Examples |
|----------|-------|----------|
| HIGH | 8 | Thread-safety race in kread, dangling pointers, offset validation gap, mutex deadlock |
| MEDIUM | 14 | Macro overflow, no retry loops, hardcoded smr_base, kcall verification missing |
| LOW | 9 | khexdump leak, offset duplicates, socket exhaustion threshold, TweakLog racing |

**Fixes shipped:** W0lfSword (7), bad_query (3), darksword-kexploit (2)

---

## Setup

### Prerequisites

- **Git** 2.40+
- **Python** 3.10+ — for XPF, TSS proxy, activation scripts
- **clang + ldid** — if building exploits locally
- **Theos** — optional, for tweak compilation
- **libimobiledevice** — optional, for USB device interaction

### Supported agents

| Agent | Config File | Auto-load |
|-------|------------|-----------|
| Claude Code | `.claude/instructions.md` | Yes |
| Cursor | `.cursorrules` | Yes |
| OpenAI Codex | `.codex.md` | Yes |
| OpenCode | `opencode.json` | Yes |
| Windsurf | `.windsurfrules` | Yes |
| GitHub Copilot | `.github/copilot-instructions.md` | Yes |
| Google Gemini | `GEMINI.md` | Manual import |
| Alibaba Qwen | `qwen-extension.json` | Manual import |
| Moonshot Kimi | `kimi.plugin.json` | Manual import |

---

## Contributing

Add a new project:
```bash
cd projects/
git submodule add https://github.com/author/new-exploit.git
```

Add a new skill — create a markdown file in `skills/` with YAML frontmatter, trigger words, cross-reference rules, and `research_first: true`. Register it in `SKILL.md`, `opencode.json`, and the agent config files.

---

## Credits

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

Additional credits: Google TAG, Linus Henze, @alfiecg_dev, CrazyMind90, khanhduytran0, tihmstar, m1stadev/doronz88, Lakr233, Duy Tran.

---

## External Resources

[Apple XNU](https://github.com/apple-oss-distributions/xnu) · [Apple KDK](https://developer.apple.com/download/all/?q=kernel) · [Theos](https://github.com/theos/theos) · [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice) · [Frida](https://frida.re) · [Objection](https://github.com/sensepost/objection) · [IPSW](https://ipsw.me) · [The iPhone Wiki](https://www.theiphonewiki.com)

---

*Curated by [kaffeindecaf](https://github.com/kaffeindecaf) · August 2026 · [MIT](LICENSE)*
