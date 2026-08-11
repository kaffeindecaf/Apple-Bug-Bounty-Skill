---
name: options-system
version: 1.0.0
description: Option flag pipeline for Apple-Bug-Bounty-Skill. Options are applied BEFORE skill routing. Stackable — combine multiple flags. Options persist for the session unless turned off.
---

# Options System

Options modify how the agent responds. They are declared before the prompt, as flags:

```
--adhd --verbose "Analyze this kernel panic for IOSurface race conditions"
```

Multiple options stack. Order does not matter. Options apply to whichever skill is loaded by the router.

## Available Options

| Flag | File | Effect |
|------|------|--------|
| `--adhd` | `options/adhd.md` | ADHD-friendly output. Action first. No preamble. No fluff. |
| `--verbose` | `options/verbose.md` | Full detail. All offsets. All caveats. All alternatives. |
| `--thinking` | `options/thinking.md` | Deep chain-of-thought. Higher token budget. Explores multiple paths before answering. |
| `--new` | `options/new.md` | Audit mode. Analyzes the target, finds issues, recommends skills, ranks findings critical-to-low. |

## How They Work

1. Agent parses the user's message for option flags
2. If flags are present, agent loads the corresponding option file(s)
3. Option rules modify the agent's output behavior
4. Agent routes the remaining prompt to the correct skill
5. Skill answers with the option constraints applied

## Stacking Examples

```
--adhd --thinking "Find the root cause of this kernel panic at 0xFFFFFFDC00000000"
→ ADHD output style + deep chain-of-thought analysis. Short answer, but deeply reasoned.

--new --verbose "Review this repo for vulnerabilities"
→ Audit mode with full detail. Lists all findings ranked, with exhaustive context.

--adhd "How do I escape the sandbox on iOS 26?"
→ Short, numbered steps. No preamble. No closing pleasantries.
```

## Turn Off

Say `stop options` or `normal mode` to clear all options. Say `stop adhd` to turn off just ADHD mode.
