---
name: ios-misc-tooling
version: 2.1.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf]
token_budget: 11264
covers: [Theos, ldid, deploy, kernelcache, libimobiledevice, device management]
platforms: [macOS, Linux cross-compile, iOS 15.0-27.0]
triggers:
  - Theos build
  - deploy to device
  - kernelcache extract
  - libimobiledevice
  - ldid sign
  - dpkg-deb
  - idevice_id
  - SSH iOS
  - build tweak
  - KPF offset
  - XPF pattern
  - crash debugging
related_skills:
  - ios-kernel-exploit
  - ios-sandbox-escape
  - ios-security-pentesting
---

# iOS Exploit Development — Tooling & Workflow

> **Skill type:** Support — build, deploy, debug, device management  
> **Platforms:** macOS, Linux (cross-compile), iOS 15.0–27.0  
> **Based on:** W0lfSword tooling, Theos ecosystem, libimobiledevice  
> **Last updated:** 2026-08-11

---

## When to Use This Skill

Use when the task involves:
- Building iOS tweaks/exploits (Theos, CMake, ldid, clang cross-compile)
- Deploying packages to iOS devices (SSH, SCP, dpkg)
- Device management (libimobiledevice, pairing, USB/WiFi)
- Logging and debugging iOS exploits
- Kernelcache extraction and analysis
- Crash monitoring and recovery
- CI/CD for iOS exploit development
- Multi-device workflow management
- Post-exploitation tooling (file transfer, VNC, networking)

---

## 1. Build System

### 1.1 Theos

Theos is the standard build system for iOS tweaks (Cydia Substrate/MobileSubstrate):

```makefile
# Makefile example
TARGET := iphone:clang:latest:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Filza

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FilzaApplySandboxExt
FilzaApplySandboxExt_FILES = Tweak.m sandbox_escape.m $(wildcard kexploit/*.m) $(wildcard utils/*.m)
FilzaApplySandboxExt_FRAMEWORKS = UIKit IOKit IOSurface
FilzaApplySandboxExt_CFLAGS = -fobjc-arc -DNDEBUG
FilzaApplySandboxExt_LDFLAGS = -Wl,-segalign,4000

include $(THEOS_MAKE_PATH)/tweak.mk

after-package::
    @echo "Built $(THEOS_PACKAGE_DIR)/$(THEOS_PACKAGE_NAME)_$(THEOS_PACKAGE_VERSION)_$(THEOS_PACKAGE_ARCH).deb"
```

**Common targets:**
```bash
make package          # Build .deb
make package install  # Build + install on device
make clean            # Clean build artifacts
make do               # Build + install + respring
```

**THEOS setup:**
```bash
# Install Theos
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# Or clone manually
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos

# Common locations checked by check_theos():
#   $THEOS (env var)
#   $HOME/theos
#   /opt/theos
#   /usr/local/theos
#   $PROJECT_DIR/.theos
```

**sudo note:** Running `make` under sudo changes `$HOME` to `/root`. The `check_theos()` function should fall through to check `$SUDO_USER`'s home directory:
```bash
if [ "$EUID" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    sudo_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    [ -d "$sudo_home/theos/makefiles" ] && export THEOS="$sudo_home/theos"
fi
```

### 1.2 Standalone Clang Cross-Compile (darksword-kexploit style)

```makefile
# Makefile for standalone CLI (no Theos needed)
TARGET = darksword
ARCHS = arm64 arm64e
SDK = $(shell xcrun --sdk iphoneos --show-sdk-path)
CC = xcrun -sdk iphoneos clang

CFLAGS = -arch arm64 -arch arm64e -isysroot $(SDK) -mios-version-min=15.0
LDFLAGS = -framework Foundation -framework IOKit -framework IOSurface

$(TARGET): src/main.m
    $(CC) $(CFLAGS) $< -o $@ $(LDFLAGS)

sign: $(TARGET)
    ldid -S../entitlements.plist $(TARGET)  # Ad-hoc sign with entitlements
```

### 1.3 Code Signing

```bash
# Ad-hoc sign (for jailbroken / TrollStore)
ldid -S entitlements.plist binary

# Codesign (for developer provisioning)
codesign -s "Apple Development" --entitlements entitlements.plist binary

# Verify signature
codesign -dvvv binary
jtool2 --sig binary           # jtool2 alternative (more detail)
```

### 1.4 Package (deb) Management

```bash
# Build .deb
dpkg-deb -b layout/ package.deb

# Inspect .deb
dpkg-deb -c package.deb        # List contents
dpkg-deb -I package.deb        # Package info (control file)

# Extract .deb
dpkg-deb -x package.deb output_dir/
```

---

## 2. Device Management

### 2.1 libimobiledevice (USB)

```bash
# List USB devices
idevice_id -l

# Device info
ideviceinfo -k DeviceName
ideviceinfo -k ProductVersion
ideviceinfo -k HardwareModel
ideviceinfo -k UniqueDeviceID

# Pair with device
idevicepair pair

# Validate pairing
idevicepair validate

# Diagnostics
idevicediagnostics restart     # Reboot device
idevicesyslog                  # Live syslog
```

### 2.2 SSH/WiFi Deployment

```bash
# Check SSH connectivity
ssh -o ConnectTimeout=5 root@DEVICE_IP "echo ok"

# SCP with retry
scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no package.deb root@DEVICE_IP:/tmp/

# Install package
ssh root@DEVICE_IP "dpkg -i /tmp/package.deb && rm /tmp/package.deb"

# Restart app
ssh root@DEVICE_IP "killall -9 Filza"

# Fetch device info
ssh root@DEVICE_IP "sw_vers -productVersion"
ssh root@DEVICE_IP "sysctl -n hw.machine"
ssh root@DEVICE_IP "sysctl -n kern.osversion"
```

### 2.3 USB Networking (usbliter8-fun2 approach)

On jailbroken/dev-mode devices, set up USB Ethernet for reliable connectivity:

```bash
# On Mac (host):
# Detect USB Ethernet interface
ifconfig | grep -A5 "en[0-9].*XHC\|USB"

# Configure IP
sudo ifconfig enXX inet 10.7.0.1 netmask 255.255.255.0
sudo sysctl -w net.inet.ip.forwarding=1
echo "nat on en0 from 10.7.0.0/24 to any -> (en0)" | sudo pfctl -ef -

# On device:
# netup.c sets SCDynamicStore for ipv4 config
# Then ssh root@10.7.0.2
```

---

## 3. Logging & Debugging

### 3.1 TweakLog System

The W0lfSword logging uses a consolidated system with rotation:

```c
// Thread-safe logging to /tmp/FilzaTweak.log
// 4MB max, rotates on overflow
// Uses pthread_mutex_trylock to prevent signal-handler deadlocks

#include "utils/tweak_log.h"

TweakLog("[Tweak] Hook installed: %s", __FUNCTION__);
TweakLog("[SSV] patch_sandbox_ext result: %d", result);
TweakLog("[SBX] Escaped — %d/%d tests passed", n, total);
```

**Log levels** (by prefix):
| Prefix | Meaning |
|--------|---------|
| `***` | Critical success/failure |
| `ERROR`, `FAILED`, `invalid`, `PANIC` | Fatal errors |
| `Retry`, `retry`, `WARNING` | Transient issues |
| `succeeded`, `ESCAPED`, `active=1` | Success events |
| `[SSV]`, `[Tweak]`, `[SBX]`, `[Padlock]` | Subsystem logs |

### 3.2 Crash Monitoring

```bash
# Monitor device log remotely
ssh root@DEVICE_IP "tail -f /tmp/FilzaTweak.log"

# Save crash log locally
ssh root@DEVICE_IP "tail -100 /tmp/FilzaTweak.log" > crash_$(date +%s).log

# Check for kernel panics
ssh root@DEVICE_IP "cat /var/mobile/Library/Logs/CrashReporter/LatestCrash-*.ips" 2>/dev/null
```

### 3.3 Runtime Debug Flags

```bash
# Enable exploit (default)
ssh root@DEVICE_IP "rm -f /var/mobile/Documents/.filza_tweak_disable"

# Disable exploit (safe mode)
ssh root@DEVICE_IP "touch /var/mobile/Documents/.filza_tweak_disable"

# Safe mode (skip kernel writes, UI hooks only)
ssh root@DEVICE_IP "touch /var/mobile/Documents/.filza_safe_mode"

# Check last exploit success
ssh root@DEVICE_IP "ls -la /var/mobile/Documents/.filza_last_success"
```

---

## 4. Kernelcache Operations

### 4.1 Extraction from Device

```bash
# Method 1: Direct from device (needs root + SSH)
ssh root@DEVICE_IP "dd if=/dev/rdisk0s1s1 of=/tmp/kc_part bs=1M count=32"
ssh root@DEVICE_IP "lzma -d /tmp/kc_part -c > /tmp/kc_raw"

# Method 2: From IPSW (firmware file)
unzip iPhone16,2_26.0.1.ipsw
# Kernelcache is at: 061-XXXXX.0123.4567.dmg.unpacked/kernelcache.release.iphone16

# Method 3: joker tool
joker -m kernelcache.release.iphone16  # Parse + dump info
```

### 4.2 Kernelcache Analysis

```bash
# Check kernel version
strings kernelcache | grep "Darwin Kernel Version"

# Find specific strings (for offset discovery)
strings kernelcache | grep "icmp6_filter"
strings kernelcache | grep "sandbox_check"

# Extract Mach-O header info
otool -l kernelcache | head -50

# XPF pattern finder
./XPF/src/xpf kernelcache > offsets.txt
```

### 4.3 KPF (Kernel Patch Finder)

Included in `W0lfSword/kpf/`:
```bash
# Pull kernelcache from device
kpf pull  # Grabs kernelcache and decompresses

# Verify against local offset database
kpf verify --ios 26.0.1 --model iPhone14,5
```

---

## 5. Multi-Device Workflow

### 5.1 Device Profiles

```bash
# Save device profile (IP, iOS version, model, exploit config)
./W0lfSword profile save iphone15pro-26.0.1

# List all profiles
./W0lfSword profile list

# Load profile (sets active device, retry count, etc.)
./W0lfSword profile load iphone15pro-26.0.1
```

### 5.2 Device Manager

```bash
# Add device
./W0lfSword device add 192.168.1.100 --name "iPhone 15 Pro"

# Switch active device
./W0lfSword device switch 192.168.1.101

# List all devices
./W0lfSword device list

# Get detailed info
./W0lfSword device info 192.168.1.100
# Output: iOS version, model, kernel build, SSH status
```

---

## 6. Common Workflows

### 6.1 Build → Deploy → Verify (One Shot)

```bash
# Quick mode: build + deploy + wait + verify
./W0lfSword quick

# With verbosity
./W0lfSword -vv quick
```

### 6.2 Auto-Discover Device (Adderall Mode)

```bash
# Fully automated: find device, check offsets, build, deploy, verify
sudo ./W0lfSword adderall

# Safe mode (no exploit, UI hooks only)
sudo ./W0lfSword adderall --safe

# Skip prompts
sudo ./W0lfSword adderall --yes

# Debug mode
sudo ./W0lfSword adderall --debug
```

### 6.3 Development Loop

```bash
# Watch for changes and auto-rebuild
while inotifywait -r -e modify .; do
    ./W0lfSword build && ./W0lfSword deploy
done

# Or manually:
./W0lfSword build    # Build .deb
./W0lfSword deploy   # Push to device
./W0lfSword log 20   # Check recent log
```

### 6.4 Debugging a Crash

```bash
# 1. Deploy with crash monitor
./W0lfSword deploy
# Crash monitor starts automatically, captures log

# 2. After crash/reconnect:
./W0lfSword crashlog   # View captured crash log

# 3. Export full debug bundle
./W0lfSword export    # Creates ZIP with session log, offsets, profiles

# 4. Check exploit stats
./W0lfSword history stats
```

---

## 7. Health Checks

### 7.1 Project Status

```bash
./W0lfSword status
# Shows: git branch, device connection, roadmap progress,
#        exploit methods available, offset blocks loaded
```

### 7.2 Environment Check

```bash
./W0lfSword doctor
# Checks: THEOS, clang, dpkg-deb, git, ssh, python3, ldid
# Reports missing tools with install instructions
```

### 7.3 Offset Coverage

```bash
./W0lfSword offsets
# Shows: iOS version blocks in offsets.m, SoC coverage per CPU family
```

### 7.4 Code Audit

```bash
./W0lfSword audit
# Performs brace/paren balance check on all source files
# Validates key struct sizes and offset consistency
```

---

## 8. Quick Reference

```
Build:           make package
Sign:            ldid -Sentitlements.plist binary
Deploy:          scp package.deb root@IP:/tmp/ && ssh root@IP "dpkg -i /tmp/..."
Restart:         ssh root@IP "killall -9 AppName"
Log:             ssh root@IP "tail -f /tmp/FilzaTweak.log"
Safe mode:       ssh root@IP "touch /var/mobile/Documents/.filza_safe_mode"
Disable:         ssh root@IP "touch /var/mobile/Documents/.filza_tweak_disable"
Reboot device:   ssh root@IP "reboot"
USB pair:        idevicepair pair
Device info:     ideviceinfo -k ProductVersion
Kernel version:  ssh root@IP "sysctl -n kern.osversion"
System version:  ssh root@IP "sw_vers -productVersion"
HW model:        ssh root@IP "sysctl -n hw.machine"
THEOS check:     ls $HOME/theos/makefiles
SDK path:        xcrun --sdk iphoneos --show-sdk-path
```

---

## 9. Contribute Back

**Found something critical?** A build chain that catches kernel panics before you deploy? A lldb script that automates offset discovery for a brand new iOS kernel? A CI pipeline that surfaces regressions across 10 devices in parallel? If your tooling workflow caught a bug that would have been a kernel panic on device, the swarm needs to know about it.

**Found something useful?** Even small improvements matter — a new Theos flag that fixes code signing, a `libimobiledevice` command you discovered, a faster deploy path over USB, a kernelcache extraction trick for encrypted firmwares.

```bash
git add skills/ios-misc-tooling.md
git commit -m "feat: new kernelcache extraction method for iOS 28 encrypted KC"

gh pr create --repo kaffeindecaf/Apple-Bug-Bounty-Skill \
  --title "Tooling improvement" \
  --body "## What was found\n\n## Tools required\n\n## iOS version / macOS version compatibility\n\n## Step-by-step workflow\n\n## Verification"
```

Repository: https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill

Every contribution sharpens every agent that loads this skill.
