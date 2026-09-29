---
name: ios-poc-lab
description: "Use for testing found iOS bugs as host-side PoCs (Linux/macOS, no device): Apple open-source forks, ASAN harnesses, honest WORKS/NEGATIVE/BLOCKED verdicts."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 4096
covers: [host-side PoC, ASAN harness, apple-oss-distributions, libxml2 fork audit, falsification, bug verification]
learns_from:
  - projects/W0lfSword
platforms: [Linux host, macOS host]
triggers:
  - "poc lab"
  - "host-side poc"
  - "reproduce without device"
  - "asan harness"
  - "libxml2 apple fork"
  - "verify a bug"
  - "negative result"
  - "falsify"
related_skills:
  - ios-research-methodology
  - ios-media-frameworks
  - ios-variant-hunting
  - ios-device-usb-tooling
cross_reference_rules:
  - Framework/parser targets → load ios-media-frameworks
  - New-bug hunting methodology → load ios-research-methodology
  - Sibling-of-a-fix hunts → load ios-variant-hunting
  - Needs real-device confirmation → load ios-device-usb-tooling
research_first: true
---

# iOS PoC Lab (host-side testing without a device)

Turn found-but-unimplemented bugs (a roadmap entry, a tracker line) into tested
PoCs on a Linux host. No device required. Verdicts are honest: WORKS (reproduced),
NEGATIVE (tried, no bug), BLOCKED (host limitation), NEEDS-DEVICE/CACHE, PATCHED.

## Workflow

1. Clone the target source once into a cache (`.w0lfsword/poclab/<name>`),
   reuse it on re-runs. Shallow clones are fine (`--depth 1`).
2. Build. Apple-oss-distributions forks often need Linux patches:
   - missing `<stdint.h>` includes (e.g. Apple's libxml2 uri.c)
   - Darwin-only symbols (e.g. `linkedOnOrAfterFall2022OSVersions` in
     xpath.c) — stub them `#if !defined(__APPLE__) { return 1; }`
   - Apple Xcode-only implicit includes from their pregenerated config.h
3. Write a small harness against the built library (compile with
   `-fsanitize=address,undefined`, link `-lm`).
4. Run, capture output, grep for the ASAN signature, print the verdict.

## Pitfalls

- **`set -euo pipefail` turns an expected ASAN crash into a pipeline
  failure** — the harness exits non-zero (ASAN abort), so
  `if ./harness | grep -q signature` evaluates false. Capture first:
  `out=$(./harness 2>&1 || true)` then `echo "$out" | grep -q`.
- **Apple backports selectively — a version gap is not a vulnerability.**
  Apple's forks (e.g. libxml2 at 2.9.13 vs upstream 2.15.0) carry many
  upstream fixes backported. Before claiming "upstream fix X is missing":
  verify the vulnerable code path actually exists in Apple's tree. Real
  case: upstream's nextCatalog NULL-deref fix (c632489) guards a dedup
  loop added after 2.9.13 — Apple's fork never had the loop, so the bug
  does not exist there. Check `git log -S <string>` upstream to find when
  a code path entered.
- **Recursion/range guards can already cover a shape you think is new.**
  Test the actual malformed inputs; both forks handled missing/empty
  catalog attributes cleanly.
- **Build dependency chains are real blockers**: mDNSResponder needs
  mbedTLS (not vendored; mbedtls source needs its own submodules; no
  passwordless sudo for libmbedtls-dev). Notate as BLOCKED with the exact
  dep, don't fight it.
- **Verify what you claim**: run both forks/binaries, don't assume from a
  diff. Negative results with evidence beat positive claims from code
  reading.

## Integration

The W0lfSword CLI exposes the lab: `./W0lfSword poclab list` (catalog with
status) and `./W0lfSword poclab test <id>` (runs scripts/poclab_test_*.sh).
Docs per bug: research/poclab.md. To add a concept: row in
`poclab_concepts()` in the W0lfSword script + a `scripts/poclab_test_*.sh`
+ doc entry.

## Verification checklist

```bash
bash -n W0lfSword scripts/poclab_test_*.sh
./W0lfSword poclab list          # renders the table
./W0lfSword poclab test alac     # WORKS verdicts (ASAN signatures)
./W0lfSword audit                # AUDIT PASSED
```
