# Host-side XPF kernelcache diffing (W0lfSword tools/xpf-cli)

The K4.1 methodology as a CLI: verify kernel struct offsets for ANY iOS
build from the host, no device needed. Shipped in W0lfSword v1.1.0
(`./W0lfSword kernelcache resolve|diff|extract`, menu `k`) and planned as
the standalone "kcwatch" watcher (research/kcwatch.md in the W0lfSword repo).

## xpf-cli output grammar (parse this, don't guess)

```
# kernel: kernel.release.t8030
# darwin: 25.0.0
# xnu: 12377.2.9~1
# os: 26.0.1
# fileset=1 arm64e=1 sptm=1 base=0xfffffe0007004000 entry=0xfffffe0007004000
0x0000000000000748 <- kernelStruct.proc.struct_size
0x000000000000022e <- kernelConstant.nsysent
0x0000000000000000 <- kernelStruct.thread.ast [UNRESOLVED/crash]
```

- `xpf-cli <kernelcache.img4>` — resolve mode: headers + one line per item.
- `xpf-cli <kernelcache.img4> out.macho` — dump mode: decompress to raw
  Mach-O (IMG4→IM4P→krnl + LZFSE/LZSS handled internally by kdecompress).
- Feed it the IMG4 kernelcache straight out of an IPSW (A12+ unencrypted).
- **Parse order matters**: check the `[UNRESOLVED` pattern BEFORE the
  `^0x([0-9a-f]+) <- (.+)$` regex — an unresolved line is
  `0x0000000000000000 <- name [UNRESOLVED/crash]` and the generic regex
  would capture the name WITH the suffix and value 0. Unresolved → None.
- SPTM/fileset builds leave PPL items unresolved by design — expected.
- Exit code non-zero on failure; stderr has the raw error. Wrap with a
  friendly message + hint (build.sh needs clang + lzfse).

## Diff semantics (scripts/xpf_diff.py in W0lfSword)

Compare two dumps: identical / changed / one-sided counts + changed values.
Interpretation:

| Signal | Meaning |
|--------|---------|
| struct offset moved | kernel struct layout changed → offsets.m needs a new block |
| symbol address shifted | code around that symbol changed → patch-diffing lead vs Apple advisory |
| `nsysent`/`mach_trap_count` changed | syscalls added/removed → new attack surface |
| item → UNRESOLVED | field/function vanished → structural change |
| base/entry moved | KASLR layout change |

K4.1 result (2026-08-14, T8150): 26.0.1 vs 26.1 — struct constants
identical, ~30 symbol shifts, `task.itk_space` 0x310 (XPF/T8150) vs 0x318
(offsets.m, SE3) — per-SoC deltas exist, always state the board.

## Ranged kernelcache download (kcwatch — "6GB IPSW? no")

IPSW = zip; the central directory lives at the END of the file:

1. HTTP `Range: bytes=N-` the last ~64KB → End of Central Directory →
   find `kernelcache.release.<board>`, its offset + compressed size.
2. HTTP `Range` exactly that range → kernelcache bytes (~60-100MB total).

**zip64 is mandatory**: modern IPSWs exceed 4GB, so the directory is in
the zip64 EOCD locator, not the classic EOCD record. Parse order:
zip64 EOCD locator → zip64 EOCD → central directory → entry.

- Kernelcache is **SoC-shared** per build (kernelcache.release.t8030 covers
  every A13 device of that build) — one download per board, not per device.
- Poll api.ipsw.me/v4/device/<identifier>/releases (version, buildid,
  sha256sum, signed, CDN url). One ranged fetch per new build; be polite.
- Offsets ≠ exploitability: a clean diff means layout is unchanged, never
  that an exploit works.

## Reuse map

| Piece | Where |
|-------|-------|
| XPF host resolver (IMG4 + LZFSE) | W0lfSword tools/xpf-cli/ (build.sh) |
| Offset diff tool | W0lfSword scripts/xpf_diff.py |
| IPSW kernelcache extract (local zip) | W0lfSword `kernelcache extract` |
| Ranged-download proof | ROADMAP K4.1 + tools/xpf-cli README |
| kcwatch project plan | W0lfSword research/kcwatch.md |
