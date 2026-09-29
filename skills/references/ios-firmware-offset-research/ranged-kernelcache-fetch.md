# Ranged kernelcache fetch from a huge IPSW (validated 2026-08-24)

Fetch ONLY the `kernelcache.release.*` bytes out of an 8GB IPSW over HTTP
Range — no full download. Implemented in W0lfSword `scripts/fetch_kernelcache.py`;
proven on iPhone12,8_18.4.1 (8.45GB, 19.2MB fetched) and 17.1 (17.6MB).

## Steps

1. HEAD the IPSW URL → total size. Range-fetch the last 256KB.
2. Find the EOCD: scan for `PK\x05\x06` **and validate `comment_len`**
   (field @+20) so that `i + 22 + comment_len == len(tail)`. A bare byte
   search false-positives on the signature appearing in file data.
3. Classic EOCD: `cd_size, cd_offset` at `@+12` (NOT @+16 — that overruns
   and reads the wrong fields). If either is `0xFFFFFFFF` → zip64:
   locator at `eocd - 20` (`z64_off` @+8), zip64 EOCD record: `cdsize` @+40,
   `cdoffset` @+48.
4. Fetch the central directory, walk `PK\x01\x02` records, match
   `name.startswith("kernelcache.release.")` — the name is **per-board**
   (iPhone12,8/D79AP ships `kernelcache.release.iphone12c`), never the SoC
   (`t8030` is NOT the zip entry name).
5. **Multi-placeholder pitfall:** the CD entry's `0xFFFFFFFF` fields resolve
   via the entry extra field (ID `0x0001`), which contains ONLY the fields
   that were `0xFFFFFFFF`, in ORDER ucsize → csize → lho. 17.1 IPSW had ALL
   THREE placeholders; 18.4.1 only lho. If you always consume csize+lho
   unconditionally, lho silently resolves to ucsize → wrong data start →
   garbage (no `IM4P` magic, xpf-cli "Failed to open kernelcache").
6. The zip entry is deflate-compressed:
   `zlib.decompressobj(-15).decompress(data)` → IMG4 (`IM4P` at ~offset 8).
   Feed THAT to xpf-cli (its kdecompress handles the inner LZFSE/LZSS).

## Verification

`xxd file | head -1` should show `IM4P` within the first ~16 bytes after
decompression. Byte-compare two independent fetches (`cmp`) to catch
off-by-one range bugs.

## xpf-cli host build (Debian)

`tools/xpf-cli/build.sh` needs `clang` + `liblzfse-dev libblocksruntime-dev`
(`apt install`); the prebuilt binary needs `liblzfse1` at runtime.

## Finding the IPSW URL for an older build

The ranged fetch needs a URL, and old builds are what offset work wants.
`https://api.ipsw.me/v4/device/<identifier>` (e.g. `iPhone12,8`) returns
`firmwares` newest-first with `version`, `buildid`, `url`, `signed` — pick the row
by version+buildid and hand its `url` to the fetcher. Signing status does not
gate the fetch: it reads Apple's CDN, so builds that are no longer signed stay
reachable, and an IPSW URL is worth recording once found.

## Getting a raw Mach-O for offset work

`tools/xpf-cli/xpf-cli <kernelcache.img4> out.macho` decompresses IMG4 → IM4P →
krnl and writes a loadable Mach-O (~60MB for a 26.x cache). That Mach-O — not the
IMG4 — is what a disassembler or a struct-offset tool wants; keep it in a cache
dir (e.g. `.w0lfsword/kernelcaches/`) rather than re-decompressing per run.
