---
name: ios-media-frameworks
description: "Use for userspace framework exploit research: audio decoding (AudioToolbox/CoreAudio/ALAC), fonts (CoreText/FontParser), media parsing (CoreMedia/PDF/ImageIO), and open-source Apple code audits."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 9000
covers: [AudioToolbox, CoreAudio, ALAC, CoreMedia, CoreText, FontParser, PDFKit, libxml2, ICU, mDNSResponder, media fuzzing, dyld cache RE]
learns_from:
  - projects/W0lfSword
platforms: [Linux host, macOS host, iOS 17.0-27.0]
triggers:
  - audio decode bug
  - ALAC
  - AudioToolbox
  - CoreAudio
  - CoreMedia
  - font parsing
  - FontParser
  - PDF parsing
  - media framework fuzz
  - framework buffer overflow
  - libxml2
  - mDNSResponder
  - ICU
  - Quick Look
  - ModelIO
  - dyld shared cache extract
related_skills:
  - ios-misc-tooling
  - ios-research-methodology
  - ios-webkit-exploit
  - ios-sandbox-escape
---

# iOS Media & Framework Exploit Research

Userspace attack surface beyond the kernel: audio decoding, fonts, media
containers, text/XML. Where the parsers are, what is auditable vs
closed, and how to hunt.

## Attack surface (ranked)

1. **Audio decoding** — AudioToolbox (AudioFile, AudioFileStream,
   AudioConverter, ExtAudioFile, AudioQueue), CoreAudio codec plugins
   (ALAC, AAC), CoreMedia audio paths. Formats: CAF, WAVE, AIFF, MP3,
   ADTS/AAC, ALAC, M4A, FLAC, Opus. Entry points: ExtAudioFileOpenURL,
   AudioFileOpen, AudioFileStreamOpen, AVAudioPlayer,
   AVAudioEngine/AVAudioPlayerNode. Closed source except ALAC.
2. **Fonts** — CoreText + libFontParser.dylib / libType1Scaler.dylib
   (closed). Fonts reach the parser from Safari web fonts, Mail,
   Messages, PDFs, Quick Look. Historically dense CVE family:
   CVE-2015-0091-93 (BLEND/STOREWV), CVE-2020-27930/43/44/46 (Type1),
   CVE-2025-43400 (OOB write, fixed 18.7.1/26.0.1, no public PoC).
3. **Media containers** — CoreMedia (MP4/MOV demux, sample buffers,
   HLS, closed captions), CoreGraphics PDF (CGPDFDocument, JBIG2/JPX;
   FORCEDENTRY CVE-2021-30860 is the 0-click template). Closed source.
4. **Open-source Apple parsers** — apple-oss-distributions contains
   Libxml2, ICU, Libiconv, mDNSResponder (verified 2026-08-29).
   Fork-diff vs upstream for unsynced fixes (CVE-2024-25062 precedent);
   mDNSResponder is the only interaction-free remote target (CVE-2015-7987
   record-decoder overflows as template).

## Auditable vs closed (ground truth, 2026-08-29)

- apple-oss-distributions has ONLY: Libxml2, ICU, Libiconv, mDNSResponder.
- CoreAudio / AudioToolbox / CoreMedia / CoreText / PDFKit / ModelIO /
  Quick Look / ImageIO / sqlite: NOT in the org. opensource.apple.com dead.
- **apple/ALAC** (github.com/apple/ALAC) is the only open-source Apple
  audio code: the production ALAC codec reference implementation
  (Apache 2.0). Everything else is binary-only: extract from the dyld
  shared cache and reverse.

## Verified ALAC findings (BB-038/BB-039 family)

ALACDecoder.cpp (apple/ALAC codec/):

- **partialFrame numSamples heap overflow**: 1-bit partialFrame flag
  overrides the caller's numSamples with 32 bits from the bitstream
  (ALACDecoder.cpp:250-254, 401-405) with no bound against
  mConfig.frameLength, which alone sizes mMixBufferU/V + mPredictor
  (calloc at Init, :135-139). Overflow sites: `mMixBufferU[i] = val`
  (:309 uncompressed SCE), `*outPtr++ = del` in dyn_decomp
  (ag_dec.c:321), mShiftBuffer writes (:336, :520-524), unmix24/32
  shiftUV OOB reads (matrix_dec.c). Also triggers with caller
  numSamples > frameLength and no partialFrame. ASAN-verified.
- **Init() magic cookie OOB read**: `theActualCookie[4..7]` read for
  'frma'/'alac' atom sniffing BEFORE any size check (ALACDecoder.cpp:
  101-113); `theCookieBytesRemaining -= 12` underflows for 5-12 byte
  cookies, then 24 bytes parse from a shifted pointer. ASAN-verified
  with a 4-byte cookie (stack-buffer-overflow READ at :102).
- **Unbounded bitstream reads**: BitBufferRead/BitBufferReadSmall
  (ALACBitUtilities.c:42-86) read cur[0..2] with the end check
  commented out; truncated frames walk past the packet buffer
  (ASAN-verified: heap-buffer-overflow READ). Bounds checking is
  declared the caller's job and the callers do not do it.

Reproduction harness pattern: build the crafted stream with the codec's
own BitBufferWrite (no hand-assembled bits), cookie frameLength=1 +
partialFrame numSamples=0x100000, decode under -fsanitize=address.

Production caveat for bounty: the open-source repo is the reference
implementation Apple ships; the production binary (AudioToolbox ALAC
codec plugin in the dyld cache) must be disassembled and confirmed
before submitting to Apple.

## Hunting playbook

1. **Host-side fuzz first**: ALAC (libFuzzer target over cookie+packet),
   libxml2/ICU/mDNSResponder (buildable on Linux; port OSS-Fuzz
   harnesses; mDNSCore builds with mDNSPosix).
2. **Fork-diff Apple's open parsers vs upstream** — every unsynced
   upstream fix is a candidate finding.
3. **Closed targets**: pull the dyld shared cache (device or IPSW),
   `ipsw dyld extract --dylib <name>` (blacktop/ipsw), decompile with
   Ghidra/ipsw, diff two iOS versions to recover unannounced fixes
   (CVE-2025-43400 playbook: 18.4.1 vs 18.7.1 libFontParser), hunt
   siblings in the fixed code region.
4. **On-device probe**: imgio_probe-style Theos tool driving
   ExtAudioFile/AVAudioPlayer (audio) or CTFontCreateWithData (fonts)
   or AVURLAsset (media) over a mutated corpus; the jailbroken 18.4.1
   SE2 is a pre-fix baseline for several 2025 CVEs.
5. **Delivery surfaces**: Quick Look thumbnail generation auto-parses
   received files (FORCEDENTRY delivery path), Messages audio/video
   attachments, Safari web fonts, Mail.

## Known-good references

- Project Zero: "Breaking the Sound Barrier" CoreAudio fuzzing series
  (CVE-2024-54529), "One font vulnerability to rule them all"
  (CVE-2015-0091-93), 0-days-in-the-wild RCA for CVE-2020-27930,
  FORCEDENTRY deep dive (2021-12).
- Citizen Lab FORCEDENTRY analysis; NVD for exact fix versions.
- blacktop/ipsw for dyld cache extraction; theapplewiki Dev:dyld_shared_cache.
