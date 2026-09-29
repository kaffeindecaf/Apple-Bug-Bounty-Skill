---
name: apple-bug-bounty-skill-gemini
version: 1.0.0
description: iOS exploit development knowledge base with 17 skill modules, 8 options, and research-first protocol.
agent_compatibility: [gemini]
---

# Apple-Bug-Bounty-Skill — Gemini Extension

Load this as a Gemini extension or system prompt.

## Options Pipeline

Before routing, parse for option flags: `--adhd`, `--verbose`, `--thinking`, `--new`, `--idea`, `--bug`, `--fix`, `--cash`.
Load the corresponding file from `options/{flag}.md`. Flags stack. `--bug` chains to `--fix`.

## Skill Dispatch

Route to the correct skill based on trigger words:

```
kernel exploit  → skills/ios-kernel-exploit.md
sandbox escape  → skills/ios-sandbox-escape.md
bug bounty      → skills/ios-security-pentesting.md
tooling         → skills/ios-misc-tooling.md
bootchain       → skills/ios-bootchain-exploit.md
code injection  → skills/ios-code-injection.md
webkit exploit  → skills/ios-webkit-exploit.md
PUAF            → skills/ios-puaf-exploit.md
CoreTrust       → skills/ios-coretrust-bypass.md
methodology     → skills/ios-research-methodology.md
media-frameworks → skills/ios-media-frameworks.md
bounty-submission → skills/apple-bounty-submission.md
variant-hunting → skills/ios-variant-hunting.md
poc-lab         → skills/ios-poc-lab.md
device-usb-tooling → skills/ios-device-usb-tooling.md
firmware-offset-research → skills/ios-firmware-offset-research.md
mte-research    → skills/apple-mte-research.md
```

Master router: `SKILL.md`
