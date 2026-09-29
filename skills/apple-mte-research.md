---
name: apple-mte-research
description: "Use for Apple Memory Integrity Enforcement (MIE/MTE) research: A19/M5 tag storage, EMTE, XZone typed allocators, bypass classes, field crash signatures."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 4096
covers: [MIE, EMTE, memory tagging, A19/t8150, M5/t8142, XZone, SPTM, tag storage, bypass classes, field crashes]
learns_from:
  - projects/W0lfSword
platforms: [A19/t8150 iOS 26-27, M5/t8142 macOS, arm64e]
triggers:
  - "apple mte"
  - "mie"
  - "memory integrity enforcement"
  - "memory tagging"
  - "a19"
  - "t8150"
  - "emte"
  - "xzone"
  - "tag storage"
  - "mte bypass"
  - "checked-allocations"
related_skills:
  - ios-kernel-exploit
  - ios-research-methodology
  - ios-firmware-offset-research
cross_reference_rules:
  - Kernel primitives that MIE hardens → load ios-kernel-exploit
  - A19 kernelcache/offset work → load ios-firmware-offset-research
  - Structuring a research program → load ios-research-methodology
references:
  - skills/references/apple-mte-research/mte-key-facts.md
  - skills/references/apple-mte-research/2026-sweep-and-conventions.md
research_first: true
---

# Apple MTE Research

> **Skill type:** repo + domain research workflow
> **Repo:** Apple-MTE-Research (kaffeindecaf/Apple-MTE-Research) (kaffeindecaf/Apple-MTE-Research on GitHub)
> **Status:** offline-first, no A19 hardware owned (SE2 A13 + iPhone 14 A15 only, no MTE)

## When to use

Use when the user says "work on Apple MTE Research", or any task touching
MIE/EMTE/tag storage/A19 silicon/XZone. The repo is the knowledge base for
Apple's Memory Integrity Enforcement program; this skill is the operating
manual for it.

## Repo layout

    README.md          doc index table (the book's front page)
    checklist.md       tiered work queue: T0 done, T1 done, T2-T6 open, T7 done
    graph.md           knowledge graph nodes + edges (15 nodes, ~60 edges)
    docs/01-11         the book: mte-basics, emte, apple-mie, xnu-mte,
                       allocators, a19-hardware, attack-surface,
                       research-methods, mte-bugs-field, exploit-examples,
                       t8150-kernelcache (offline A19 kernel numbers)
    resources/links.md all sources tagged S1..S67 (S52+ = 2026 exploit/CVE
                       sweep, S67 = A19 kernelcache; recipe in
                       references/2026-sweep-and-conventions.md)
    scripts/           graph.py + the contribution tools (mte_device_report,
                       mte_crash_scan, mte_insn_census, kc_strings,
                       contrib_common) and scripts/tests/
    resources/papers/  offensivecon-2026-navigating-mte-landscape.pdf (local)
    scripts/graph.py   link verifier: wikilinks + relative md links

## Workflow rules

0. **Sweep recipe lives in the reference.** Before any "search github
   for exploits / new CVEs" task, read
   references/2026-sweep-and-conventions.md: the gh query set, the
   ipsw-diffs code-search trick and the Apple-advisory counting method
   are all there, with the queries that returned nothing.
1. **Checklist is the queue.** "keep working" = next open box in the
   lowest tier. Tiers: 0 bootstrap, 1 theory, 2 A19 hardware, 3 XNU
   internals, 4 novel research, 5 tooling, 6 writeups, 7 field corpus.
2. **Graph must stay intact.** Run `python3 scripts/graph.py` before any
   commit; exit 1 on dangling links. New doc = number it, add to README
   table, graph.md nodes/edges, neighbors' related-links line.
3. **Sources get S-tags.** New source = S## in resources/links.md, cite
   by tag in docs. Field bugs/crashes go S25+ with the issue URL and
   open/closed state.
4. **Links are relative markdown** (`[02-emte](02-emte.md)`), NOT
   wikilinks — GitHub renders the book only with relative links.
   graph.py accepts both, but new content must use relative links.
5. **Offline-first.** No A19 device: kernelcaches via W0lfSword
   scripts/fetch_kernelcache.py (ranged zip64 IPSW fetch), offsets via
   kernel-deltas tools/xpf-cli, KDK 26.2 kernel.development.t8142 for
   symbolicated MTE code. Corellium does NOT emulate MTE (S6).
6. **Commit + push autonomously** (user-approved pattern): human-voice
   commit messages, verify `git show --stat HEAD` after commit, push,
   then verify `git log origin/main` + gh api pushed_at.

## Docs style (user requirement)

Docs/READMEs must NOT look AI-generated: terse, lowercase-ish, hyphen
separators, no em-dashes/emojis/AI filler ("delve", "comprehensive",
"navigable network of documents"). Concrete numbers always (1/32 DRAM,
70+ processes, 15/16 catch rate). Crash entries keep the real signature
block verbatim (exception type/subtype, codes, termination reason,
region type, top stack frames).

## Key locked facts (detail: references/mte-key-facts.md)

- MIE shipped 2025-09-09 (iPhone 17/A19 + M5), EMTE (FEAT_MTE4,
  Armv8.9) synchronous mode only, + typed allocators + TCE.
- A19 = T8150 (iPhone18,1), M5 = t8142. Tag storage 1/32 DRAM at high
  PA, SPTM page type XNU_TAG_STORAGE. Tag PRNG reseeded every context
  switch (PACGA_IRG_RESEED).
- Kernel + 70+ userland processes MTE by default; third-party opt-in
  via com.apple.security.hardened-process.checked-allocations.
- iOS 26.4: DATA tagged by default, third-party soft-mode dropped,
  z_tag -> runtime zone_submap_has_tagging_enabled.

## Pitfalls

- **Diverged history on push:** this repo had web edits on origin
  (README tweaks, test.txt deletion) + a big local seed commit. Fix:
  `git fetch`, inspect both sides, `git rebase origin/main`, resolve
  conflicts keeping the real content (`git checkout --theirs <file>`
  when upstream only has placeholder README), then re-remove files the
  rebased commit re-added (git rm), commit, push. Do not force-push.
- **Wikilink conversion is one-way:** after converting a KB to relative
  links, grep for `[[` before committing; graph.py's resolve() treats
  non-.md targets (scripts/papers) as a sentinel, not dangling — the
  caller must isinstance-check str before os.path.basename (Pyright
  enforces).
- **Soft mode is not an escape hatch:** checked-allocations.soft-mode
  does NOT downgrade all fault classes (SwiftUI weak-table MTE fault on
  macOS 27 still fired under soft mode, S27).
- **Go code trips MTE:** granule-unaligned word reads (Go indexbyte,
  golang/go#59090) fault even within a page. Any vendor shipping Go
  into a tagged process hits this.
- **Field crash greps:** EXC_ARM_MTE_TAGCHECK_FAIL, Termination Reason
  MTE_FAIL code 262, SEGV_MTESERR (Android), mteState: enabled,
  "Attempted to unregister unknown __weak variable".
- **Reproducing device data is the bottleneck, not tooling.** The repo owns
  no A19 hardware; when asked to widen the corpus, point people at
  README's "Want to help?" section and the three scripts (README documents
  the exact 5-minute flow). The census tool is the best ask: contributors
  ship numbers, never Apple binaries.

## Tooling pointers

- W0lfSword: XPF source + CLI, offsets.m (has T8150 entries), usbtest,
  NDJSON .ips panic analyzer.
- kernel-deltas: kcwatch feed, t8030+t8110 watched; T8150 board is a
  Tier 5 goal (first A19 offset-delta feed).
- ABBS (Apple-Bug-Bounty-Skill): ios-* methodology skills + offsets.yaml
  (checkm8 b2/b3 correction lesson: verify block-to-version mapping).

## References

- references/mte-key-facts.md — condensed domain bank: MTE mechanics,
  MTE4 feature list, FEAT_CPA spec, P0 bypass classes, TikTag/StickyTags
  stats, Linux/Android API map, real field crash signatures, S1..S34
  source map.
