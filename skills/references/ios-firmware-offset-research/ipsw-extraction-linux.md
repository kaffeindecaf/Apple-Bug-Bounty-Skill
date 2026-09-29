# IPSW extraction on Linux — pyimg4 details

Verified working in session (2026-08): pyimg4 0.8.8, extracted synthetic
im4p payloads end-to-end via `research/extract.sh` on Linux.

## Why pyimg4

`usbliter8-arctic/tools/img4` (and img4tool, ldid, gtar, …) are **macOS
Mach-O binaries** — `exec format error` on Linux. The pure-Python
[pyimg4](https://github.com/verygenericname/pyimg4) CLI is the Linux backend:

```bash
pip install --break-system-packages pyimg4     # PEP 668 hosts need the flag
```

## CLI reference

```bash
# extract an UNENCRYPTED im4p payload (iBSS/iBEC/TXM) to raw
python3 -m pyimg4 im4p extract -i Firmware/dfu/iBSS.n104ap.RELEASE.im4p -o ibss.raw

# extract an ENCRYPTED payload (kernelcache / restore ramdisk)
# IV and KEY are the two 32-hex halves of the wiki's concatenated IVKEY
python3 -m pyimg4 im4p extract -i kernelcache.release.n104ap -o kernelcache.raw \
    --iv "<32 hex>" --key "<32 hex>"
```

Gotchas:
- **IV/key are separate flags**, split the wiki's 64-hex IVKEY at 32 chars.
- **FourCC must be exactly 4 chars** on `im4p create` (`txm` → error; pad as
  `"txm "`). Only affects synthetic test fixtures, not real files.
- `im4p extract` with `--iv/--key` on an unencrypted payload succeeds anyway
  (keys ignored) — don't mistake that for decryption.

## keys.txt format (research/extracted/<name>/keys.txt)

```yaml
kernelcache_ivkey: "a1b2...64hex..."
restoreramdisk_ivkey: "c3d4...64hex..."
```

## IPSW component paths (board, not model)

| Component | Path inside IPSW | Encrypted? |
|---|---|---|
| iBSS | `Firmware/dfu/iBSS.<board>.RELEASE.im4p` | no |
| iBEC | `Firmware/dfu/iBEC.<board>.RELEASE.im4p` | no |
| TXM | `Firmware/all_flash/*TXM*.im4p` | no |
| kernelcache | `kernelcache.release.<board>` | yes (wiki keys) |
| RestoreRamDisk | `Firmware/all_flash/048-*.dmg` | yes (wiki keys) |

Board examples: iPhone 11 = `n104ap`, 11 Pro = `d421ap`, 11 Pro Max =
`d431ap`, SE 2 = `d79ap`, XS = `d321ap`, XR = `n841ap`, iPad 9 =
`j181ap/j182ap`.

## Key sources

- IPSW downloads: https://ipsw.dev/ (betas, direct CDN links), https://ipsw.me/
  (stable), developer.apple.com (Apple ID).
- IV/Key per (device, build): https://theapplewiki.com/wiki/Firmware_Keys/27.x
  → open the build row for your device → copy IV + Key for Kernelcache and
  RestoreRamDisk, concatenate, no spaces.

## Synthetic end-to-end test recipe

Used to verify `extract.sh` on Linux without a real IPSW:

```bash
# wrap fake payloads as im4p (4-char fourcc!)
python3 -m pyimg4 im4p create -i ibss.raw -o Firmware/dfu/iBSS.n104ap.RELEASE.im4p -f ibss -d test
# zip the tree → research/extract.sh <fake.ipsw> "<name>" n104ap [--keys]
```

## extract.sh backend selection order

1. `img4` on PATH (user-built img4lib)
2. bundled `tools/img4` **only on macOS** (`uname` = Darwin)
3. `pyimg4` via `python3 -m pyimg4` (Linux)

If `research/extract.sh` is missing from a fresh clone: `research/` is
gitignored in usbliter8-arctic — the script + README are local-only unless
the user opts to track them.
