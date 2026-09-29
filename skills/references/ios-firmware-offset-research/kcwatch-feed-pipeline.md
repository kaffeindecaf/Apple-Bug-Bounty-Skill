# kcwatch feed pipeline (kaffeindecaf/kernel-deltas)

The public, cron-driven deployment of the host-side XPF diff methodology.
Repo: kaffeindecaf/kernel-deltas (public). Watches t8030 (A13, iPhone SE 2)
+ t8110 (A15, iPhone 14); t8103 (A14, iPhone 12 mini) is already defined in
the BOARDS dict but not enabled in the workflow. Daily 06:00 UTC GitHub
Actions cron auto-commits `kcwatch: feed update`.

## Two offset layers (do not confuse)

1. **Resolved set** — what the feed diffs and reports (65-66 items/build).
   Metric name strings grouped into XPFSet blocks in
   `tools/xpf-cli/xpf_patched.c` (gBaseSet, gTranslationSet, gPhysmapSet,
   gStructSet, gExtendedSet, gSandboxSet, ...). The prebuilt `xpf-cli`
   binary prints `0x... <- <name>` per item into `state/<board>/*.txt`
   dumps; kcwatch.py diffs dumps via scripts/xpf_diff.py.
2. **Offset table** — `kexploit/offsets.m`, vendored from W0lfSword
   (`cp <W0lfSword>/kexploit/offsets.m kexploit/offsets.m`). Used ONLY by
   `kcwatch verify` and the report VERDICT line. The feed tracks symbols
   without any offsets.m entry.

## Adding an offset to the feed

1. **Finder must exist first.** Finders are registered with
   `xpf_item_register(name, finder, ctx)` inside the `xpf_*_init()`
   functions of the XPF source: XPF/src/common.c (struct offsets),
   non_ppl.c (symbols), ppl.c, bad_recovery.c. That source is NOT vendored
   in kernel-deltas — only the binary + shims are. Edit/build in a
   W0lfSword checkout (build.sh compiles XPF/src + ChOma, needs clang +
   liblzfse-dev + libblocksruntime-dev), then copy the fresh binary and
   xpf_patched.c back into tools/xpf-cli/.
2. Add the metric string to the right set in xpf_patched.c (gStructSet for
   struct offsets, gExtendedSet for symbols, etc.).
3. Re-resolve cached kernelcaches:
   `tools/xpf-cli/xpf-cli .kcwatch/t8030/26.6.1-23G83.img4 > state/t8030/26.6.1-23G83.txt`
   per board and build. The IMG4s are gitignored (`.kcwatch/`, `.w0lfsword/`,
   `*.img4`); on a fresh clone re-fetch via `kcwatch poll --version <ver>`.
4. Rebuild the feed artifacts:
   `python3 scripts/regenerate_dumps.py` (reports + state from the dumps
   under .kcwatch/<board>/), then `kcwatch.py index` + `kcwatch.py atom`.
5. Commit the new dumps, reports, feed, and the rebuilt binary.

**Verify mapping**: `kcwatch verify` maps dump item `kernelStruct.<x>.<y>`
to variable `off_<x>_<y>` in offsets.m (kernelStruct.task.map ->
off_task_map). Add the var in the right version block to get verify
coverage; symbol addresses never need offsets.m entries. 0x0 XPF values are
skipped as "per-SoC, not verifiable" (thread.machine_* on fileset builds).

## Pitfalls

- **Unknown metric name prints 0x0 silently** — no error, no UNRESOLVED
  marker (that marker only appears on finder crash). Grep the XPF source
  for the exact registered name before adding it to a set.
- **per-VERSION vs per-SoC**: task.itk_space 17.x=0x300, 18.x=0x318,
  26.x=0x310 (XPF-verified on t8030 AND T8150); proc.struct_size grows +8
  per major version (0x730 -> 0x740 -> 0x748 -> 0x750); proc.p_name is
  per-board (t8030 0x470, t8110 0x488) while offsets.m 26.x still lists
  0x57d; vm_map.pmap 0x40 (T8150 26.0.1) vs 0x58 (t8030 26.6.1).
- **Adding a board** = one line in the BOARDS dict (device identifier +
  soc + label) in scripts/kcwatch.py PLUS loop entries in
  .github/workflows/watch.yml (restore state, poll, sync state/reports).
- **Push gotcha**: the cron auto-commits upstream, so pushes get rejected
  ("fetch first") regularly. `git fetch origin && git rebase origin/main`;
  unstaged changes (e.g. a mode-only 644->755 diff) block the rebase —
  `git stash` -> rebase -> `git stash pop`. Verify staged files with
  `git show --stat HEAD` after committing (git add can silently omit).

## Docs style for this repo family (user preference)

READMEs/docs must read human-written: no emojis in titles, no em-dashes,
no TL;DR sections or shiny badge rows, terse sentences, concrete numbers
(65-66 offsets, 53/12/0 identical/changed/degraded, 0x310/0x750), a
plain-language glossary for beginners. Commit messages terse + lowercase-ish
with a hyphen separator and the repo's prefix convention (docs:/feat:/fix:/
chore:), e.g. `docs: readme overhaul - beginner friendly + offsets guide`.
