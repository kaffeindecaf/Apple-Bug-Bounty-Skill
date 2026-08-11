---
name: ios-coretrust-bypass
description: "Use for iOS CoreTrust bypass including fastPathSign, CMS signature, perma-sign, AMFI userspace bypass, and TrollStore internals."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 8192
covers: [CoreTrust, AMFI, code signing bypass, perma-sign, TrollStore, fastPathSign, entitlement injection, CMS signature, provisioning]
platforms: [iOS 14.0-17.0, arm64/arm64e]
learns_from:
  - projects/TrollStore
  - projects/opainject
triggers:
  - CoreTrust
  - CoreTrust bypass
  - code signing bypass
  - perma-sign
  - TrollStore
  - fastPathSign
  - AMFI bypass
  - entitlement injection
  - provisioning profile
  - CMS signature
  - code directory hash
  - installd bypass
related_skills:
  - ios-security-pentesting
  - ios-bootchain-exploit
  - ios-code-injection
  - ios-kernel-exploit
cross_reference_rules:
  - If AMFI/proc.p_flag or kernel-level signing bypass → load ios-kernel-exploit
  - If trust cache injection (boot-level) → load ios-bootchain-exploit
  - If ROP-based code injection for unsigned dylibs → load ios-code-injection
  - If bug bounty reporting for CoreTrust bugs → load ios-security-pentesting
  - If researching new AMFI/CoreTrust bugs → load ios-research-methodology
research_first: true
---

# iOS CoreTrust Bypass — Code Signing, TrollStore, Perma-Sign

> **Skill type:** Specialized — code signing and CoreTrust bypass
> **Platforms:** iOS 14.0-17.0, arm64/arm64e
> **Learns from:** `projects/TrollStore/`, `projects/opainject/`
> **Last updated:** 2026-08-11

---

## When to Use This Skill

Use when the task involves:
- CoreTrust code signing bypass (CVE-2022-26766, CVE-2023-41991)
- Permanently signing IPAs without a paid developer certificate (perma-sign)
- TrollStore internals — fastPathSign, RootHelper, PersistenceHelper
- CMS (Cryptographic Message Syntax) signature manipulation
- CodeDirectory hash computation and cdhash injection
- AMFI bypass at the userspace level
- Installd bypass for IPA installation
- Entitlement injection and provisioning profile manipulation

---

## DYNAMIC CROSS-REFERENCE NOTICE

CoreTrust is the code signing layer. When the conversation moves:

- **Kernel-level AMFI bypass** (proc.p_flag, P_AMFI_DISABLED) → load `ios-kernel-exploit.md`
- **Boot-level trust cache injection** (StaticTrustCache, checkm8) → load `ios-bootchain-exploit.md`
- **ROP-based code injection** (injecting unsigned dylibs) → load `ios-code-injection.md`
- **Bug bounty for CoreTrust bugs** → load `ios-security-pentesting.md`
- **Finding new CoreTrust vulnerabilities** → load `ios-research-methodology.md`

---

## RESEARCH-FIRST DIRECTIVE

If the user mentions a new CoreTrust bypass, a TrollStore fork, an updated AMFI mechanism, or an Apple security advisory — **research it before answering.** Fetch the source, understand the new technique, then answer.

---

## 1. CoreTrust Architecture

### 1.1 What CoreTrust Does

CoreTrust (part of AMFI — Apple Mobile File Integrity) verifies that every executable on iOS is signed by a trusted certificate:

```
App Launch:
  1. dyld loads the Mach-O binary
  2. AMFI reads the CMS signature blob at the end of the binary
  3. CoreTrust validates the certificate chain against Apple's root CA
  4. AMFI checks entitlements against the provisioning profile
  5. AMFI enforces library validation (all loaded dylibs must be signed)
  6. Hardened Runtime restrictions enforced
```

### 1.2 The CMS (Cryptographic Message Syntax) Signature

Every signed iOS binary has a `LC_CODE_SIGNATURE` load command pointing to a blob containing:
- **SuperBlob** — container for all signature data
- **CodeDirectory** — hashes of every page of the binary (SHA1 + SHA256)
- **Entitlements** — embedded plist of granted entitlements
- **CMS Signature** — cryptographic signature over the CodeDirectory
- **Certificate chain** — from leaf certificate to Apple root CA

---

## 2. CVE-2022-26766 — Original CoreTrust Bug

**Found by:** Linus Henze, Google TAG
**iOS:** 14.0 beta 2 - 15.x (fixed in 15.7.x / 16.x)
**Bounty:** Not publicly disclosed

### The Bug

CoreTrust accepted signatures where the certificate chain was malformed in a specific way — it would accept certificates that chained to Apple's root CA but were not developer certificates. This meant:
1. A self-signed certificate could be used if crafted to appear as Apple's CA
2. Any entitlement could be embedded in the signature
3. No provisioning profile validation was performed

### TrollStore 1.0 Usage

TrollStore exploited this by:
1. Ad-hoc signing the IPA with `ldid` (embeds entitlements + basic signature)
2. Patching the Mach-O to replace the signature blob with a crafted CMS signature
3. The crafted signature uses a fake certificate chain that CoreTrust incorrectly accepts

---

## 3. CVE-2023-41991 — Second CoreTrust Bug

**Found by:** Google TAG, patch-diffed by @alfiecg_dev
**iOS:** 14.0 beta 2 - 17.0 (fixed in 17.0.1)
**Bounty:** Not publicly disclosed

### The Bug

CoreTrust's multiple signer verification had a flaw — if a binary was signed by multiple signers, CoreTrust would only validate one of them. By crafting a CMS signature with a valid signer AND a malicious signer, the malicious signer's entitlements would be accepted.

### fastPathSign Implementation

```c
// 1. Read the Mach-O, find LC_CODE_SIGNATURE
// 2. Parse SuperBlob → find SHA1 and SHA256 CodeDirectories
// 3. Compute hashes of CodeDirectories
// 4. Load fake CA private key and certificate (hardcoded PEM)
// 5. Create CMS signature blob:
//    - Certificate chain depth: 3
//    - Uses App Store leaf marker OID: 1.2.840.113635.100.6.1.3
//    - Embeds SHA1 and SHA256 cdhashes
// 6. Replace signature blob in Mach-O
// 7. Update load commands for new blob size
```

**Key OID (Object Identifier) for App Store signature:**
```
1.2.840.113635.100.6.1.3  — Apple App Store leaf certificate marker
```
This OID in the signature chain makes CoreTrust treat the binary as an App Store binary, granting broader entitlement acceptance.

---

## 4. TrollStore Architecture

### 4.1 Components

```
TrollStore.app (perma-signed)
├── fastPathSign     — Applies CoreTrust bypass to arbitrary IPAs
├── RootHelper       — Runs as root, installs/manages apps
├── PersistenceHelper — Survives icon cache reloads
└── TrollHelperOTA   — installd bypass on iOS 14-15.6.1
```

### 4.2 RootHelper (root-spawned binary)

```c
// Runs as UID 0 via posix_spawn with:
//   com.apple.private.persona-mgmt entitlement
// Functions:
//   installApp(bundleID, path) — Install an app
//   uninstallApp(bundleID)     — Remove an app
//   installIpa(path)           — Install from IPA file
//   installTrollStore()        — Self-install TrollStore
//   registerPath(path)         — Rebuild icon cache (uicache)

// Signing flow per app:
//   1. Ad-hoc sign with ldid
//   2. Apply CoreTrust bypass via fastPathSign
//   3. Fix entitlements for unsandboxing
```

### 4.3 PersistenceHelper

Installs into a system app by replacing its binary:

```
1. Find a system app (e.g., Tips.app)
2. Backup original binary → Tips_TROLLSTORE_BACKUP
3. Copy PersistenceHelper → Tips.app/Tips (replaces binary)
4. When SpringBoard reloads icon cache → PersistenceHelper runs
5. PersistenceHelper re-registers all TrollStore apps as "System"
6. Apps persist across reboots
```

### 4.4 Entitlements for Unsandboxing

```
Standard entitlements granted by TrollStore:
  com.apple.private.security.no-sandbox
  platform-application
  com.apple.private.security.storage.AppDataContainers
  com.apple.private.persona-mgmt

Banned on iOS 15+ A12+ (require PPL bypass):
  com.apple.private.cs.debugger
  dynamic-codesigning
  com.apple.private.skip-library-validation
```

---

## 5. Versions and Compatibility

| iOS Version | TrollStore Support | Method | Notes |
|------------|-------------------|--------|-------|
| 14.0 b2 - 14.8.1 | Yes | CoreTrust (CVE-2022-26766) + installd bypass | TrollHelperOTA |
| 15.0 - 15.6.1 | Yes | CoreTrust (CVE-2022-26766) + installd bypass | TrollHelperOTA |
| 16.0 - 16.6.1 | Yes | CoreTrust (CVE-2023-41991) | No installd bypass needed |
| 16.7 RC (20H18) | Yes | CoreTrust (CVE-2023-41991) | RC only, not 16.7.1+ |
| 17.0 | Yes | CoreTrust (CVE-2023-41991) | Last supported version |
| 17.0.1+ | NO | Fixed | CVE-2023-41991 patched |
| 15.1+ A12+ | Banned entitlements | Some entitlements require PPL bypass | `com.apple.private.cs.debugger` etc. |

---

## 6. Key Offsets and Structures

### 6.1 Mach-O Code Signature LC

```c
struct linkedit_data_command {
    uint32_t cmd;        // LC_CODE_SIGNATURE = 0x1D
    uint32_t cmdsize;    // 16
    uint32_t dataoff;    // File offset to signature blob
    uint32_t datasize;   // Size of signature blob
};
```

### 6.2 CodeDirectory Structure

```c
struct CodeDirectory {
    uint32_t version;
    uint32_t flags;
    uint32_t hashOffset;     // Offset to hash array
    uint32_t identOffset;    // Offset to identifier string
    uint32_t nSpecialSlots;  // Number of special hash slots
    uint32_t nCodeSlots;     // Number of code page slots
    uint32_t codeLimit;      // Limit of code pages
    uint8_t  hashSize;       // Size of each hash (20 = SHA1, 32 = SHA256)
    uint8_t  hashType;       // 1 = SHA1, 2 = SHA256
    // ... more fields
    // Followed by hash array: nSpecialSlots + nCodeSlots hashes
    // Followed by identifier string
};
```

### 6.3 CDHash Computation

```bash
# The cdhash is the SHA256 of the CodeDirectory blob
# Not the hash of the binary itself
codesign -dvvv binary 2>&1 | grep CDHash

# Manual computation:
# 1. Find CodeDirectory in SuperBlob
# 2. Compute SHA256(CodeDirectory blob)
# 3. This is the cdhash
```

---

## 7. Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Wrong iOS version | App fails to launch with "invalid signature" | Check version table — 17.0.1+ patched CVE-2023-41991 |
| Entitlement too powerful | App crashes on launch | Remove banned entitlements on iOS 15+ A12+ |
| Signature blob too large | Mach-O load command overflow | Optimize CMS signature, reduce certificate chain |
| PersistenceHelper not running | Apps disappear after reboot | Verify system app binary replacement, check icon cache |
| CDHash mismatch | CoreTrust rejects binary | CDHash must be exactly SHA256 of entire CodeDirectory |
| OID missing | Binary not treated as App Store | Include 1.2.840.113635.100.6.1.3 leaf marker in CMS |

---

## 8. Quick Reference

```
CoreTrust bugs:    CVE-2022-26766 (original), CVE-2023-41991 (TrollStore 2.0)
TrollStore iOS:    14.0b2 - 17.0 (17.0.1+ patched)
fastPathSign:      Replaces CMS signature with fake App Store chain
RootHelper:        Runs as root via posix_spawn + persona-mgmt
Persistence:       Replaces system app binary, survives icon cache reload
CDHash:            SHA256 of CodeDirectory blob
App Store OID:     1.2.840.113635.100.6.1.3
LC_CODE_SIGNATURE: 0x1D load command
Banned on A12+:    debugger, dynamic-codesigning, skip-library-validation
```

---

## 9. Reference Projects

| Project | Technique | iOS | Path |
|---------|-----------|-----|------|
| TrollStore | CoreTrust bypass + perma-sign | 14-17 | `projects/TrollStore/` |
| opainject | Ad-hoc signing + entitlement bypass | 14-17 | `projects/opainject/` |

---

## 10. Contribute Back

**Found something critical?** A new CoreTrust bypass for iOS 17.0.1+? An entitlement that was previously restricted now accessible? A new OID that grants different privileges? Contribute it back.

```bash
git add skills/ios-coretrust-bypass.md
git commit -m "feat: new CoreTrust bypass for iOS 18"
gh pr create --repo kaffeindecaf/Apple-Bug-Bounty-Skill \
  --title "CoreTrust bypass improvement" \
  --body "## What was found\n\n## iOS version\n\n## CVE (if applicable)\n\n## Technique details\n\n## Verification"
```

Repository: https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill
