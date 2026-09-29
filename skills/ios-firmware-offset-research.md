---
name: ios-firmware-offset-research
description: "Use for iOS boot-chain offset discovery and IPSW/kernelcache work: extract, fingerprint, migrate offsets across builds and devices, XPF resolution, kcwatch feeds."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 4096
covers: [IPSW extraction, im4p, kernelcache, iBSS/iBEC/TXM, offset migration, fingerprinting, XPF, kcwatch, fileset KC]
learns_from:
  - projects/usbliter8-fun
  - projects/usbliter8-fun2
  - projects/kfd
  - projects/darksword-kexploit
platforms: [Linux host, macOS host, iOS 15.0-27.0, A12-A19, t8030/t8110/t8150]
triggers:
  - "ipsw"
  - "kernelcache"
  - "offset migration"
  - "im4p"
  - "ibss"
  - "ibec"
  - "txm"
  - "fingerprint offset"
  - "xpf"
  - "kcwatch"
  - "fileset"
  - "beta offsets"
  - "usbliter8 profile"
related_skills:
  - ios-bootchain-exploit
  - ios-kernel-exploit
  - ios-misc-tooling
  - ios-research-methodology
cross_reference_rules:
  - Boot-chain exploitation with those offsets → load ios-bootchain-exploit
  - Kernel R/W that consumes the offsets → load ios-kernel-exploit
  - Build/deploy the CFW → load ios-misc-tooling
references:
  - skills/references/ios-firmware-offset-research/ipsw-extraction-linux.md
  - skills/references/ios-firmware-offset-research/struct-offset-from-kernelcache.md
  - skills/references/ios-firmware-offset-research/ranged-kernelcache-fetch.md
  - skills/references/ios-firmware-offset-research/host-side-xpf-diff.md
  - skills/references/ios-firmware-offset-research/kernelcache-binary-diffing.md
  - skills/references/ios-firmware-offset-research/xpf-finder-authoring.md
  - skills/references/ios-firmware-offset-research/kcwatch-feed-pipeline.md
  - skills/references/ios-firmware-offset-research/kext-xref-fileset-kc.md
research_first: true
---

# iOS Firmware & Offset Research (A12/A13, usbliter8 era)

Workflow for the user's usbliter8-arctic ecosystem: install RP2350 exploit
firmware, extract IPSW boot-chain components, and discover/migrate patch
offsets for iOS builds. Covers `usbliter8-arctic` (tooling +
profiles), `research/` (workspace), `Apple-Bug-Bounty-Skill` (canonical
offsets.yaml), `W0lfSword` (kernel struct offsets).

## When to use

- A new iOS beta ships and offsets must be re-discovered (migrate)
- A device other than iPhone 11 Pro (iPhone12,3) needs a profile (propagate)
- Any task touching `.ipsw` files, im4p payloads, kernelcache, iBSS/iBEC/TXM
- Reviewing/validating offset YAML profiles (`offsets/*.yaml`)

## Core concepts

- **IPSW = zip.** Component paths use the **board**, not the model
  (`Firmware/dfu/iBSS.n104ap.RELEASE.im4p` for iPhone 11; board table in
  `research/README.md`).
- **Unencrypted** (extractable without keys): iBSS, iBEC, TXM im4p payloads.
- **Encrypted** (need IV+Key from theiphonewiki per device+build):
  `kernelcache.release.<board>` and the `048-*.dmg` RestoreRamDisk.
- **Kernelcache is SoC-shared per build**: `kernelcache.release.t8030` is the
  same binary for every A13 device of that build → kernel/daemon/ramdisk
  offsets propagate across same-SoC devices; iBSS/iBEC/TXM are per-device.
  **Pitfall: the IPSW zip entry name is per-BOARD, not per-SoC** — e.g.
  iPhone12,8 (D79AP, SE 2) ships `kernelcache.release.iphone12c`. Don't grep
  the central dir for `t8030`; match `kernelcache.release.*` and take the hit
  (W0lfSword scripts/fetch_kernelcache.py does this).
- **comp-dir layout** consumed by migrate/propagate:
  `research/comp-dir/<name>/{base,target}/*.raw` (ibss.raw, ibec.raw,
  txm.raw, kernelcache.raw, restoreramdisk.raw).

## Phase 1 — Install RP2350 exploit firmware

- Guided setup (`sudo ./main.py` → `1`/`h`) validates UF2 magic, downloads
  from Octopus1633 with retries, prints flash steps.
- Manual: hold BOOTSEL, plug in → `RPI-RP2` drive → copy the UF2 → auto-reboot.
  Board→UF2 mapping in `offsets/sources.yaml` (`rp2350_boards`).

## Phase 2 — Extract IPSW on Linux

**Pitfall: `tools/img4` is a macOS Mach-O binary — it does not run on Linux.**
`research/extract.sh` auto-selects the backend (system `img4` → bundled
Mach-O on macOS → `pyimg4` on Linux). On Linux:

```bash
pip install --break-system-packages pyimg4    # PEP 668 hosts
./research/extract.sh research/ipsw/<file>.ipsw "iPhone12,1_27.0b3_24A5380h" n104ap
# encrypted parts: fill research/extracted/<name>/keys.txt (see references/ipsw-extraction-linux.md)
./research/extract.sh ... --keys
```

Output: `research/extracted/<name>/` with `*.raw` + `provenance.txt`.
Everything under `research/` is **gitignored by design** (multi-GB files).

## Phase 3 — Find the offsets

| Situation | Command | Expectation |
|---|---|---|
| Same device, new beta | `profile_gen.py migrate base.yaml target.yaml --comp-dir … --auto` | ≥0.90 auto-filled; report lists REVIEW REQUIRED |
| New device, same SoC | `profile_gen.py propagate offsets/iPhone12,3_27.0b2.yaml iPhone12,1 --comp-dir …` | kernel/daemons copied; iBSS/iBEC/TXM fingerprinted ≥0.90, rest stay `pending` |
| New device, other SoC | propagate + `--force` | sub-0.90 hits → manual Ghidra/IDA review of candidates from report |
| A struct FIELD offset (nothing to fingerprint) | locate a kernel message that PRINTS the field, then read the field loads off the disassembly | verified per build/SoC before pinning — see `references/struct-offset-from-kernelcache.md` |

Cross-device search = same AArch64 fingerprint engine as migrate
(`fingerprint.py`: immediates wildcarded, capstone-verified). `--comp-dir`
only fills iBSS/iBEC/TXM; kernel is copied (shared-kernelcache assumption).

## Hard rules (never break)

1. **Never trust anything below 0.90 confidence** — wrong offset rated HIGH = brick risk.
2. Delta inference is **always LOW** (0.30).
3. Profiles with `pending: true` entries **cannot be activated**
   (`set_active_device` refuses) — unverified offsets never reach the flash path.
4. A profile leaves `research/profiles/` (marked UNVERIFIED) only after
   `device_offsets.py validate` AND an on-device flash test.
5. `propagate` refuses cross-SoC and pending-base propagation without `--force`.

## Tool map (usbliter8-arctic)

- `profile_gen.py`: `create` (sentinel profile), `propagate` (same-SoC
  expansion), `diff`, `migrate` (beta-to-beta), `coverage` (per-device status
  table), `list`. `migrate` CLI lives in `migrate.py` (`--comp-dir`,
  `--fetch`, `--auto`, `--report`).
- `device_offsets.py`: `validate`, `list`, `find` (online sources), `activate`.
- `fingerprint.py`: `mask_insn`, `build_pattern`, `search_pattern`,
  `verify_site` (capstone), `migrate_site` (confidence tiers 0.95/0.90/0.60/0.30).
- Profile YAMLs serialize offsets as **0x-hex** via `device_offsets.dump_profile_yaml`
  (hex-int representer; bools stay `true`). Plain `yaml.dump` writes decimal —
  cosmetic but violates repo convention; always use `dump_profile_yaml`.
- Tests: `python3 -m pytest tests/ -q`. Synthetic-binary fixtures
  (`_make_component` + `_name_filler` in tests/) model cross-build/cross-device
  moves; oracle table in `OffsetMigrationChecklist.md`.

## References

- `references/ipsw-extraction-linux.md` — pyimg4 CLI details, keys.txt format,
  IPSW component paths, theiphonewiki key retrieval.
- `references/struct-offset-from-kernelcache.md` — derive a struct FIELD offset
  from a kernelcache: panic-string xref, capstone/Mach-O pitfalls, the verified
  `struct zone` table, kalloc bucket size via `inpi_zone`.
- `references/ranged-kernelcache-fetch.md` — pull just the kernelcache out of a
  multi-GB IPSW over HTTP Range, plus URL discovery for any older build.
- Also in this directory: `host-side-xpf-diff.md`, `kernelcache-binary-diffing.md`,
  `xpf-finder-authoring.md`, `kcwatch-feed-pipeline.md` — host-side XPF
  resolution/diffing and the kcwatch feed.
- `references/kext-xref-fileset-kc.md` — kext-level disassembly on a fileset KC: nested
  `LC_FILESET_ENTRY` parsing, the three xref forms (bl / tagged-vmoffset pointers / arm64e
  thunks), function-start detection incl. `bti c`, capstone+rizin pitfalls, and how to read the
  `/9` magic and the `0x2bad` poison idiom (which is *not* an element bound).
