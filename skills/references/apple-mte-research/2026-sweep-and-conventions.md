# 2026 source sweeps + repo conventions

Two sweeps so far: S35-S51 (2026-08-31, source/topic sweep) and S52-S66
(2026-09-18, github exploit + CVE sweep, commit a91e34b).

## Source map additions (S1..S34 → S1..S51)

New 2026-developments section in resources/links.md, tagged S35+:

- S35–S37: **CVE-2026-28952** — first public kernel exploit surviving
  MIE. Calif + Anthropic Mythos, 2026-05. Data-only local LPE on macOS
  26.4.1 (25E253) on M5 with kernel MIE enabled. Two bugs: overflow in
  `_zalloc_ro_mut` + per-CPU allocation bounds. NEVER performs memory
  corruption, NEVER triggers a tag exception — MIE has nothing to
  intercept. Fixed in macOS 26.5 (2026-05-11). 55-page report withheld
  until patch adoption. Sources: blog.calif.io, 9to5Mac, byteiota.
- S38: octet-stream.net (Tom Bull) hands-on MIE experiments (heap
  overflow/UAF demos on A19/M5).
- S39–S41: A19 die shots — ChipWise (N3P, ~25–30B transistors),
  TechPowerUp (98.6 mm2 vs 105 mm2 A18 Pro, ~10% smaller), TechInsights
  (TMUA28 floorplan, paywalled). Tag-storage silicon footprint still
  unmeasured — open research gap.
- S42–S44: XZone open source — apple libmalloc doc/xzone_malloc.md
  (bucketed type isolation, 1–4 general buckets, early allocations/MFM,
  TINY/SMALL/LARGE/HUGE), Xcode "Adopting type-aware memory
  allocation" (malloc_type_* API), df-f.com (Levin) memento
  introspection (`Malloc XZone with 241 zones, 10 slots`, bucketing_key,
  segment tables — runtime fingerprinting template).
- S45–S49: darknavy.org allocator MTE survey, Folded-Tag (Computers &
  Security 2025), IUBIK (IEEE S&P 2025), NanoTag (IEEE S&P 2026),
  ARM MTE Performance in Practice (arXiv 2601.11786).
- S50: pbxscience iOS 27 sandbox-escape/Filza talk skepticism piece.
- S51: sigreturn.com "Apple internals #9: SPTM, TXM and memory tagging"
  — PPL/TXM/SPTM generation table, SPTM endpoint numbers (XNU #1, TXM
  #3, SK via SVC/HVC → VBAR_GL2; Darwin 24: 34 endpoints, Darwin 25
  adds 37–42), kernel-R/W reach limits (XNU_DEFAULT yes; page tables,
  creds, trust-cache slabs, SPTM frame table, Secure Kernel no), MTE
  tag storage only in iPhone18,4+ IPSWs, **Spectre V1 quantified:
  attacker needs 25+ chained V1 sequences for high exploitability**.

## GitHub exploit/CVE sweep recipe (the 2026-09 run)

What actually produced hits, in order of yield:

1. `gh search issues "EXC_ARM_MTE_TAGCHECK_FAIL"` / `"MTE_FAIL"` /
   `"mteState enabled"` — these three strings return the entire field
   corpus plus brand-new issues (the eqvol M5 report was filed the same
   day). Best signal-to-noise of any query.
2. `gh search repos` with plain phrases fails on MTE terms ("MTE
   bypass", "memory tagging extension exploit" -> empty). What works:
   the vendor phrase ("memory integrity enforcement"), product names
   ("Coruna", "SPTM bypass", "PUAF", "kalloc_type", "T8150").
3. `gh search code "<symbol>" --repo <diff-corpus-repo>` — searching
   `mtePageTags` / `EXC_ARM_MTE_TAGCHECK_FAIL` inside blacktop/ipsw-diffs
   locates the exact build pairs where MTE tooling changed. ipsw-diffs
   is the highest-value GitHub asset for this KB (846 stars, every IPSW
   transition as a symbol diff, README indexes old .vs new).
4. `gh api repos/<owner>/<repo>/readme --jq .content | base64 -d` for
   repo claims, and `/contents/<path>` for directory listings. Never
   trust the GitHub description alone.
5. Apple advisory pages via curl + tag strip, then count CVE IDs inside
   `<h3>Kernel</h3>` sections with a small python parse. Grepping the
   same pages for "Memory Integrity"/"MTE" confirms Apple never names
   the feature, so release notes cannot track it.
6. NVD REST (`services.nvd.nist.gov/rest/json/cves/2.0?cveId=...`) for
   per-CVE text and CVSS; keywordSearch with date ranges returned empty,
   so look up IDs you already have instead.

## S52-S66 additions (2026-09-18)

- S52 pmap_tte_remove (physical UAF, uint16 pt_desc refcount, MIE-blind).
  Document with caveats: single-source, bounty closed as "expected
  behavior", Apple issued a fabrication-flavored program warning. State
  the caveat in the doc, do not launder it into a fact.
- S53 eqvol M5 driver-host MTE_FAIL (filed 2026-09-18).
- S54 ironpeak Pardon MIE? — the CVE-2026-28952 two-instruction fix with
  the pre/post asm and the sibling RO-writer list. The single best
  technical source on the trusted-writer class.
- S55 ipsw-diffs, S56 iOS-SDKs (exception.h MTE codes 0x106/0x107).
- S57-S62 + S66 Coruna kit ecosystem and Titan (PPL/SPTM bypass, pre-A19).
- S63 RISC-V-MIE, S64 kalloc-type-rs (clean-room and allocator refs).
- S65 Apple advisory set (kernel CVE counts: 26.6 23, 26.6.1 4, 26.7 18,
  iOS 27 20; no MIE mention anywhere).

Doc placement used: 10 gains sections 9-11 (physical UAF / trusted writer
/ PPL-SPTM layer) plus three pattern-summary rows; 09 gains the eqvol
case, the crash-reporting build timeline and the advisory gap; 07 gains
research angles 11-12 and a "what to conclude" block; 04 gains the
trusted-writer section and the exception codes; checklist gains Tier 9.

## Contribution tooling (commit b96c7d7)

scripts/ now carries the contributor path: contrib_common.py (signature
list, .ips/panic/stacks parsing, redaction), mte_device_report.py (device
identity + MTE verdict + optional crash pull/syslog, `--plist` offline
mode), mte_crash_scan.py (MTE triage, `--emit` writes corpus entries in
the 09-doc format), mte_insn_census.py, tests in scripts/tests/.

Hard-won details worth not rediscovering:

- **.ips shapes vary and all land in the same folder.** Modern: two JSON
docs (one-line header + body). `exception.codes` is a STRING
("0x0000..., 0x0000..."), the ints live in `rawCodes`. Panic reports carry
`panicString` and no threads; "stacks" reports are bug_type 288 with
`processByPid`; legacy reports are plain text. Assume nothing: wrap every
field access (a bare `.get` on a str/list blew up on real files).
- **Kernelcaches are Mach-O filesets.** Top level has 235
`LC_FILESET_ENTRY` (0x80000035) commands, each with `fileoff` at cmd+16 and
an entry_id string offset at cmd+24; `com.apple.kernel` is itself an entry.
Without fileset walking you get 0 sections and silently report nothing.
.ips SDK-path kernelcaches (t8030/t8110 26.x from os-bounty-hunt) are raw
FEEDFACF; older ones are IM4P + LZFSE-compressed (`bvx2`) and need pyimg4.
- **Zero is a real result.** A13 t8030 26.6.1: 6,665,832 instructions / 235
kexts / 0 MTE instructions, and the strings `memtag`/`mte_`/`__arm_mte`
are absent too, so the tagging paths are built for MTE chips. Verify the
counter itself with a clang Mach-O probe (`clang -c -target
arm64-apple-ios16.0 -march=armv8.5-a+memtag`) rather than doubting a 0.
- **Redaction must be case-insensitive.** ideviceinfo plists use
`SerialNumber`/`UniqueChipID`, crash JSON uses `serialNumber`; and plist
keys can be dropped from the report entirely (ECID is an identifier, not
context) so they never depend on the text rules.
- **`idevice_id -l` failing with rc=255 "Unable to retrieve device list!"
is usbmuxd, not a missing tool.** Check `shutil.which` first; report the
real reason and the `sudo systemctl start usbmuxd` hint.

## A19 kernelcache offline (commit f97d223, doc 11)

Fetching a real A19 kernel needs no device:

    curl -s "https://api.ipsw.me/v4/device/iPhone18,1?type=ipsw"   # find build + URL
    python3 W0lfSword/scripts/fetch_kernelcache.py <ipsw-url> out.img4
    pyimg4 im4p extract -i out.img4 -o out.kc     # auto-detects LZFSE, no --lzfse flag

Entry is `kernelcache.release.v53` (new naming, not `.iphone18`). 26.6.1
(23G83) = 22.0 MB im4p -> 72.7 MB Mach-O, 298 fileset kexts; 27.0 (24A437)
= 78.1 MB, 301 kexts.

Hard numbers this produced (the doc's core value):

- MTE instruction census: T8150 26.6.1 = 884 sites, 27.0 = 713, both ~99%
  inside com.apple.kernel/__TEXT_EXEC (ldg dominant, exactly 1 irg).
  A13 t8030 and A12 t8110 26.6.1 = 2 sites each, both a Libm compiler
  pattern, 0 in their kernels.
- The shipped kernelcache is stripped: all kexts have LC_SYMTAB with
  nsyms = 0. Function-level RE (imgact_setup_sec, _zalloc_ro_mut,
  task_has_sec_*) needs a development kernel or KDK. That is the named
  blocker, not a tooling gap.
- What is recoverable: kalloc_type/zone name tables and panic strings.
  `task_has_sec_soft_mode/_inherit/_never_check` and
  `checked-allocations` are A19-only strings vs A13.

## Instruction-census pitfall (cost a wrong finding once)

`capstone.Cs.disasm()` stops at the first word it cannot decode, and
`__text` contains literal pools and padding. A naive census reported **0
MTE instructions on every kernel**, which is false: A19 has 884. Resync 4
bytes after a stop and continue; coverage went 8.2M -> 11.54M instructions
(100% of text words). Rule: never publish a zero-count from a linear sweep
without printing instructions-scanned vs section_bytes/4. A raw-encoding
cross-check needs masks derived from >=2 assembled variants with varied
registers *and* immediates, or the mask silently pins Rn/Rt to 0 and
undercounts (this bit the same investigation).

## ipsw-diffs symbol diff conventions

`gh search code <symbol> --repo blacktop/ipsw-diffs` locates the exact
build pairs where a symbol changed; dirs are `<older>__vs_<newer>` and
README indexes them. In a symbol diff, `+` = present in the newer build,
`-` = only in the older. Watch the underscore: iOS 15.4/18.4 diffs show
`_isMTECrash` being *dropped*, a different symbol from the `isMTECrash`
added in 26.0 RC. Cross-major diffs (26.5 vs 27.0b1) list hundreds of
symbols as removed because of framework splits: confirm with a same-major
beta-to-beta diff before calling anything a removal.

## Data-only attack class (the big 2026 finding)

MIE's blind spot: logic flaws that never produce an invalid access.
CVE-2026-28952 is the canonical example. Documented in:
- 07-attack-surface.md: added to "what MTE does not catch" + Current
  public state (was "no known public bypass" → now "data-only LPE
  public since 2026-05")
- 10-exploit-examples.md: section 8 "Data-only exploitation: no
  corruption, no tag fault" + pattern table row
- 09-mte-bugs-field.md: counter-example case

Implication: expect the field to shift toward data-only/logic-bug
exploitation. MTE raises the bar for corruption chains to near-
practical-impossible but does not see this class at all.

## Repo conventions established

- **Relative markdown links, not wikilinks**: GitHub renders the book
  only with `[02-emte](02-emte.md)` style. graph.py accepts both but
  new content MUST use relative links. `[[` grep before committing.
- **graph.py**: verifies wikilinks AND md links; non-.md targets
  (scripts, papers) return a True sentinel (not dangling) — the caller
  must isinstance-check str before os.path.basename (Pyright enforced).
- **.gitignore for agent-private material** (24b752d): resources/papers/,
  resources/downloads/, resources/kernelcaches/, resources/kdk/,
  resources/corpus/, *.pdf, *.ipsw, kernelcache*, *.ips, *.panic, *.dmp,
  notes/, scratch/, .hermes/. The OffensiveCon PDF was untracked
  (git rm --cached) — stays on disk, out of the repo. Reference docs
  meant for the agent are working copies, not repo content; distilled
  knowledge lives in docs/ + resources/*.md.
- **Diverged-history fix**: git fetch → inspect → git rebase origin/main
  → resolve keeping real content (git checkout --theirs) → re-remove
  files the rebased commit re-added → push. No force-push.

## Docs style (reinforced)

Terse, lowercase-ish, hyphen separators, no em-dashes/emojis/AI filler.
Concrete numbers (1/32 DRAM, 70+ processes, 25+ V1 chains, 98.6 mm2).
Crash entries keep the real signature block verbatim.
