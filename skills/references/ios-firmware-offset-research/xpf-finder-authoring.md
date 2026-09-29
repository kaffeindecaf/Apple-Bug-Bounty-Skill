# Authoring XPF finders for new struct offsets (kcwatch feed / W0lfSword XPF)

How to add an offset to the kernel-deltas feed, end to end. Validated
2026-08-30 on t8030/t8110 26.6 + 26.6.1 kernelcaches.

## Architecture (what actually drives the dump)

- `tools/xpf-cli/main.c` walks `gXPF.firstItem` and prints EVERY registered
  finder. The XPFSet metric blocks in `tools/xpf-cli/xpf_patched.c`
  (gBaseSet, gStructSet, ...) only matter for the library's
  `xpf_construct_offset_dictionary` path — **the CLI ignores them**. To add
  an offset to the feed: register a finder in the XPF source init; no
  xpf_patched.c edit is needed.
- Finders are `static uint64_t xpf_find_*(void)` in W0lfSword's
  `XPF/src/common.c` (struct offsets + constants), `non_ppl.c`, `ppl.c`,
  `bad_recovery.c`, registered in `xpf_common_init()` etc. with
  `xpf_item_register("kernelStruct.<x>.<y>", finder, NULL)`.
- Item name prefixes: `kernelStruct.<struct>.<field>`,
  `kernelSymbol.<name>`, `kernelConstant.<name>`, `kernelGadget.<name>`.
- `XPF_ASSERT(x)` on failure sets the error and RETURNS 0 — safe, no abort;
  failed finders print `0x0` in the dump. A name with no registered finder
  also prints 0x0 silently.

## Where new offset recipes come from

- `kexploit/offsets.m` comments document per-version hex recipes for most
  struct offsets: `iOS 26.x: find hex <bytes>, and get it from
  prologue+0xN (LDR)`. Those hex strings are memory byte order (LE);
  the host uint32 is the byte-reversed word (`09 01 80 52` -> `0x52800109`).
- Wildcards `??` in a recipe become a mask word passed to
  `pfmetric_pattern_init(inst, mask, nbytes, alignment)` — per-byte mask
  array, e.g. `?? ?? FF B5` -> inst `0xb5ff0000`, mask `0xffff0000`.
- LDR imm decode (`arm64_dec_ldr_imm`) returns the SCALED byte offset
  (imm12 x width: x=8, w=4, b=1) — no manual scaling.
- `arm64_dec_add_imm` accepts ADD only (mask 0x7f800000 == 0x11000000);
  SUB doesn't match.

## Recipe pitfalls: "prologue+0xN" breaks on newer builds

The recipe anchor assumes the pattern's function still has the field load
at prologue+0xN. On 26.6.x the layout moved (functions shortened /
inlined copies). Two robust replacements, both validated:

- **Backward scan** from the pattern match for the first decodable load:
  `for (i=1..0x10) off = xpf_ldr_imm_at(section, matchAddr - 4*i)`. Used
  for task.task_exc_guard — the LDRB `[x0,#0x5dc]` sits 8 bytes before the
  `cmp w21,#0x81` pattern on t8030.
- **Mode across ALL pattern matches** at prologue+0xc/+0x10: collect every
  nonzero LDR imm from every match's function start, return the most
  frequent value. Used for thread.t_tro — the pattern occurs 4x as
  inlined accessor copies, exactly one carries the field LDR.

First-match-wins is fragile: t_tro matches 4x, p_fd 30x on 26.6.1.

## Build loop

`tools/xpf-cli/build.sh` compiles XPF/src + ChOma and expects
`$REPO/XPF/src` — the XPF source is NOT vendored in kernel-deltas. From the
kernel-deltas root:

```bash
ln -s W0lfSword/XPF XPF   # symlink the source in
cd tools/xpf-cli && ./build.sh                  # clang + liblzfse-dev + libblocksruntime-dev
cd ../.. && rm XPF                              # remove the symlink again
```

## Validation loop (do this BEFORE trusting values)

1. Decompress a cached kernelcache: `tools/xpf-cli/xpf-cli kc.img4 out.macho`.
2. Parse the fileset with Python + capstone (Cs(CS_ARCH_ARM64, CS_MODE_ARM)).
   Gotchas that cost real time:
   - **LC_FILESET_ENTRY cmd is 0x80000035, NOT 0x8b.** Layout:
     cmd(4) cmdsize(4) vmaddr(8) fileoff(8) entry_id(4, lc_str offset from
     cmd start) reserved(4); id string at cmd_addr + entry_id.offset.
   - **Load commands start at file offset 32** (right after the 32-byte
     mach_header_64) — not at the `sizeofcmds` field (offset 20). Reading
     at sizeofcmds gives garbage (e.g. "com." bytes).
   - Section fileoffs inside a fileset sub-macho are container-relative:
     kernel entry at fileoff 0x8000, its `__TEXT_EXEC __text` at fileoff
     0x2cc8000 means `data[0x2cc8000]`, not `sub[0x2cc8000]`.
   - LC_FUNCTION_STARTS (0x26) blob = uleb128 deltas; 0 terminates. Base
     is the sub-macho's __TEXT segment vmaddr (or the kernel base from the
     dump header) — replicate pfsec_find_function_start by taking the last
     entry <= the match address.
3. Disassemble ~16 instructions before/after each pattern match and read
   the real field loads.
4. Verify the exact instruction encoding exists in the kernel:
   - LDR X1,[X0,#imm] unsigned: `0xF9400000 | (imm/8)<<10 | (Rn<<5) | Rt`
     (t_tro 0x3a0 -> `01 D0 41 F9`).
   - LDRB W8,[X0,#imm]: `0x39400000 | (imm<<10) | 8` — scale 0, imm NOT
     divided (exc_guard 0x5dc -> `08 70 57 39`).
5. Cross-check stability: resolve BOTH builds on BOTH boards. A real
   offset is stable 26.6 -> 26.6.1 and per-SoC values track the offsets.m
   direction (t8110 > t8030).

## Pitfalls hit in practice

- `re.escape()` on a bytes pattern escapes wildcard dots — `b"..\xFF\xB5"`
  becomes literal dots and finds nothing. Escape only the literal tail.
- 0x28 in a bytes pattern is a regex `(` -> `re.PatternError:
  unterminated subpattern`; escape the whole pattern.
- Patching raw-string ASCII art containing backslashes: a JSON patch
  `\\` can land as `\\\\` in the file (diff shows doubled backslashes).
  Verify art bytes with `sed -n ... | cat -A` before committing.
- `verify`'s `effective_offsets` takes the LAST assignment per version
  block regardless of `isA13Above`/`isA15Above` conditionals — per-SoC
  overrides resolve to the A18+ value. Treat verify OK/MISMATCH on such
  vars as approximate; the feed diff (report verdict) is the clean signal.

## 2026-08-30 findings (26.6 / 26.6.1, t8030 + t8110)

- thread.t_tro resolves 0x3a0 (t8030) / 0x3b0 (t8110); offsets.m 26.x
  block lists 0x390 / 0x398 — stale, thread struct grew.
- task.task_exc_guard resolves 0x5dc / 0x604 vs 0x5d4 / 0x5fc — stale.
- thread.ast pattern exists only on A15 (t8110); ctid / machine_upcb /
  p_fd recipes do not fit 26.6.x layouts (pattern absent or wrong function
  shape) — those finders print 0x0, an honest UNRESOLVED, same as the
  existing per-SoC items. Do not delete them; they may resolve on future
  builds.
