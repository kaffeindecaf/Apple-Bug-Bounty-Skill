---
name: options-verbose
version: 1.0.0
trigger: --verbose
description: Maximum detail output. All offsets, all caveats, all alternatives, full code snippets.
---

# --verbose: Detailed Output

Produce maximum detail. Do not abbreviate. Do not summarize. Give everything.

## Rules

### 1. Full offsets and struct layouts
For every technique mentioned, include the exact offset, struct name, and the source (KDK version, XNU version, or project file reference).
```
Bad:  "Patch the sandbox extension at the right offset."
Good: "Patch at offset `off_sandbox_extension_set = 0x10` (verified KDK 26.0, XNU-11215.1.10).
       Struct: sandbox → +0x10 → extension_set * → extension.type_buckets[0..8].
       Source: skills/ios-sandbox-escape.md §2.1, FilzaJailedDS/kexploit/sandbox.m:89-303."
```

### 2. Full code snippets
Include complete, compilable code. Not fragments. Include imports, error handling, cleanup.
```
Bad:  "kread32(proc + off_proc_p_pid)"
Good: "#include <stdint.h>
       extern uint64_t kread64(uint64_t where);
       static inline uint32_t kread32(uint64_t where) {
           return (uint32_t)kread64(where);
       }
       uint32_t pid = kread32(self_proc + off_proc_p_pid);
       if (pid != getpid()) return -1;"
```

### 3. List all alternatives
For every approach, list alternatives. Rank them with tradeoffs.
```
If (kernel R/W available) → use extension patch (reliable, fast)
Else if (userspace only)    → use path traversal via containermanagerd (no K-R/W needed)
Else if (checkm8 device)    → use boot-time sandbox NOP patches (permanent)
Else                        → no sandbox escape path known for this config
```

### 4. Include caveats and edge cases
Every technique has edge cases. List them explicitly.
For DarkSword IOSurface race:
- iOS 15.0-17.0: `pe_v1` — searches 0x2000 pages, higher retry count
- iOS 17.0-26.0.1: `pe_v1` with updated smr_base = 2
- A18 devices: `pe_v2` — only 0x10 pages, requires 3GB wired allocation
- arm64e: requires xpaci() on all pointers
- Device must have `com.apple.IOSurfaceRoot` entitlement

### 5. Show the full chain
When describing exploit chains, show every step from entry to goal.
```
Safari → JSC type confusion → addrof/fakeobj → JIT bypass → OffscreenCanvas dlopen →
JOP chain → GPU IPC deserialization → GPU sandbox escape → IOSurface physical mapping →
ICMPv6 socket spray → pwritev race → PCB corruption → kernel R/W → sandbox ext patch →
vnode data swap → SSV write → persistence
```

### 6. Time estimates for every step
Break time down per component.
- Kernelcache extraction: 5 minutes (IPSW download) + 2 minutes (joker extract)
- Offset validation: 10 minutes (run offsets_validate, iterate if wrong)
- Build and deploy: 3 minutes (make package, scp, dpkg -i)

### 7. Reference every source
Every claim links to a source file and line.
Format: `projects/{repo}/{file}:{line}` or `skills/{file}.md §{section}` or KDK version.
