# MTE / MIE condensed domain bank

Compiled 2026-08-31 from the Apple-MTE-Research Tier 1 + Tier 7 passes.
Source tags S1..S34 refer to resources/links.md in the repo.

## MTE mechanics (S8, S20)

- 4-bit tag per 16-byte granule. Pointer tag rides in VA bits [59:56]
  (TBI). 15 usable values (0xF canonical in standard MTE).
- Tag storage ~3% of DRAM (Apple: exactly 1/32). Hardware compares
  pointer tag vs memory tag on every access; mismatch = tag check fault.
- Instructions: IRG (random tag), ADDG/SUBG, GMI, LDG/STG, STZG,
  LDGM/STGM, ST2G/STZ2G.
- Modes: sync (fault at instruction, precise), async (deferred, per-core
  flag), asymmetric (Armv8.7: sync reads / async writes). Apple: sync
  only, explicitly refuses async (S1).
- Stack/globals: stack tagged via compiler; globals/BSS NOT covered by
  standard MTE — the hole EMTE canonical checking closes.

## MTE4 / EMTE feature set (Armv8.9, FEAT_MTE4) (S5, S9, S22)

- Canonical tag checking: tagged pointer cannot access untagged memory
  without knowing the tag. Apple's headline feature.
- Tag permission: STG/LDG denied through untagged PTEs.
- Store-only tag checking (performance mode; Apple does not use in prod).
- Enhanced fault reporting (all non-address bits on fault).
- Apple uses: canonical checking + sync only + tag permission via PTE.

## FEAT_CPA (checked pointer arithmetic) (S9)

- CPA instructions: normal pointer arithmetic + overflow check in MSBs.
- Armv9.4: optional. Armv9.5: mandatory. Detect via ID_AA64ISAR3_EL1.CPA.
- FEAT_CPA2 extends it. A19 presence unknown — check kernelcache
  feature regs (Tier 5 tooling) or on-device [HW].

## P0 "MTE As Implemented" findings (S12, Pixel-class silicon)

Bypass classes: known-tag (learn/forge tags -> invalid access looks
valid) and unknown-tag (implementation limits let exploit proceed
despite wrong tags).

Hardware: no additional speculative side channel found for tag-check
success/failure on their test silicon; MTE does NOT block Spectre
(speculative wrong-tag loads still leak).

Async-mode weaknesses (why Apple requires sync):
1. Syscall-arg accesses unchecked in async mode.
2. Sync mode turns bad user pointers into EFAULT = oracle (P0
   software_issue_2.c).
3. SIGSEGV catchable -> corruptible signal handler (Breakpad/Crashpad)
   disables async MTE process-wide (duktape demo, 0.076 ms bypass).
4. Multi-threaded coercion: another thread does post-fault work before
   faulting thread hits kernel boundary. ~0.2 ms exploit window at 95%
   reliability (CONFIG_HZ_250, 4 ms timer).

Kernel problems: TCR_ELx.TCMA1 makes tag 0b1111 match-all (forgeable
privileged tag); TFSR_EL1 direct access lets kernel clear own flags;
DMA + non-MTE coprocessors bypass checks; pointer-equality leaks (kcmp,
fuse_lock_owner_id, epoll_fdinfo); TYPESAFE_BY_RCU exempt by design.

## Speculative primitives (S13, S14)

- TikTag: speculative gadgets leak MTE tags from arbitrary addresses.
  >95% success in <4 s, demonstrated vs Chrome + Linux kernel.
- StickyTags: deterministic round-robin tags by size class, 4% overhead
  vs 20.2% Scudo+MemTagSanitizer; contention-based side channel reveals
  tag-check success/failure without reading the tag.
- Apple counters (S5, untested on A19): side-channel-resistant SoC,
  PACGA_IRG_RESEED tag PRNG rekey every context switch, SPTM-guarded
  tag storage (XNU_TAG_STORAGE page type).

## Linux / Android API map (S10, S11)

- Linux: HWCAP2_MTE; PROT_MTE (0x20) on mmap/mprotect (anonymous +
  tmpfs/memfd only, not clearable); prctl PR_SET_TAGGED_ADDR_CTRL (55):
  PR_TAGGED_ADDR_ENABLE, PR_MTE_TCF_NONE/SYNC/ASYNC, PR_MTE_TAG_MASK
  0xfffe; PSTATE.TCO per-thread disable; per-CPU preferred mode via
  sysfs mte_tcf_preferred; execve resets all; PTRACE_PEEK/POKEMTETAGS;
  core dumps PT_AARCH64_MEMTAG_MTE (p_filesz = p_memsz/32, 4K page =
  128 bytes).
- Android: memtag_heap sanitize flag (+diag for sync); system property
  arm64.memtag.process.<basename>; MEMTAG_OPTIONS env; manifest
  android:memtagMode; mallopt M_MEMTAG_TUNING_BUFFER_OVERFLOW (adjacent
  deterministic) vs UAF (random, ~93%); kernel CONFIG_KASAN_HW_TAGS,
  kasan.mode sync/async, kasan.fault report/panic.
- Apple replaces all of this: entitlements + VM_FLAGS_MTE (no CoW, tags
  stripped on inheritance/OOL mach messages).

## Field crash signatures (S25..S34)

- iOS/macOS: EXC_ARM_MTE_TAGCHECK_FAIL, Termination Reason "Namespace
  MTE_FAIL, Code 262", mteState: enabled, region MALLOC_SMALL.
- Android: signal 11 SIGSEGV code 9 SEGV_MTESERR (sync) / SEGV_MTEAERR
  (async), tagged_addr_ctrl in crash header, "Cause: [MTE]: Use After
  Free" in tombstones.
- objc console: "Attempted to unregister unknown __weak variable".
- Real cases: FuturaeKit iPhone 17e startup crash (S25, third-party
  lifetime bug only visible on A19); SwiftUI weak-table fault macOS 27
  beta FB23066215, NOT downgraded by soft-mode (S27); Go indexbyte
  granule trip golang/go#59090 in cake_wallet + react-native libgojni
  (S28, S33); godot C# XZone trap _xzm_xzone_malloc_freelist_outlined
  (S31); ZeroTier macOS 26.1 silent launch failure, MTE-unconfirmed
  (S29); Vanadium sync MTE crash (S26); fluffychat entitlement request
  (S32); sentry-cocoa enhanced-security prep (S30).

## Source map (S1..S34)

S1 Apple MIE blog | S2 PSG | S3 Xcode docs | S4 Meet with Apple video |
S5 OffensiveCon 2026 PDF (local copy in repo) | S6 JAMF | S7 8kSec
parts 1-2 | S8 ARM MTE intro (now Android-flavored guide) | S9 Armv8.9
extension doc | S10 Linux kernel MTE doc | S11 AOSP MTE doc | S12 P0 MTE
as Implemented parts 1-3 | S13 TikTag | S14 StickyTags | S15 Steffin &
Classen SPTM/TXM/Exclaves | S16 DFF SPTM blog | S17 Wikipedia A19 |
S18 NotebookCheck A19 Pro | S19 Privacy Guides | S20 HackTricks |
S21 kalloc_type blog | S22 securitycryptographywhatever podcast |
S23 Hexacon keynote | S24 OBTS v8 | S25..S34 field bugs (see repo
links.md for URLs).

## GitHub bug-corpus search pattern

    gh api "search/issues?q=<urlencoded signature>&per_page=10" \
      --jq '.items[] | "\(.repository_url|split("/")[-1]) #\(.number) [\(.state)] \(.title)"'

Good queries: "EXC_ARM_MTE_TAGCHECK_FAIL", "MTE_FAIL",
"SEGV_MTESERR iPhone", "checked-allocations", "memory integrity
enforcement crash", "GUARD_EXC_MTE_SYNC_FAULT". Then pull full body +
comments with gh api repos/.../issues/N and /comments. Note: search
results can 404 on the guessed repo owner (e.g. "ios-sdk" is
Futurae-Technologies/ios-sdk, "fluffychat" is krille-chan/fluffychat) —
resolve via search/issues html_url before fetching.
