# Kext-level disassembly on an iOS 26 fileset kernelcache

Pitfalls hit while tracing AppleAVD index producers in `.kcwatch/t8030/26.6.1-23G83.img4`
(host-side, xpf-cli + rizin/capstone, no device).

## Parsing a fileset kernelcache

- iOS 26 kernelcaches are Mach-O **filesets**: top-level `LC_SEGMENT_64` commands are
  containers with `nsects=0` (`__TEXT`, `__TEXT_EXEC`, `__DATA`, ...), and each kext is an
  `LC_FILESET_ENTRY` (cmd `0x80000035`) that points (vmaddr + fileoff) at a **nested
  `mach_header_64`** carrying that kext's real sections. Walk the nested headers — the
  container segments have no sections, so a naive section scan finds nothing.
- `fileset_entry.entry_id` is an `lc_str` **but Apple writes the string inline right after
  `reserved`**, i.e. at `cmd+32`. Slicing 16 bytes truncates every long id
  (`com.apple.driver.AppleAVD` is 26 chars) — read ~64 bytes.
- For this era, `fileoff = VA - 0xfffffff007004000` holds for kernel and kext sections alike
  (verified: AppleAVD `__TEXT_EXEC.__text` VA `0xfffffff008157a40` ↔ KC off `0x1153a40`).

## Finding xrefs — the three forms that matter

1. **Direct `bl`** — scan raw `bl` words (`(w & 0xFC000000) == 0x94000000`, target =
   `pc + sext26*4`) across every executable top-level segment. Catches cross-kext calls that a
   single-kext scan misses.
2. **Stored pointers** — in this cache kext code pointers are stored as **tagged vmoffsets**:
   word = `0x00100000_<VA - kernel_base>` (e.g. `0x00100000011a1f98` for a `__mod_init_func`
   entry). A search for the raw 8-byte VA finds **nothing**. Search the low-32 vmoffset pattern
   and verify the 8-byte word; also try the VA/low-39-bit forms.
3. **arm64e thunks** — many workers have *zero* `bl` xrefs and *no* stored pointer. They are
   entered through landing-pad thunks
   (`bti c` / `ldr x0, [x0, #0x3ce8]` / `b <worker>`), themselves reached by `blr`/`blraa`.
   Find them by grepping the linear dump for the target VA (a `b` tail call), not by `bl` scan;
   the upstream indirect site usually stays UNVERIFIED — say so instead of guessing a vtable.

## Function boundaries

- Function starts = `bl` targets **plus** `bti c` landing pads (indirect entries) **plus**
  prologues (`pacibsp`, `stp x29,x30,[sp,#-N]!`) directly after a `ret`/`retab`.
- Missing `bti c` as a start makes a site look like it belongs to the *previous* function and
  silently corrupts an index-provenance trace. Cross-check with a backwards prologue scan and
  prefer the branch-target-derived start.

## Disassembler / tooling

- Use system capstone **5.0.7** (`/usr/lib/python3/dist-packages`) with `/usr/bin/python3`. The
  `ios-bounty-hunt/tools/.venv` capstone is 4.0.2 and imports `distutils`, which is gone in
  python 3.13 → import error.
- rizin loads the whole 62 MB fileset KC at correct VAs (`rizin -q -c 's <VA>; pd N' <kc>`), but
  **backwards `pd -N` output is frequently misaligned** (prints `.string`/`invalid`). Only trust
  forward disassembly from a verified function start; use rizin as the second opinion on the
  same window.
- Do VA arithmetic in python: kernel VAs (`0xfffffff0...`) exceed 2^63, so bash `$(( ))` wraps
  them negative and silently produces garbage/empty comparisons.
- `python3 -c ...` and `execute_code` are blocked in unattended single-query sessions — put the
  logic in a script file under the task's evidence dir and run it.

## Reading iOS kernel idioms

- **`0x38E38E39` magic**: `umull x8, wN, #0x38E38E39; lsr x8, x8, #0x21` = `wN / 9`; followed by
  `add w8, w8, w8, lsl #3; sub wM, wN, w8` = `wN % 9`. Range `[0,8]` — an intrinsic bound; do not
  mistake it for a bitfield extraction or for an unguarded index.
- **`movk x16, #0x2bad, lsl #48` + `csel`** = Apple's LAM/poison idiom: the poison branch is taken
  when `(u64)((u32)idx << scale) != sext32(same)`, i.e. it only catches an index
  **≥ 0x20000000** (u32 shift overflow). It is **never an element bound** — when auditing, look for
  a separate `cmp wIdx, #imm` / `cmp wIdx, [self+field]` + `b.hs/b.lo` skip, or a `mod N` producer.
- Explicit element bounds in this kext look like `cmp w24, #0x40; b.lo`, or a live field bound
  `ldr w8, [x19, #0x3cf8]; cmp w21, w8; b.hs <skip>`. A whole family being guarded while a sibling
  array (same object, different offset) is not is the cheapest missed-sibling signal to chase.
- Same-function non-contiguous layout is normal: an early-return epilogue (`ldp ...; retab`) can sit
  mid-function with the cold path continued after it (reached by `tbnz`), so "after a retab" does not
  imply a new function.
