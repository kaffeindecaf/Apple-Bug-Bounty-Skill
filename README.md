# Apple-Bug-Bounty-Skill

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A knowledge base for iOS exploit development, packaged as markdown skills that AI coding agents load automatically. Ten modules: kernel exploitation, sandbox escapes, the bootchain, WebKit, code injection, CoreTrust, and the research methodology that ties it together.

It grew out of a full audit of the W0lfSword exploit chain and ten reference repos, done in August 2026. The 31 findings from that audit live in `docs/researchdeepseek.md`; the fixes landed in the projects themselves. What's left here is what an agent actually needs to answer iOS exploit questions without making up offsets.

Works with: Claude Code · Cursor · OpenAI Codex · OpenCode · Windsurf · GitHub Copilot · Gemini · Qwen · Kimi

## Contents

- [Quick start](#quick-start)
- [Options](#options)
- [Skills](#skills)
- [Reference projects](#reference-projects)
- [Research findings](#research-findings)
- [Requirements](#requirements)
- [Contributing](#contributing)
- [Credits](#credits)
- [External resources](#external-resources)

## Quick start

### Clone it

```bash
git clone https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill.git
cd Apple-Bug-Bounty-Skill
```

### Run the setup script

**Linux / macOS:**

```bash
./setup
```

**Windows (PowerShell):**

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
.\setup.ps1
```

The script looks at which agents you already have installed and wires up their config files. Pick one, or all of them.

### Ask questions

There's nothing to import. Open your agent and go:

```bash
# Claude Code (auto-discovers .claude/instructions.md)
claude "How do I escape the iOS sandbox on version 26?"

# OpenCode (skills are symlinked into ~/.config/opencode/skills, so they work in every project)
opencode "Load ios-kernel-exploit skill and analyze this kernel panic"

# Cursor / Windsurf (open this directory as a workspace)
cursor .    # then: @skills/ios-kernel-exploit.md
```

### Flags

Flags go before your prompt and they stack:

```bash
--adhd "How do I escape the sandbox?"      # short numbered steps, no fluff
--verbose "Explain the DarkSword exploit"   # every offset, every caveat
--new --verbose "Audit this repo"           # full audit with ranked findings
--bug "Check for thread-safety issues"      # scan, write foundbugs.md, then --fix
--cash "What should I build next?"          # money-focused ideas and career paths
```

The full list is in the [Options](#options) section.

### Manual setup

<details>
<summary>If you'd rather not run the script</summary>

#### Claude Code

```bash
claude    # auto-discovers .claude/instructions.md
```

#### Cursor / Windsurf

Open this directory as a workspace and reference skills inline: `@skills/ios-kernel-exploit.md`

#### OpenAI Codex

```bash
codex    # auto-discovers .codex.md
```

#### OpenCode

```bash
# the setup script symlinks every skill into ~/.config/opencode/skills/ (global)
# and .opencode/skills/ (project-local)
opencode    # skills show up in any project
```

#### Gemini / Qwen / Kimi

Import the config file from the project root into the agent's plugin settings.

</details>

### Uninstall

**Linux / macOS:**

```bash
./uninstall
```

**Windows (PowerShell):**

```powershell
.\uninstall.ps1
```

Removes the OpenCode symlinks, the agent config files the setup script created, and (with confirmation) the installed copy at `~/.apple-bug-bounty-skill`.

## Options

Flags go before your prompt and stack. They change how the agent responds no matter which skill ends up loaded.

| flag | what it does |
|------|--------------|
| `--adhd` | action-first output, numbered steps, no preamble, no fluff |
| `--verbose` | maximum detail: full offsets, full code, all caveats and alternatives |
| `--thinking` | deeper reasoning, 3+ hypotheses evaluated, higher token budget |
| `--new` | audit mode: scan a target, find bugs, recommend skills, rank findings |
| `--idea` | project or feature ideas. empty dir → project ideas, code → feature ideas |
| `--bug` | bug checker, 10 bug classes, writes `foundbugs.md` |
| `--fix` | bug fixer. critical first, asks before each severity tier |
| `--cash` | money-focused ideas, career paths, freelancing opportunities |

Options are processed before skill routing. `--bug` hands off to `--fix` once the scan is done. Say `stop options` to clear them.

## Skills

Ten modules, each with YAML frontmatter, trigger words, cross-reference rules, and a `research_first` directive. The master `SKILL.md` routes questions and makes sure the agent actually reads external sources before answering.

| skill | tokens | covers |
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
| `ios-research-methodology` | 8K | audit protocol, 10 bug classes, 5-stage learning path, tool references |

Kernel struct offsets live in one file, `offsets.yaml`. Skills reference it instead of hardcoding values, so a new iOS version means updating one file, not ten skills.

### How the skills fit together

The skills cross-reference each other. When a conversation drifts into a neighboring topic, the active skill tells the agent to load the one that covers it:

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

## Reference projects

The skills are built from these. The table shows which technique each project uses, which iOS versions it targets, and whether it gets kernel read/write, sandbox escape, or SSV bypass.

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

## Research findings

31 findings from the systematic audit, from `docs/researchdeepseek.md`:

| Severity | Count | Examples |
|----------|-------|----------|
| HIGH | 8 | Thread-safety race in kread, dangling pointers, offset validation gap, mutex deadlock |
| MEDIUM | 14 | Macro overflow, no retry loops, hardcoded smr_base, kcall verification missing |
| LOW | 9 | khexdump leak, offset duplicates, socket exhaustion threshold, TweakLog racing |

**Fixes shipped:** W0lfSword (7), bad_query (3), darksword-kexploit (2)

## Requirements

- Git 2.40+
- Python 3.10+ — for XPF, the TSS proxy, and the activation scripts
- clang + ldid — only if you build exploits locally
- Theos — optional, for compiling tweaks
- libimobiledevice — optional, for USB device interaction

### Supported agents

| Agent | Config file | Auto-load |
|-------|-------------|-----------|
| Claude Code | `.claude/instructions.md` | Yes |
| Cursor | `.cursorrules` | Yes |
| OpenAI Codex | `.codex.md` | Yes |
| OpenCode | `opencode.json` + skills symlinked into `~/.config/opencode/skills/` | Yes (global, any project) |
| Windsurf | `.windsurfrules` | Yes |
| GitHub Copilot | `.github/copilot-instructions.md` | Yes |
| Google Gemini | `GEMINI.md` | Manual import |
| Alibaba Qwen | `qwen-extension.json` | Manual import |
| Moonshot Kimi | `kimi.plugin.json` | Manual import |

## Contributing

**New project:** drop it under `projects/`. The ones in there now are plain vendored copies, so a clone is enough:

```bash
cd projects/
git clone https://github.com/author/new-exploit.git
```

If you'd rather keep it linked to upstream, `git submodule add` works too.

**New skill:** create a markdown file in `skills/` with YAML frontmatter (`name` and `description` are required for OpenCode compatibility), trigger words, cross-reference rules, and `research_first: true`. Then register it in `SKILL.md`, add it to the agent config files, and re-run `./setup` to regenerate the OpenCode symlinks.

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

Additional credit to: Google TAG, Linus Henze, @alfiecg_dev, CrazyMind90, khanhduytran0, tihmstar, m1stadev/doronz88, Lakr233, Duy Tran.

## External resources

[Apple XNU](https://github.com/apple-oss-distributions/xnu) · [Apple KDK](https://developer.apple.com/download/all/?q=kernel) · [Theos](https://github.com/theos/theos) · [libimobiledevice](https://github.com/libimobiledevice/libimobiledevice) · [Frida](https://frida.re) · [Objection](https://github.com/sensepost/objection) · [IPSW](https://ipsw.me) · [The iPhone Wiki](https://www.theiphonewiki.com)

---

Built and maintained by [kaffeindecaf](https://github.com/kaffeindecaf) · August 2026 · [MIT](LICENSE)
