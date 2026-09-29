# Build-pair diff corpus (ipsw-diffs)

`blacktop/ipsw-diffs` publishes `ipsw diff` output for ~150 consecutive Apple build
pairs. A reader script can pull one file at a time from raw.githubusercontent: no IPSW
download, no `ipsw` binary, no token, no 3.4 GB clone. Cache the fetched files
(e.g. `~/.cache/ipswdiffs`).

This is the cheap first pass for every new build, BEFORE any kernelcache work.

    python3 tools/ipswdiffs.py index
    python3 tools/ipswdiffs.py kexts <pair>            # per-kext delta table
    python3 tools/ipswdiffs.py sweep <pair> --watchlist tools/ipswdiffs.watchlist.txt --section kernel
    python3 tools/ipswdiffs.py sweep <pair> --watchlist tools/ipswdiffs.watchlist.txt --section dylibs
    python3 tools/ipswdiffs.py show <pair> <kext|binary>
    python3 tools/ipswdiffs.py grep <pair> --section kernel <pattern>

## Why the watchlist works

Apple's asserts print their own expression. A watchlist rule matching added
assert-shaped strings therefore returns the guards Apple added in that exact build:

```
+ "copied == srcLen"
+ "newTotalSize <= bufCapacity"
+ "remaining >= cmdSize"
+ "numRecords <= <cache>_CacheSize"
```

A guard Apple just added marks a fix site. Its bug class is what to hunt in the
siblings (see the parent skill's Playbook 3).

`--section dylibs` returns added/removed MANGLED JavaScriptCore/WebCore symbols for
the pair — function-level WebKit evidence with no WebKit clone, usable to pre-filter a
fix-commit sibling hunt.

## Traps

- **Two dataset layouts.** Newer pairs write `KEXTS/<bundle>.md`; older ones inline the
  kext diff in the pair README. Handle both; never assume `KEXTS/` exists.
- **Filtered noise is not proof.** Compile timestamps are filtered out, so an
  apparently empty delta is not proof until you re-run with `--all-strings`.
- **`Symbols: 0`.** Newer pairs record no symbol lists at all. cstrings, function counts
  and section sizes are the evidence then; a tool that prints nothing is not a tool that
  found nothing.
- **Same size, changed content** is reported per kext. That is an edit that shifted
  nothing — exactly what a tightened check looks like, so do not filter it out.
- **One device only.** The dataset diffs a single device (e.g. iPhone18,1). Kext-level
  deltas are build-wide; kernel `.text` layout is per-SoC. Never turn a kext hit into a
  per-SoC offset claim.
- **An OS-jump pair is noisy.** e.g. 26.5 → 27.0 rewrote whole subsystems, so rank
  added-assert hits by reachability (an app-openable userclient first) before spending
  reverse-engineering time.
- **A pure relink pair returns zero kext signals** even with `--all-strings`. That is a
  real result — record it as a negative and move on.

## Rules

- HIT != FINDING. Promote to the tracker only after reading the target's own diff and
  the raw source (or the on-device binary), as with every other hunter claim.
- Record the pair id + file path with every hit so the claim is reproducible without the
  cache.
- A negative here gets one tracker line, not a paragraph.
