---
name: ios-variant-hunting
description: "Use for finding new iOS/WebKit bugs from published fixes: fix-commit sibling hunting, advisory-to-commit mapping, branch version sweeps, and build-pair kext diffing."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 9216
covers: [sibling hunting, fix-commit analysis, advisory mapping, branch sweep, affected-version proof, kext diff corpus, hunter delegation, verification rules]
learns_from:
  - projects/W0lfSword
  - projects/DarkSword-RCE
platforms: [any host, iOS 15.0-27.0, macOS]
triggers:
  - variant hunt
  - sibling bug
  - incomplete fix
  - advisory mapping
  - fix commit
  - affected versions
  - branch sweep
  - kext diff
  - patch diff
  - bugzilla mapping
  - is this a duplicate
related_skills:
  - ios-webkit-exploit
  - ios-security-pentesting
  - apple-bounty-submission
  - ios-firmware-offset-research
  - ios-poc-lab
  - ios-research-methodology
cross_reference_rules:
  - If the candidate is a JSC/WebCore shape → load ios-webkit-exploit for the actual exploitation primitive
  - If a source-only candidate needs a device repro → load ios-device-usb-tooling
  - If the candidate can be tested host-side against an Apple open-source fork → load ios-poc-lab
  - Once a finding is confirmed and the affected-version sweep exists → load apple-bounty-submission
  - If the diff corpus points at kernel offsets rather than bug sites → load ios-firmware-offset-research
references:
  - skills/references/ios-variant-hunting/advisory-fix-commit-map.md
  - skills/references/ios-variant-hunting/branch-version-sweep.md
  - skills/references/ios-variant-hunting/build-pair-diff-corpus.md
research_first: true
---

# iOS Variant Hunting (finding new bugs from published fixes)

Apple fixes one instance of a bug class. The siblings usually survive for months.
This skill is the host-side loop that turns a published advisory into a new
confirmed finding — no device, no build, no clone required for the source stages.

Three playbooks, cheapest first:

1. **Build-pair diff corpus** (5 min) — what changed in the last two shipping
   builds. Lead generator for kernel/kext work.
2. **Advisory → fix-commit map** (30-60 min) — every Bugzilla id in a fresh
   advisory either gets a CONFIRMED commit or an explicit UNVERIFIED.
3. **Fix-commit sibling hunt** (1-3 h) — extract the exact guard shape the fix
   added, then search the tree for the same shape with the guard missing.

## Scoring — no middle ground

Every candidate gets exactly one verdict:

| Verdict | Meaning |
|---|---|
| CONFIRMED | no runtime guard at the site AND the site is page-reachable |
| LIKELY | guard shape matches, reachability not yet traced |
| CLEAR | a runtime check is present at the site |
| UNVERIFIED | could not fetch the file / the tool silently skipped it |

"Probably vulnerable" is not a verdict. A hunter that only ever reports CONFIRMED
has started hallucinating; a hunter that only reports UNVERIFIED is not fetching.

## Playbook 1 — Build-pair diff corpus

`blacktop/ipsw-diffs` publishes `ipsw diff` output for consecutive Apple build
pairs. Read one file at a time from raw.githubusercontent — no IPSW download, no
tool, no token, no multi-GB clone. This is the cheap first pass for every new build,
before any kernelcache work.

Lead generator that pays off immediately: Apple's asserts print their own expression,
so a watchlist rule for added assert-shaped strings returns guards Apple added in that
build — `+"copied == srcLen"`, `+"newTotalSize <= bufCapacity"`, `+"remaining >=
cmdSize"`. A guard Apple just added marks a fix site; its bug class is what to hunt in
the siblings. The dylibs section returns added/removed mangled JavaScriptCore and
WebCore symbols for the pair: function-level WebKit evidence with no WebKit clone.

Traps: two dataset layouts (newer pairs write `KEXTS/<bundle>.md`, older ones inline
the diff in the pair README); compile timestamps are filtered, so an apparently empty
delta is not proof until you re-run with `--all-strings`; newest pairs record
`Symbols: 0` since dylib symbol lists stopped, so cstrings/function counts/section
sizes are the evidence; the dataset diffs ONE device, so kext-level deltas are
build-wide while kernel `.text` layout is per-SoC — never turn a kext hit into a
per-SoC offset claim.

Details: `skills/references/ios-variant-hunting/build-pair-diff-corpus.md`.

## Playbook 2 — Advisory → fix-commit map

Goal: for every `WebKit Bugzilla: N` line in a security.apple.com advisory entry,
produce a CONFIRMED commit or an explicit UNVERIFIED. The traps are what make this
work — parsing, attribution, and the two ways a "fixed" commit is not actually fixed
(an in-tree revert, or a superseded rewrite that deletes the guard). Read them before
the first run: `skills/references/ios-variant-hunting/advisory-fix-commit-map.md`.

The two checks that catch most false claims:

- **Ancestry is not liveness.** `compare/main...<sha>` with `ahead_by == 0` proves the
  commit is an ancestor of main. It does NOT prove the guard is still there. Fetch
  today's main copy of each touched file and grep the guard.
- **A fix can be superseded.** Check the touched path's later history. A second,
  differently-shaped crash in the same file means the class survived its first fix.

## Playbook 3 — Fix-commit sibling hunt

1. Pick fresh advisory entries (Safari/iOS releases on security.apple.com) and resolve
   the fixing commit (`gh api repos/WebKit/WebKit/commits/<sha>`), then read its
   `.patch`.
2. Extract the **exact guard shape** the fix added: ASSERT→runtime check, a missing
   `contains()` re-check, a missing scheme check, a missing bounds clamp.
3. Tree-wide pattern search for the shape: `gh api -X GET search/code -f
   q='repo:WebKit/WebKit <pattern>' --jq '.items[].path'`. Rate limit is roughly
   10/min — batch queries. The search is a LEAD GENERATOR, never a census: it
   silently skips large files, and the files fix commits touch are exactly the ones
   it misses. Count and classify with `grep`/`sed`/`wc` over freshly curl-ed bytes and
   keep the search reply only as one input to a reconciliation list.
4. Fetch candidates from `raw.githubusercontent.com/WebKit/WebKit/main/<path>` and
   quote exact `file:line` in findings. Never invent code, CVEs or line numbers.
5. Score each candidate with the table above. Fetch the CALLER before calling
   anything CONFIRMED: sync dispatch versus `queueTask` changes everything.

### Proven yielding shapes

- **`convert<IDLSequence>` + ASSERT-only size → unchecked deref.** A JS builtin result
  converted through a sequence that runs the JS iteration protocol (page-poisonable via
  `Symbol.prototype`/`Array.prototype[Symbol.iterator]`), an ASSERT-only size check on
  debug builds only, then `results[N]` dereferenced unchecked. Fixed once in a
  stream-transform path in 2026; treat other converts at the same boundary as live.
- **WeakHashSet client loops missing a `contains()` re-check.** `copyToVectorOf<Ref>` +
  callback without re-checking membership. Two decisive questions: does the Ref copy
  make mid-loop destruction structurally impossible, and does the caller dispatch
  synchronously or queue?
- **IPC boundary handlers missing a scheme check.** Handlers that reach the network
  from WebContent with only a cookie check and no `protocolIsInHTTPFamily`. Compare
  against the sibling handler that WAS hardened — the hardened twin is your checklist.

### Reachability is the whole argument

Shape alone proves nothing. Two real near-misses from past rounds: a font-cache
site looked unguarded until the caller proved a lock was held, and a
`LocalDOMWindow` site looked script-reachable until the caller turned out to use
`queueTask` (queued, not synchronous). Both were CLEAR after one caller read.

## Hunter delegation rules

If work is split across subagents, the brief must state all of this:

- read-only; `curl`/`gh` only; write ONLY to `/tmp/hX_*.md`
- no fabricated offsets, disassembly, or CVEs; UNVERIFIED is a valid verdict
- table-first output: `file:line | pattern | guard | score`
- report cap ~250 lines: findings table, top-3 candidates, quotes
- append findings to the report file after each completed step (a single
  "trace these 3 sites, disassemble, then write the report" task has burned a full
  40-minute window and delivered zero)
- one task = ONE site or ONE question

Then the parent re-verifies every claim against raw source before it enters the
tracker. Hunters over-claim on shape.

## Hard rules

1. **Never name your own helper scripts in the final answer.** Fact-checkers probe the
   workspace for script-like tokens and report "command not installed" when the file is
   not at the expected root, which reads as a contradiction and burns correction rounds.
   Write scripts into the round's evidence dir and cite paths, not commands.
2. **Save every fetched artifact** (advisory HTML/text, commit JSON, patch, raw source)
   into the round evidence dir so each claim is probeable against a file.
3. **Independent verification, or the pass does not count.** Re-derive the previous
   pass's counts with tools you did not author (`grep -h … | wc -l`, `awk -F'\t'`,
   `sha256sum`), and cite each checker as ONE transcript file: command line + real
   stdout. A summary line like "174/174 PASS" is read as self-asserted.
4. **HIT is not FINDING.** Promote nothing to the tracker until the target's own diff
   and raw source (or the on-device binary) have been read.
5. **A negative result gets one tracker line** so the family is not re-hunted next round.
6. **Never name an unfixed site in a public repo, commit message, or skill file.**
   Live sibling candidates are embargoed until Apple ships a fix.
