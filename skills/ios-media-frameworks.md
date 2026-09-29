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
  - ios-poc-lab
  - ios-variant-hunting
  - ios-research-methodology
  - ios-webkit-exploit
  - ios-sandbox-escape
cross_reference_rules:
  - If the parser can be built and fuzzed on a host → load ios-poc-lab
  - If the bug class matches a published advisory → load ios-variant-hunting
research_first: true
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

## Open-source ALAC decoder - how to audit it

github.com/apple/ALAC is the only open-source Apple audio code, so it is the one
audio target you can both read and fuzz. Classes that pay off, in order:

- **Length fields the stream can override.** A value that arrives from the
  bitstream (a partial-frame flag, a sample count, an atom size) used to size or
  index a buffer without being bounded against the config the buffer was
  allocated for.
- **Header parsing that runs before validation.** Atom sniffing that reads fixed
  offsets out of the magic cookie before the remaining-size check, and the
  subtraction that then underflows on a short cookie.
- **Bit readers without an end check.** BitBufferRead/BitBufferReadSmall read
  ahead of the packet end and leave the bound to the caller; callers that skip it
  walk off a truncated frame.

Harness pattern that exposes all three: build the crafted stream with the codec's
own BitBufferWrite (never hand-assemble bits), drive Init + Decode under
`-fsanitize=address`, and assert on the ASAN report rather than on the returned
status.

Production caveat before any submission: the open-source repo is the reference
implementation, not the shipping code. The production binary is the AudioToolbox
ALAC codec plugin in the dyld shared cache - extract it, disassemble it, confirm
the site is the same shape, and only then report.

Sites found in a live audit are unreported until Apple ships a fix, so they stay
out of this repo; they live in the local-only notes.

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
