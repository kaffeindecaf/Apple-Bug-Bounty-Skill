# Deriving a struct FIELD offset from a kernelcache

Use when the exploit offset table needs `offsetof(struct X, field)` and no
KDK/DWARF/symbol exists. The field must be one that code READS and that the
kernel PRINTS — that is what makes the offset verifiable from a binary instead
of guessed. (A wrong offset here is not a failed guess; it is a kernel write
through a bogus address, which panics the phone.)

## Method

1. **Find a message that prints the field.** XNU prints a lot of its own
   structs. Example: the zone bound check emits
   `zone bound checks: buffer %p of length %zd overflows object %p of size %zd in zone %p[%s%s] @%s:%d`
   and the value it calls the object's size IS `struct zone`'s `z_elem_size`.
   Byte-search the whole file for the literal, then map file offset -> VA through
   the segments (not sections).
2. **Find code references.** Scan the executable ranges for ADRP+ADD pairs whose
   computed target equals the string VA; if none, look for an 8-byte pointer to
   the string in data and ADRP+LDR that slot. Kernelcaches are stripped —
   `llvm-objdump --syms` returns almost nothing, so a symbol name is not an
   option.
3. **Identify the struct's register by scoring, never by assumption.** Collect
   every load in the function window and score each candidate base register by
   how many expected `(offset, width)` pairs it hits; take the best. Compilers
   differ per build: one build read the flags byte through a scratch register and
   only recomputed the struct into its "usual" register afterwards, so an anchor
   that hardcodes the register names the wrong one. Require 4-of-5 expected
   fields before you believe a register holds the struct at all.
4. **Corroborate with a semantic anchor.** A load of the flags byte immediately
   feeding a `tbnz` on the single-bit flag (`z_percpu`) proves that byte is the
   flags word; the field that the message prints proves that field's offset and
   width.
5. **Assert, do not print.** The tool must exit non-zero unless every expected
   field is present at the expected offset AND width, and the wanted field's
   loaded register provably reaches the message's argument slot. A tool that
   dumps whatever it found "passes" on a wrong window.
6. **Pin only on agreement across every kernelcache on hand** — each version
   block of the offset table, and both SoCs if the table is SoC-shared. The
   public xnu source (`apple-oss-distributions/xnu`, `osfmk/kern/zalloc_internal.h`,
   `zalloc.c`) supplies the expected layout and the reading of the code; note
   that build numbers are not tag names (a `xnu-12377.42.6` kernel ships under
   tag `xnu-12377.41.6`), so take the nearest tag and confirm the struct is
   byte-identical across the tags that bracket the builds.

## Pitfalls that cost the most time

- **iOS 26 kernelcaches put most code in a SECTION-LESS `__TEXT_EXEC` segment.**
  A section-only walk finds a fraction of the kernel and every string looks
  unreferenced. Iterate segments with `initprot & VM_PROT_EXECUTE` and use the
  segment's own file range when it carries no `__text` section.
- **`section_64.offset` and `.align` are `uint32`, not `uint64`.** Parsing the
  section header as three QWORDs (`addr, size, offset`) shifts every following
  field and silently mis-maps file offsets to VAs.
- **capstone: `insn.raw` raises `CsError: Details are unavailable (CS_ERR_DETAIL)`**
  unless detail mode is enabled. Use `int.from_bytes(insn.bytes, "little")` when
  you only need the instruction word (e.g. to decode LDR/STR immediates).
- **Widths: the LDR/STR unsigned-immediate `size` field is 0/1/2/3 => 8/16/32/64 BITS.**
  Pick one unit (bits) and keep it everywhere; a mixed bit/byte width makes every
  offset assertion fail for no visible reason.
- **Compare register NUMBERS, not names.** `stp x23, x21, [sp, #0x18]` and a
  tracked `w23` are the same register; string comparison misses the store and the
  "field reaches the message" check reports NO.
- **Sub-word fields over an 8-byte read primitive:** read the aligned qword that
  contains the field and mask it (the `uint16` at `+0x34` is bits 32..47 of the
  qword at `+0x30`), so the engine never needs an unaligned 2-byte kernel read.
- **The bit number of a flag is not stable across XNU eras even when the offset
  is.** `z_percpu` is bit 5 of the flags byte on the 17.0-era build and bit 6 from
  18.x on (`z_exhausts` was inserted ahead of it) — read the OFFSET from the
  binary and take the bit from the source of that era.

## Verified layout: `struct zone`

Identical in the public sources `xnu-10002.1.13`, `xnu-11417.101.15`,
`xnu-12377.41.6`, and read off 17.0 + 18.4.1 (t8030/A13) and 26.1/26.2 (t8110/A15),
26.6/26.6.1 (both boards) kernelcaches:

| field | offset | width | how it shows up in the bound check |
|---|---|---|---|
| `z_self` | 0x00 | 64 | |
| `z_stats` | 0x08 | 64 | |
| `z_name` | 0x10 | 64 | the `[%s]` argument — same offset the tree already uses as `kalloc_type_view.kt_zv.zv_name` |
| `z_views` | 0x18 | 64 | |
| `z_expander` | 0x20 | 64 | |
| `z_quo_magic` | 0x28 | 32 | multiply magic of `Z_FAST_MOD()` |
| `z_align_magic` | 0x30 | 32 | |
| `z_elem_size` | 0x34 | 16 | printed as the object's size in the panic |
| `z_elem_offs` | 0x36 | 16 | the element's offset inside the element |
| flags | 0x3c | 8 | `z_percpu` = bit 5 on the 17.0-era build, bit 6 from 18.x on |

Use: `pcb -> inpcbinfo.ipi_zone -> (qword at zone+0x30 >> 32) & 0xffff` is the
kalloc BUCKET size — the allocation's real extent, i.e. strictly better evidence
for clamping a kernel write than a struct's own field span. A bucket SMALLER than
the field span means the field table and the zone disagree: refuse the write
rather than widening it.

Vendored implementation to copy from: W0lfSword `scripts/kc_zone_fields.py`
(takes a raw Mach-O or an IMG4 kernelcache, `--json` for machine use).
