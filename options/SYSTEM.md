---
name: options-system
version: 2.0.0
description: Option flag pipeline for Apple-Bug-Bounty-Skill. 8 options — stackable, cross-compatible, dynamic.
---

# Options System

Options modify how the agent responds. They are declared before the prompt, as flags:

```
--adhd --verbose "Analyze this kernel panic for IOSurface race conditions"
```

Multiple options stack. Order does not matter. Options apply to whichever skill is loaded by the router.

## Available Options

| Flag | File | Effect | Chains To |
|------|------|--------|-----------|
| `--adhd` | `options/adhd.md` | ADHD-friendly output. Action first. No preamble. No fluff. | — |
| `--verbose` | `options/verbose.md` | Full detail. All offsets. All caveats. All alternatives. | — |
| `--thinking` | `options/thinking.md` | Deep chain-of-thought. Higher token budget. Explores multiple paths. | — |
| `--new` | `options/new.md` | Audit mode. Analyzes target, finds issues, recommends skills, ranks findings. | — |
| `--idea` | `options/idea.md` | Project/feature idea generator. Empty folders → project ideas. Existing code → feature ideas. | — |
| `--bug` | `options/bug.md` | Bug checker. Scans using 10 bug classes, writes to foundbugs.md. | → `--fix` |
| `--fix` | `options/fix.md` | Bug fixer. Fixes bugs from foundbugs.md one at a time, critical first. | ← `--bug` |
| `--cash` | `options/cash.md` | Money-focused idea generator. Same as --idea but ranked by earning potential. | — |

## How They Work

1. Agent parses the user's message for option flags
2. If flags are present, agent loads the corresponding option file(s)
3. Option rules modify the agent's output behavior
4. Agent routes the remaining prompt to the correct skill
5. Skill answers with the option constraints applied

## Chained Options

`--bug` and `--fix` are chained:

```
--bug "Scan this repo"        → Writes foundbugs.md → "Run --fix next"
--fix                         → Reads foundbugs.md → Fixes CRITICAL → "Continue with HIGH?"
--fix                         → Fixes HIGH → "Continue with MEDIUM?"
```

## Stacking Examples

```
--adhd --idea                 → Project ideas in ADHD format (short, action-first)
--new --verbose "audit this"  → Full audit with maximum detail
--bug --verbose "find bugs"   → Bug scan with comprehensive descriptions in foundbugs.md
--cash --thinking             → Money ideas with deep chain-of-thought for each
--adhd --bug                  → Bug scan with short, numbered bug descriptions
```

## Turn Off

Say `stop options` or `normal mode` to clear all options. Say `stop adhd` to turn off just ADHD mode.
