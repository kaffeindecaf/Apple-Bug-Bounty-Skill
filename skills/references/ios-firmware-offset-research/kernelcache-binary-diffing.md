# Kernelcache binary diffing when symbols move (K4.7 method, 2026-08-25)

XPF resolves named items, but its output alone can't answer "what code
changed between 26.1 and 26.2" — resolved symbol ADDRESSES shift on every
build (normal code churn), and the item that a security fix touched may
not be in the XPF table at all. When hunting a fix (e.g. CVE-2025-46285,
"integer overflow addressed by adopting 64-bit timestamps"):

## 1. Map vaddr → file offset via LC_SEGMENT_64 — never vaddr − BASE

Modern kernelcaches are FILESETS: multiple segments (__TEXT,
__PRELINK_TEXT, __DATA_CONST, __DATA_SPTM, __TEXT_EXEC,
__TEXT_BOOT_EXEC, …) each with their own `vmaddr`/`fileoff` delta.
`fileoff = vaddr − BASE` lands mid-function in most segments (hit:
disassembling "0xfffffff00814ed2c" via naive math showed unrelated
garbage while the real function was 0x4000 bytes earlier in the file).
Parse LC_SEGMENT_64 (cmd 0x19): `fileoff + (vaddr − vmaddr)` for the
segment containing the vaddr. Same trap applies to the xpf-cli
`out.macho` dump.

## 2. Anchor functions by byte signature, not address

Between builds everything moves. To compare a function across builds:
- Signature-match its distinctive constant loads. Example: the
  seconds→ns divide-by-1e9 magic 0x44B82FA09B5A53 loads as
  `mov x9,#0x5a53; movk x9,#0xa09b,lsl#16; movk x9,#0xb82f,lsl#32;
  movk x9,#0x44,lsl#48` → 16 searchable bytes. But note this idiom
  appears ~60× per kernel (compiler emits it for every /1e9) — match
  the CLOSEST PAIR of hits (the a600/a65c twin helpers sit ~0x60 apart)
  or use the callers' own constants to pin the right instance.
- BL targets point at the callee's `bti c` PROLOGUE, not its constant
  loads — scanning for `bl` to a mid-function address finds nothing.
  Locate the `bti c` (0xD503245F) and target THAT.
- Once anchored, byte-diff at identical relative offsets; all-BL/adrp
  deltas = benign code churn, semantic changes = the fix.

## 3. Hypothesis-test with an opcode census

Before eyeballing hours of disassembly, count instruction classes across
both kernels — a clean kill is instant:
- W-reg vs X-reg mul/madd: prefix `(word>>21)&0x7FF` == 0xD80 (W) vs
  0x4D8 (X). A "32→64-bit widening" fix would drop W-mul counts; both
  kernels having ZERO W-muls disproves that theory outright.
- umull/umaddl (32×32→64, prefix `(word>>22)&0x3FF` == 0x1E8) and
  smull/smaddl (0x1C8) counts: 720→730 = no bulk conversion happened.
- 1e9 constant load sites: `mov wN,#0xca00; movk wN,#0x3b9a,lsl#16` is
  the 32-bit form (bytes `00 40 99 52 40 73 a7 72`), the 64-bit form
  uses x-reg opcodes (`…52/…d2`). 6 sites in both kernels = same callers.

## Verdict plumbing

Turn the diff into a decision: struct/constant items (kernelStruct.*,
kernelConstant.*) identical → the highest applicable
`SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"x.y")` block in offsets.m
still covers the new build; symbol address shifts alone are noise.
(Implemented as kcwatch.py `offsets_verdict()` + the "degraded"
resolved↔UNRESOLVED category added to xpf_diff.py — items that vanish
from one dump's resolution table are structural changes, not "identical".)

## Environment notes

Public xnu GitHub tags (e.g. xnu-12377.41.6) do NOT align with release
build numbers (12377.42.6~55) — the source-diff shortcut usually dead-ends.
capstone is available in the system python3 (`import capstone`); write
scripts to a file and run via terminal python3 (execute_code sandbox
lacks it).

## Static-collection kext layout (kernelcache kext diffing, 2026-09-02)

Per-kext diffs on modern (fileset-style) kernelcaches — proven on the
t8030 26.6→26.6.1 pair (ios-bounty-hunt, AppleSEPCredentialManager):

- `__PRELINK_INFO` gives each kext's `_PrelinkExecutableLoadAddr` = its
  Mach-O header vmaddr inside `__PRELINK_TEXT` (t8030: va=0xfffffff00700c000
  fo=0x8000, linear). `kc_kext_extract.py` copies only the __TEXT metadata
  member (~70 KB) — its `_PrelinkExecutableSize` is NOT the code size.
- The member's own `__TEXT_EXEC` load command carries the relocated code:
  all kext code lives in the TOP `__TEXT_EXEC` (t8030: va=0xfffffff007fa8000
  fo=0xfa4000, linear: fileoff = 0xfa4000 + (va − 0xfffffff007fa8000)).
  SEP's exec grew +0xb38 (2872 B) while its prelink "file size" grew only
  +1216 — always measure the __TEXT_EXEC delta for the real change size.
- The member's `LC_FUNCTION_STARTS` fo is collection-absolute; decode
  uleb deltas against the member's __TEXT vmaddr, keep only addrs inside
  its exec range (932/933 fns for SEP). Function size = gap to next start.
- Naive ordinal gap-diff explodes (~630 "changed") when one function is
  inserted AND non-exec data moved: every pc-relative immediate
  re-encoded. De-noise by masking per instruction: adrp/adr/bl/b/cbz/
  tbz/ldr-lit pc-imms, plus the compensating imm12 of add/sub(S=0)/ldr/
  str — then map old↔new fns by a normalized fingerprint at fn+16 and
  diff bodies. Verify with size accounting: sum of changed-fn deltas must
  equal the exec size delta exactly (residual 0).
- capstone returns kernel vaddrs (>2^63, top byte 0xff) as NEGATIVE
  ints: mask every operand imm (`& 0xFFFFFFFFFFFFFFFF`) before address
  math or bl-target/caller/string-page lookups silently fail and every
  in-exec call prints as "out-of-exec".
