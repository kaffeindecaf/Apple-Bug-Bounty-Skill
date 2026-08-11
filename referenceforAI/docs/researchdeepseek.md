# researchdeepseek.md — Comprehensive W0lfSword Exploit Analysis

> **Date:** 2026-08-11 | **Analyst:** kaffeindecaf (malware-analysis skill audit)  
> **Scope:** W0lfSword + 6 referenceforAI projects | **Findings:** 17 new bugs beyond existing 14 in BUG_BOUNTY.md

---

## Table of Contents

1. [Exploit Architecture Deep Dive](#1-exploit-architecture-deep-dive)
2. [NEW Bug Bounty Findings (BB-015 through BB-031)](#2-new-bug-bounty-findings)
3. [PR-Worthy Fixes](#3-pr-worthy-fixes)
4. [Reference Project Analysis](#4-reference-project-analysis)
5. [What I Would Change](#5-what-i-would-change)
6. [iOS Exploit Development Learning Path](#6-ios-exploit-development-learning-path)

---

## 1. Exploit Architecture Deep Dive

### 1.1 DarkSword Kernel Exploit (ICMPv6 Socket Spray + IOSurface OOB)

The core exploit achieves kernel R/W through a **physical memory read/write primitive** that combines three racing components:

**Component 1: ICMPv6 Socket Spray (`kexploit_opa334.m:400-500`)**
- Creates ~27,000 SOCK_DGRAM RAW ICMPv6 sockets
- Each socket's `inpcb` (Internet Protocol Control Block) is a kernel heap allocation (~512 bytes)
- Spray fills the kernel zone allocator's buckets with these predictable PCB structures
- The `icmp6filter` pointer inside each PCB (offset ~0xA8) normally points to the socket's ICMPv6 filter data buffer
- By corrupting this pointer, we can make `setsockopt(ICMP6_FILTER)` / `getsockopt(ICMP6_FILTER)` read/write arbitrary kernel memory

**Component 2: IOSurface Physical Memory Mapping (`kexploit_opa334.m:200-350`)**
- `IOSurfaceCreate` with `IOSurfaceMemoryRegion` + `PurpleGfxMem` properties creates physically contiguous kernel memory
- The IOSurface has an `IOSurfaceAddress` property that maps to the **physical** page backing the surface
- By `mach_vm_map()` -ing this memory object into our process, we get a userspace ptr to the physical page
- The crucial race: call `mach_vm_map()` on a **freed** surface's memory entry → the kernel remaps the physical page while we're still writing to it via `pwritev` → physical OOB access

**Component 3: Socket Corruption (`kexploit_opa334.m:600-900`)**
- `physical_oob_read_mo()` races `pwritev` (writing to physical memory via file descriptor) against `mach_vm_map` (remapping freed IOSurface memory) on a separate `free_thread`
- When the race wins, the `pwritev` reads from or writes to physical memory that is in the process of being freed/reallocated
- We scan this physical OOB data looking for our sprayed socket PCBs (identified by markers written during spray)
- When found, we corrupt the `icmp6filter` pointer to instead point to `inp_listnext` — this is a self-referential pointer in the PCB that points to a **different kernel address** (usually the socket's own PCB or an adjacent one)
- After corruption, `getsockopt(ICMP6_FILTER)` reads kernel memory from wherever `icmp6filter` points
- This gives us **arbitrary kernel read** via `getsockopt` and **arbitrary kernel write** via `setsockopt` (with a 0x20-byte granularity, the size of ICMP6_FILTER data)

**The `early_kread64` / `early_kwrite64` primitives:**  
These wrap the `setsockopt`/`getsockopt` mechanism:
```
early_kread64(addr):
    1. setTargetKaddr(addr) → copies addr into controlData buffer → setsockopt(controlSocket, IPPROTO_ICMPV6, ICMP6_FILTER, controlData, 0x20)
    2. getsockopt(rwSocket, IPPROTO_ICMPV6, ICMP6_FILTER, resultBuf, &len)
    3. Return first 8 bytes of resultBuf → this is kread64(addr)

early_kwrite64(addr, val):
    1. Same as read, but setsockopt on rwSocket with the value to write
    2. Value lands at addr because the corrupted icmp6filter redirects the setsockopt write
```

### 1.2 Sandbox Escape — Two Strategies

**Strategy A: Direct Extension Patching (`sandbox_escape.m:127-245`)**

Walks the kernel memory chain: `proc → proc_ro → ucred → cr_label → sandbox → extension_set` and directly overwrites extension data:
- Sets extension path to `"/"` (root filesystem)
- Rewrites class name to `"com.apple.app-sandbox.read-write"`
- Fills all 16 hash slots with the same extension
- **Key insight:** Extension class names and paths are stored in kernel heap (not read-only), so they can be overwritten with kernel R/W

**Strategy B: Extension Borrowing (`sandbox.m:314-356`)**

Instead of crafting extensions from scratch, copies existing (legitimate) sandbox extensions from system daemons:
- Finds `cfprefsd`/`securityd`/`notifyd`/`lsd` processes via `proc_find_by_name`
- Copies their `extension_set.type_buckets[]` pointers directly into our process's extension_set
- **Critical risk:** If the source daemon dies, the borrowed extension_set contains dangling pointers → kernel panic

### 1.3 SSV Bypass — Vnode Data Pointer Redirect (`vnode.m`)

The Signed System Volume (SSV) makes `/System/`, `/usr/`, `/bin/` read-only at the APFS level. The bypass works by:
1. Opening both source and destination files
2. Finding their `vnode` structures via `proc → filedesc → fileproc → fileglob → vnode`
3. Swapping `vnode.v_data` pointers — the destination vnode thinks it's the source file's data
4. Writing through the swapped vnode writes to the destination's actual on-disk data
5. The APFS layer doesn't check this because it only validates the vnode, not the data pointer

### 1.4 USBLoader8 / Checkm8 Chain (`usbliter8-fun/`, `usbliter8-fun2/`)

Checkm8 (CVE-2018-XXX) is the bootrom exploit for A5-A11 chips (extended to A12/A13 via USBLoader8). The exploit chain:
1. Hardware enters PWN DFU mode via RP2350 (Raspberry Pi Pico 2) USB injection
2. Uploads patched iBSS → patched iBEC (SecureROM secondary loaders)
3. Patches bypass image validation (`image4_validate_property_callback → mov x0,#0; ret`)
4. Loads patched kernelcache with sandbox hooks disabled (`file_check_mmap → mov x0,#0; ret`)
5. Loads patched ramdisk with SSH + custom binaries
6. Post-boot: hacktivation, VNC, USB networking, trust cache injection

### 1.5 WebKit-to-Kernel Chain (`DarkSword-RCE/`)

The leaked production exploit chain:
1. **WebKit RCE:** Safari loads hidden iframe → JavaScript Web Worker → JIT bug in GPU process → arbitrary native function calls
2. **GPU Sandbox Escape:** Decodes crafted IPC messages through `RemoteGraphicsContextGL_*` stubs → OOB in GPU process → R/W in GPU's (broader) sandbox
3. **Kernel Exploit:** DarkSword ran from GPU process → full kernel R/W
4. **PAC Bypass:** Uses GPU-register-based fcall with pre-computed PAC gadgets

---

## 2. NEW Bug Bounty Findings

### BB-015: Thread-Safety Race in `early_kread64` / `setTargetKaddr` [HIGH]

**ID:** BB-015  
**File:** `kexploit/kexploit_opa334.m:132-141` + early_kread64/early_kwrite64  
**Status:** New finding — exploitable under retry loop + multi-threaded hooks

**Description:**  
`setTargetKaddr()` writes to the global `controlData` buffer then calls `setsockopt`. There is **no mutex** protecting this sequence. Under the retry loop (which re-executes exploit steps), multiple background threads call kread simultaneously (e.g., `ensureSSVActive` on main thread + `runSSVDiagnosticsOnce` on background queue).

If thread A calls `setTargetKaddr(0xABCD)` and thread B calls `setTargetKaddr(0x1234)` before thread A's `setsockopt` executes, thread A's `getsockopt` reads from address `0x1234` instead of `0xABCD` → **silent data corruption**.

This was not an issue when the exploit ran once (single-threaded) but becomes critical with:
- The retry loop running kread in background
- NSFileManager hooks calling `ensureSSVActive` → kread on main thread
- The crash monitor thread calling kread

**Impact:** Silent kernel data corruption during reads/writes. Could cause: incorrect sandbox extension patching (extensions point to wrong memory), write to unintended kernel address, kernel panic from writing to unmapped memory.

**Fix:** Add a pthread_mutex around the `setTargetKaddr` + `setsockopt`/`getsockopt` pair. Alternatively, use a per-thread controlData buffer.

**Apple Bounty:** N/A (bug in exploit code, not kernel)

---

### BB-016: `S()` Macro Sign-Extension Logic Bug [MEDIUM]

**ID:** BB-016  
**File:** `sandbox_escape.m:71-73`  
**Status:** New finding — fragile sign extension that works by accident

**Description:**  
```c
#define S(x) ({ uint64_t _v = __xpaci_sbx(x); \
    ((_v >> 32) > 0xFFFF ? (_v | 0xFFFFFF8000000000ULL) : _v); })
```
This checks if `_v >> 32 > 0xFFFF` to decide whether to sign-extend. For valid kernel pointers (e.g., `0xFFFFFFDC00123456`), `_v >> 32 = 0xFFFFFFDC` which IS > `0xFFFF`, so it works. However:

1. For PAC-signed pointers on arm64e, the upper bits encode the PAC signature, which varies unpredictably — the pointer could be `0x001234560000XXXX` where `>>32 = 0x00123456` which IS > 0xFFFF, causing incorrect sign extension to `0xFFFFFFFFDEADBEEF`
2. For heap pointers near the bottom of kernel space (`0xFFFFFFDC00000000`), `>>32 = 0xFFFFFFDC` works
3. The macro assumes 47-bit virtual addresses (4-level paging). On A18 with 5-level paging (T1SZ=0x11 → 47-bit still), this is correct. If Apple moves to 52-bit addressing, it breaks.

**Fix:** Use the validated `kread_smrptr()` function instead of the `S()` macro, or check against `VM_MIN_KERNEL_ADDRESS` directly.

---

### BB-017: `K()` Macro Uses Wrong Comparison Value [MEDIUM]

**ID:** BB-017  
**File:** `sandbox_escape.m:73`  
**Status:** New finding — rejects some valid kernel pointers

**Description:**  
```c
#define K(x) ((x) > 0xFFFFFF8000000000ULL)
```
This checks `> 0xFFFFFF8000000000` which means values like `0xFFFFFF8000000001` would pass. But kernel addresses actually start at `VM_MIN_KERNEL_ADDRESS = 0xFFFFFFDC00000000` on iOS 26. Values in the range `0xFFFFFF8000000000..0xFFFFFFDBFFFFFFFF` would pass K() validation but are not actually valid kernel addresses.

Worse, a PAC-stripped pointer might be `0x00000001A8000000` (32-bit value with bits set). This would FAIL the K() check even though it's a valid kernel pointer whose PAC bits were stripped by `__xpaci_sbx`.

**Fix:** Replace with `ptr_in_kernel(x)` which uses the actual VM bounds.

---

### BB-018: Borrowed Extension Set — Dangling Pointers After Daemon Death [HIGH]

**ID:** BB-018  
**File:** `kexploit/sandbox.m:314-356`  
**Status:** New finding — can cause kernel panic

**Description:**  
`borrow_sandbox_ext()` copies the victim daemon's `type_buckets[]` pointer values directly into the self process's extension_set. If the source daemon (e.g., `cfprefsd`) crashes or is killed by jetsam:
1. The daemon's kernel memory is freed (zone allocator reuses the pages)
2. The self process's extension_set still holds pointers to the freed memory
3. Next sandbox_check reads freed kernel memory → reads garbage or triggers a kernel guard page fault → **kernel panic**

This is particularly likely because cfprefsd is a low-priority daemon that jetsam will kill under memory pressure.

**Attack vector for DoS:** Cause memory pressure while the exploit is active → cfprefsd killed → kernel panic on next file operation.

**Fix:** Instead of borrowing pointers, copy the extension struct data into newly allocated kernel memory (or use the direct patch approach exclusively).

---

### BB-019: `vnode_get_child_vnode` — Concurrent Rename Race [LOW]

**ID:** BB-019  
**File:** `kexploit/vnode.m:153-172`  
**Status:** New finding — returns wrong vnode under concurrent rename

**Description:**  
The function reads `vp_name` from each child vnode and compares it to `child_filename`. Between reading the name and validating the vnode, another thread could rename the file:
1. Thread A: reads `vp_name = "foo"`, matches `child_filename = "foo"`
2. Thread B: renames "foo" → "bar"
3. Thread A: returns the vnode — but it's now named "bar", not "foo"

Additionally, the `blacklist_vdata` guard at line 166 is insufficient if a newly created file happens to reuse the same `v_data` pointer as the blacklisted one (possible with zone allocator reuse after the blacklisted file is closed).

**Fix:** After finding the candidate vnode, re-read `vp_name` and compare again before returning. Or use a sequence number/timestamp check.

---

### BB-020: `sandbox_escape` No Retry — Silently Fails [MEDIUM]

**ID:** BB-020  
**File:** `sandbox_escape.m:127-245`  
**Status:** New finding — single-shot escape with no retry

**Description:**  
Unlike `patch_sandbox_ext()` in `sandbox.m` which has 3 retries + borrow fallback, `sandbox_escape()` has NO retry logic. If the ucred pointer scan fails (offset search doesn't find ucred at expected locations), it returns -1 immediately.

The exploit driver (`TweakExploit.m`) retries the WHOLE exploit chain on failure (5 retries), but each retry re-executes the ICMPv6 socket spray + IOSurface race from scratch — 30+ seconds of work redone for a single offset scan failure.

**Fix:** Add local retry within `sandbox_escape()` for the ucred scan (try all offsets again from a fresh proc_self() read). Only propagate failure to the outer loop after 3 local retries.

---

### BB-021: `free_thread` Busy-Wait Spin on Single-Core Devices [MEDIUM]

**ID:** BB-021  
**File:** `kexploit/kexploit_opa334.m:198-199`  
**Status:** New finding — thread starvation on A10/A11

**Description:**  
```c
void *free_thread(void *arg) {
    while (freeThreadStart == 0)
        ;
```
This is a busy-wait loop with no yield/sleep. On multi-core devices (A12+), the main thread runs on a different core so this doesn't block it. But on A10/A11 devices (2+2 cores, performance cores), if both threads end up on the same core:
1. free_thread spins, consuming 100% of core time
2. Main thread never gets CPU time to set `freeThreadStart = 1`
3. → **deadlock**

**Chance:** Low on modern iOS (scheduler tends to distribute threads), but plausible on heavily loaded devices.

**Fix:** Add `usleep(100)` or `pthread_yield_np()` in the spin loop.

---

### BB-022: `khexdump` Prints Uninitialized Memory [LOW]

**ID:** BB-022  
**File:** `kexploit/krw.m:88-129`  
**Status:** New finding — potential info leak through log output

**Description:**  
`khexdump` allocates `data` with `malloc(size)` but only fills it in 8-byte chunks via `early_kread64`. For sizes not divisible by 8, the last (size % 8) bytes of `data` are **uninitialized heap memory**. When printed as hex/ASCII, this leaks heap contents from the process — potentially including:
- ObjC class pointers (can be used to defeat ASLR)
- String constants (e.g., bundle IDs, file paths)
- Stack canary values

**Fix:** `calloc()` instead of `malloc()`, or memset the buffer to 0 before filling.

---

### BB-023: Duplicate Extern Declarations in `offsets.h` [LOW]

**ID:** BB-023  
**File:** `kexploit/offsets.h:29-30, 32-33`  
**Status:** New finding — compile warning, potential linker issues

**Description:**  
`off_thread_machine_jop_pid` and `off_thread_machine_rop_pid` are each declared `extern uint32_t` twice. Depending on the compiler and flags, this could cause a "duplicate symbol" warning or in rare cases, a linker error with `-fno-common`.

**Fix:** Remove the duplicate declarations (lines 30 and 33).

---

### BB-024: `ensureSSVActive` Mutex Deadlock via Re-entrant File Hooks [HIGH]

**ID:** BB-024  
**File:** `Tweak.m` (ensureSSVActive implementation)  
**Status:** New finding — theoretical deadlock under specific file operation sequences

**Description:**  
`ensureSSVActive` holds a `pthread_mutex_t` while performing kernel R/W via `kread64`/`kwrite64`. During this period, Filza may attempt file operations that trigger our NSFileManager hooks. The hooks call `ensureSSVActive` → tries to lock the same mutex → **deadlock**.

This requires a specific sequence:
1. Main thread calls `ensureSSVActive` (locks mutex)
2. While holding mutex, calls `kread64` which writes to `controlData` buffer
3. A background queue triggered by Filza calls an NSFileManager hook
4. The hook calls `ensureSSVActive` → `pthread_mutex_lock` on already-locked mutex → **deadlock**

**Likelihood:** The mutex block is short, so the window is narrow. But with the retry loop running concurrent kreads, this becomes more likely.

**Fix:** Use `pthread_mutex_trylock` in the hooks' fast path and skip SSV activation if mutex is held (the main thread will complete it shortly). Or use a recursive mutex (`PTHREAD_MUTEX_RECURSIVE`).

---

### BB-025: `sandbox_escape` Uses Pre-KRW Primitives Without Guard [MEDIUM]

**ID:** BB-025  
**File:** `sandbox_escape.m:127`  
**Status:** New finding — uses `early_kread64()` without checking `exploit_is_done()`

**Description:**  
`sandbox_escape()` calls `early_kread64()` directly — this is the socket-based primitive that requires `rwSocket`/`controlSocket` to be set up. If called before the socket corruption succeeds (before `exploit_is_done()` = true), it reads from uninitialized/bogus socket data.

`patch_sandbox_ext()` in `sandbox.m` has the guard at line 100-103. But `sandbox_escape()` does NOT check `exploit_is_done()`.

**Fix:** Add `if (!exploit_is_done()) return -1;` at the top of `sandbox_escape()`.

---

### BB-026: `set_rw_class` Blind Write at `da+32` [MEDIUM]

**ID:** BB-026  
**File:** `sandbox_escape.m:105-123`  
**Status:** New finding — hardcoded offset into extension data buffer

**Description:**  
`set_rw_class()` writes the class name string at `data_addr + 32` bytes blindly, assuming the extension data buffer layout is: `[path_string\0][32 bytes padding?][class_string\0]`. There's no validation that:
1. The buffer is at least 64 bytes long (32 + 33 bytes for class string)
2. The bytes at offset 32 are unused/padding
3. The layout hasn't changed between iOS versions

If the buffer is shorter, this overflow corrupts adjacent kernel heap objects.

**Fix:** Read `data_len` from the extension struct first, verify enough space exists before writing.

---

### BB-027: Zip/Unzip Main Thread Blocking — Watchdog Risk [LOW]

**ID:** BB-027  
**File:** `Tweak.m:139-167, 170-240`  
**Status:** New finding — main thread blockage for large files

**Description:**  
The zip/unzip hooks run on Filza's calling thread (likely main thread). For large archives (500MB+), the operations can take 30+ seconds. iOS's watchdog kills apps that block the main thread for >10 seconds.

**Fix:** Wrap the actual zip/unzip work in `dispatch_async` to a background queue, return immediately, and use a callback or completion handler.

---

### BB-028: `get_rootvnode` Assumes Fixed Parent Chain [MEDIUM]

**ID:** BB-028  
**File:** `kexploit/vnode.m:60-72`  
**Status:** New finding — hardcoded parent walk

**Description:**  
`get_rootvnode()` assumes: `v_textvp(launchd) → /sbin/launchd → v_parent → /sbin → v_parent → /`. If Apple moves launchd to a different path (e.g., the sealed system volume migration in iOS 27+ could put it elsewhere), or adds intermediate directory layers, the function returns wrong vnode.

**Fix:** Walk the v_parent chain until reaching a vnode whose v_parent == itself (root vnode's parent points to itself in XNU). This is generic and handles any filesystem layout.

---

### BB-029: APFS `fsnode` Offset Validation Gap [MEDIUM]

**ID:** BB-029  
**File:** `kexploit/offsets.m:953-956`, `utils/permission_utils.m:105-107`  
**Status:** New finding (extension of BB-012)

**Description:**  
BB-012 documented that if APFS fsnode offsets change, we'd write to wrong fields. The existing code writes UID/GID/mode using hardcoded `v_data + 0x80/0x84/0x88`. Before writing, we should validate:
1. `mode & 0777` is a valid POSIX permission (0-0777)
2. `uid` is a valid UID (typically 0-501)
3. `gid` is a valid GID (typically 0-80)

If any read-back validation fails, the offset is wrong. BB-012 mentioned adding this check but it hasn't been implemented.

**Fix:** Add a `validate_fsnode_offset()` function that reads the struct, checks values are reasonable, and returns error on detection of offset drift.

---

### BB-030: `spray_socket` Memory Exhaustion — No Bounds Check [LOW]

**ID:** BB-030  
**File:** `kexploit/kexploit_opa334.m` (spray_socket region)  
**Status:** New finding — exhausts system socket limits on constrained devices

**Description:**  
The spray creates ~27,000 RAW ICMPv6 sockets. On devices with limited memory (2GB, 3GB), this can exhaust the kernel's socket buffer pool and cause the system to reject new socket creation system-wide. Background daemons that need sockets (push notifications, iCloud sync) will fail silently.

**Fix:** Check available memory (`sysctl hw.memsize`) before spraying and reduce count on low-memory devices. Or handle `ENOBUFS` / `ENOMEM` from socket() gracefully.

---

### BB-031: `offsets_init()` Verification Gap — No Sanity Check on Loaded Offsets [HIGH]

**ID:** BB-031  
**File:** `kexploit/offsets.m` (offsets_init function)  
**Status:** New finding — wrong offset loaded = all kernel R/W corrupt

**Description:**  
`offsets_init()` determines the device model + iOS version and loads a block of offsets. If the wrong block is loaded (e.g., iOS 26.0 block for iOS 26.0.1 device where one offset changed), ALL subsequent kernel R/W operations use wrong offsets. This is particularly dangerous because:

1. Wrong `off_thread_machine_kstackptr` → writes to wrong thread field → **kernel panic**
2. Wrong `off_proc_p_proc_ro` → can't find ucred → sandbox escape silently fails
3. Wrong `off_label_l_perpolicy_sandbox` → reads wrong memory → junk data treated as sandbox ptr

There's no post-load validation that the offsets produce sensible results.

**Fix:** After loading offsets, do a mini-validation:
- Read `proc_self() + off_proc_p_pid` → should return our actual PID
- Read `thread_self + off_thread_machine_kstackptr` → should be a kernel pointer
- Read `proc_self() + off_proc_p_proc_ro` → should be a PAC-signed kernel pointer

---

## 3. PR-Worthy Fixes

### Fix 1: Thread-safe `early_kread64`/`early_kwrite64` (BB-015)
**Priority:** HIGH — data corruption potential
**Files:** `kexploit/kexploit_opa334.m`
**Change:** Add a `pthread_mutex_t` guard around the `setTargetKaddr + setsockopt/getsockopt` sequence. Only ~15 lines of code.

### Fix 2: Replace `S()`/`K()` macros with validated functions (BB-016, BB-017)
**Priority:** MEDIUM — pointer validation bugs
**Files:** `sandbox_escape.m`
**Change:** Replace `S()` with `xpaci() + ptr_in_kernel()`, replace `K()` with `ptr_in_kernel()`. Reuses existing validated code.

### Fix 3: Copy borrowed extension data instead of borrowing pointers (BB-018)
**Priority:** HIGH — kernel panic risk
**Files:** `kexploit/sandbox.m`
**Change:** In `borrow_sandbox_ext()`, instead of copying `type_buckets[]` pointers, read the victim's extension struct data, allocate new kernel memory, and write copies. Prevents dangling pointer panics.

### Fix 4: Add `exploit_is_done()` guard to `sandbox_escape()` (BB-025)
**Priority:** MEDIUM — crash prevention
**Files:** `sandbox_escape.m`
**Change:** One-line addition at top of function.

### Fix 5: Root vnode discovery via `v_parent` chain (BB-028)
**Priority:** MEDIUM — iOS 27 compatibility
**Files:** `kexploit/vnode.m:60-72`
**Change:** Replace fixed 2-step walk with generic parent-chain walk.

### Fix 6: Offset validation on `offsets_init()` (BB-031)
**Priority:** HIGH — prevents silent failures
**Files:** `kexploit/offsets.m`
**Change:** Add ~20 lines of post-load validation with known-good values.

---

## 4. Reference Project Analysis

### 4.1 `bad_query/` — Container Path Traversal

**Technique quality:** HIGH — clever, simple, reliable  
**Why it works:** `containermanagerd` doesn't sanitize the `part_domain` path component. By setting class 13 (SharedSystemDataContainer) and making the part_domain `../../../../../../..<target>`, the path resolution escapes the container root and resolves to arbitrary filesystem paths.

**What we can learn:** This is a "type confusion" sandbox escape — the daemon treats the path as inside a data container, but path traversal makes it point outside. This is simpler and more reliable than our kernel-based sandbox escape. If the kernel exploit fails, we could fall back to this technique for basic file access.

**Limitation:** Only works for specific container classes. Can't grant access to `com.apple.app-sandbox.read-write` (full access). It grants a container-type extension, which is path-specific.

### 4.2 `darksword-kexploit/` — Standalone Exploit CLI

**Quality:** Clean, well-documented, self-contained  
**Key difference from W0lfSword:** No sandbox escape, no vnode redirection, no UI hooks. Pure exploit demonstration. The code is simpler because it doesn't have to be safe — it can call `FAILURE` and `exit()` freely.

**What we can learn:** This is the "reference implementation" to study. The exploit logic is identical to W0lfSword's `kexploit/kexploit_opa334.m` but without the production hardening (retry loops, safe FAILURE macro, thread safety).

### 4.3 `DarkSword-RCE/` — WebKit Full Chain

**Scale:** ~43,000 lines of JS (unminified)  
**Complexity:** EXTREME — production exploit with JS↔native bridging, GPU IPC deserialization, multi-stage PAC bypass  
**Key technique:** `OffscreenCanvas` trick for dlopen from JS — creates an OffscreenCanvas bitmap, feeds through createImageBitmap, the resulting ImageBitmap internally calls OS routines that trigger dlopen. This is how JS loads native libraries without any native code execution.

**What we can learn:** The `sbx0_main_18.4.js` GPU sandbox escape is the most interesting — it crafts IPC messages that exploit a deserialization bug in `RemoteGraphicsContextGL_*` to get arbitrary memory R/W in the GPU process. Since the GPU process has broader sandbox, this is a stepping stone to kernel access.

### 4.4 `excalibur/` — Full-Featured GUI Exploit App

**Most interesting feature:** Remote ROP (`TaskRop/RemoteCall.m`) — hijacks threads in OTHER processes, sets up ROP chains, and executes `objc_msgSend` remotely. This enables SpringBoard tweak injection, status bar customization, and on-device development without dyld insertion.

**What we can learn:** The `MigFilterBypassThread.m` is the key to bypassing sandbox MIG (Mach Interface Generator) filters. It locks `_duplicate_lock` (a kernel `lck_rw_t`) by writing through kernel R/W, which prevents the sandbox from checking Mach messages. This means ANY Mach message passes through — you can send arbitrary RPC to any Mach service (including kernel services like `host_priv`).

**AMFI research:** `amfi_research.h` has complete reverse-engineered `OSEntitlements`/`OSEntitlementsState` structs for iOS 17 vs 18. The struct layout changed significantly — iOS 17 had flat layout, iOS 18 moved to inline entry arrays with `CEQueryContext` version checks.

### 4.5 `usbliter8-fun/` + `usbliter8-fun2/` — Bootrom Exploitation

**Technique:** Checkm8-based SecureROM exploit via RP2350 hardware  
**Key patches:**
- `image4_validate_property_callback → nop; mov x0,#0; ret` — bypasses IMG4 signature checks
- `AMFIIsCDHashInTrustCache → mov x0,#1; ret` — trusts ALL code signatures
- `file_check_mmap → mov x0,#0; ret` — bypasses mmap sandbox checks
- APFS seal panic bypass at offset `0x229fD50` — prevents kernel panic on unsealed root

**The ScreenTime bypass:** `disable_screentime.py` is elegantly simple — `ScreenTimeAgent` is an on-demand Mach service that doesn't reply during Setup, causing a 10-second timeout loop. Setting `disabled=true` in launchd's `disabled.plist` makes launchd refuse to launch it, causing Setup's XPC to fail fast.

---

## 5. What I Would Change

### 5.1 Architecture: Separate Exploit Engine from Tweak Injection

The current architecture is a monolith — the exploit is embedded directly in the MobileSubstrate tweak. This means:
- Can't use the exploit without Filza running
- Can't port to other app targets without rewriting
- Can't test the exploit independently

**Proposal:** Extract `kexploit/` into a standalone `libdarksword.dylib` with a clean API:
```c
int ds_init(void);              // Auto-detect device, load offsets
int ds_exploit(void);            // Run kernel exploit → kR/W primitives
int ds_sandbox_escape(void);    // Escape current process sandbox
int ds_ssv_bypass(void);        // Enable SSV writes
int ds_cleanup(void);           // Restore kernel state
```
Then the tweak, CLI tool, and any future app target can link against this.

### 5.2 Threading: Replace Global State with Thread-Local or Mutex-Guarded

Current code has multiple global mutable variables:
- `controlData` (0x20 bytes) — shared across kread64/kwrite64 calls
- `rwSocket`, `controlSocket` — socket fds for R/W
- `highestSuccessIdx`, `successReadCount` — race statistics
- `g_patch_sandbox_ext_done` — state flag

All of these are accessed without synchronization. Under the retry loop model, multiple threads can and DO access these concurrently.

**Proposal:** 
1. Add `pthread_mutex_t g_krw_lock` around all `setTargetKaddr + setsockopt/getsockopt` sequences
2. Make `g_patch_sandbox_ext_done` use `_Atomic bool` with `memory_order_acquire/release`
3. Remove `highestSuccessIdx`/`successReadCount` from global scope (or make atomic)

### 5.3 Error Handling: Structured Error Codes

Currently functions return `-1` or `0` or `uint64_t(-1)`. There's no way to distinguish between:
- "offset not found for this iOS version"
- "socket spray failed (memory exhausted)"
- "physical OOB race didn't win in time"
- "sandbox extension set has unexpected structure"

**Proposal:** Define error codes:
```c
#define DS_ERR_OFFSETS_NOT_FOUND  -1
#define DS_ERR_SOCKET_SPRAY_FAIL  -2
#define DS_ERR_OOB_RACE_LOST      -3
#define DS_ERR_SBX_PROC_CHAIN     -4
#define DS_ERR_SBX_EXT_INVALID    -5
```

### 5.4 Testing: Automated Offset Validation

The biggest risk is wrong offsets (BB-011, BB-031). Current approach: load offsets, try exploit, see if it fails (possibly via kernel panic).

**Proposal:** Add a `./W0lfSword test-offsets` command that:
1. Loads offsets for current device
2. Does read-only validation (reads proc PID, thread stackptr, known kernel data structure sentinels)
3. Reports which offsets produce valid-looking values and which don't
4. Never writes to kernel memory
5. Takes ~1 second, safe to run

### 5.5 Build System: CMake Instead of Theos

Theos is great for tweak development but painful for standalone tooling. A CMake-based build would:
- Work on macOS/Linux/Windows for development
- Support cross-compilation via clang + custom sysroot
- Enable CI/CD (GitHub Actions building on every commit)
- Make it easier for contributors who don't use Theos

---

## 6. iOS Exploit Development Learning Path

### 6.1 Kernel Memory Layout

Understanding where things are in kernel memory is the prerequisite for all exploitation:

**Virtual address space (arm64, 4-level paging, T1SZ=0x19):**
```
0x0000000000000000 — 0x0000007FFFFFFFFF   User space (512GB)
0xFFFFFF8000000000 — 0xFFFFFFFBFFFFFFFF   Kernel space (512GB)
  ├── 0xFFFFFFDC00000000    VM_MIN_KERNEL_ADDRESS (kernel heap, data)
  └── 0xFFFFFFFBFFFFFFFF    VM_MAX_KERNEL_ADDRESS
```

**Key kernel structures:**
```
proc (process) — represents a running process
  ├── p_pid (offset varies)       Process ID
  ├── p_proc_ro (offset ~0x18)    Read-only proc data
  │     └── p_ucred (offset 0x20) Credentials pointer (SMR-encoded)
  │           └── cr_label (0x78) MAC label
  │                 └── l_perpolicy[1] (0x10) Sandbox policy
  │                       └── extension_set (0x10) Hash table of extensions
  ├── p_fd (offset varies)        File descriptor table
  │     ├── fd_cdir (offset varies)   Current directory vnode
  │     └── fd_ofiles (offset varies) File descriptor array
  └── p_textvp (offset varies)    Text (executable) vnode

thread — represents a thread of execution
  ├── machine (offset varies)     Machine-dependent state
  │     └── kstackptr (offset varies) Kernel stack pointer (used in PAC bypass)

vnode — represents an open file/directory
  ├── v_data (offset varies)      Filesystem-specific data (apfs_fsnode for APFS)
  ├── v_parent (offset varies)    Parent directory vnode
  ├── v_name (offset varies)      Directory entry name
  └── v_ncchildren (offset varies) Namecache children list

inpcb — Internet Protocol Control Block (for each socket)
  ├── inp_listnext (offset varies) Next socket in list
  └── icmp6filter pointer (offset ~0xA8) → points to ICMPv6 filter data buffer
```

### 6.2 Exploit Techniques Progression

**Level 1: Kernel Info Leak (KASLR bypass)**
- Read `struct proc` → `p_textvp` → Mach-O header → kernel slide
- Read thread context to leak kernel stack/heap pointers
- Use physical OOB to read adjacent allocations

**Level 2: Physical Memory R/W (DarkSword)**
- IOSurface + PurpleGfxMem → physically contiguous memory
- pwritev/preadv race → physical OOB read/write
- Socket PCB corruption → self-referential `icmp6filter` trick → arbitrary kernel R/W

**Level 3: Post-Exploitation Primitives**
- PAC pointer stripping via `XPACI` instruction
- SMR pointer decoding via `t1sz_boot` + `smr_base` bitmask
- Zone element write for structures larger than 0x20 bytes
- Thread hijacking for remote function calls

**Level 4: Sandbox Escape**
- Container path traversal (bad_query approach) — simplest
- Extension set patching (CrazyMind90 approach) — kernel R/W required
- Extension borrowing from daemons — dangles on daemon death
- MIG filter bypass (excalibur approach) — for Mach message sandbox bypass

**Level 5: Persistence**
- SSV bypass via vnode data pointer swap — writable until reboot
- Trust cache injection via kernel R/W — persists across reboots
- Launch daemon installation via SSV bypass — requires modified plist
- Bootrom exploit (checkm8) — permanent, needs hardware

**Level 6: Code Signing Bypass**
- AMFI disable via `proc.p_flag` (BB-004)
- CoreTrust bug abuse (TrollStore approach)
- Remote ROP to call `proc_set_pflag` in arbitrary process

### 6.3 Glossary

| Term | Meaning |
|------|---------|
| **PAC** | Pointer Authentication Code — arm64e uses cryptographic signing to protect pointers from modification. `XPACI` instruction strips PAC bits to get raw pointer. |
| **SMR** | Signed Memory Region — kernel encodes certain pointers (ucred, vouchers) with a per-boot random base to prevent reuse after free. |
| **T1SZ** | Translation Table Level 1 Size — determines virtual address space width (0x19 = 4-level paging = 47-bit addresses). |
| **KTRR** | Kernel Text Readonly Region — hardware protection that makes kernel code immutable after boot. |
| **PPL** | Page Protection Layer — prevents kernel from modifying page tables, even from kernel mode. |
| **SSV** | Signed System Volume — APFS snapshot that makes /System (and all subdirectories) read-only at the filesystem level. |
| **AMFI** | Apple Mobile File Integrity — enforces code signing, library validation, and Hardened Runtime. |
| **TCC** | Transparency, Consent, and Control — manages app permissions (camera, mic, photos, location). |
| **MIG** | Mach Interface Generator — RPC system for kernel-user communication. |
| **zone allocator** | Kernel heap allocator — allocates fixed-size blocks from per-type zones, fast but has limited fragmentation protection. |
| **namecache** | Kernel cache of filename-to-vnode mappings — speeds up path resolution but can become stale. |
| **jetsam** | iOS memory management daemon — kills processes under memory pressure. |

### 6.4 Useful Resources

**Source code:**
- XNU kernel source: https://github.com/apple-oss-distributions/xnu
- IOSurface source: https://github.com/apple-oss-distributions/IOSurface

**Tools:**
- KDK (Kernel Debug Kit): Apple's official kernel debugging symbols
- joker: iOS kernelcache extractor/analyzer
- XPF: XNU pattern finder (included in this repo at `XPF/`)
- img4tool: IMG4 firmware image manipulation

**References:**
- `DarkSword-RCE/pe_main.js` — most complete DarkSword implementation study
- `excalibur/TaskRop/` — remote ROP technique reference
- `excalibur/research/amfi_research.h` — OSEntitlements struct layout
- `excalibur/research/apfs_fsnode.h` — complete APFS fsnode struct

---

*This document serves as both bug bounty supplement and personal learning reference for iOS kernel exploit development. Each finding above BB-014 is a NEW discovery not in the original BUG_BOUNTY.md.*
