---
name: ios-device-usb-tooling
description: "Use for driving an iOS device over USB from Linux/macOS: pairing, syslog capture, USB SSH via iproxy, crash/panic pulls."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 4096
covers: [libimobiledevice, idevicepair, idevicesyslog, iproxy USB SSH, pymobiledevice3, afcclient, panic triage]
learns_from:
  - projects/W0lfSword
platforms: [Linux host, macOS host, iOS 15.0-27.0]
triggers:
  - "ios usb"
  - "idevicepair"
  - "idevicesyslog"
  - "iproxy"
  - "usbmuxd"
  - "device panic"
  - "crash pull"
  - "afcclient"
  - "pairing failed"
  - "usb ssh"
related_skills:
  - ios-misc-tooling
  - ios-poc-lab
  - ios-security-pentesting
cross_reference_rules:
  - Transport questions (WiFi vs USB) → this skill; toolchain/build/deploy → load ios-misc-tooling
  - Logs from a live run in a hosted PoC → load ios-poc-lab
  - Frida/on-device instrumentation → load ios-security-pentesting
references:
  - skills/references/ios-device-usb-tooling/usb-enumeration-triage.md
  - skills/references/ios-device-usb-tooling/device-panic-triage.md
  - skills/references/ios-device-usb-tooling/usb_probe.sh
research_first: true
---

# iOS Device USB Tooling

Playbook for driving a physical iPhone/iPad over USB from a Linux or macOS host with libimobiledevice: identify the device, pair it, test the link, and reach sshd over USB when WiFi/IP is unavailable or wrong.

## Tool inventory

| Tool | Job | Package |
|------|-----|---------|
| `idevice_id -l` | list USB devices (UDIDs). WITHOUT `-n` it lists USB only — a UDID here already proves the USB path | libimobiledevice-utils (apt) / libimobiledevice (brew) |
| `ideviceinfo -k KEY` | read one lockdown key: DeviceName, ProductVersion, HardwareModel… (one `-k` per call; empty output = locked/untrusted) | same |
| `idevicepair validate` / `pair` | pairing state / first-time trust | same |
| `idevicediagnostics diagnostics All` | harmless read-only lockdown round-trip | same |
| `idevicesyslog` | stream device syslog (never exits — must be killed) | same |
| `iproxy 2222 22` | forward localhost:2222 → device:22 over usbmuxd (USB SSH) | libusbmuxd-tools (apt) / libimobiledevice (brew) |
| `usbmuxd` | USB multiplexer daemon (Linux: systemctl start usbmuxd) | usbmuxd / libusbmuxd |

## Pairing — use exit codes, never output text

`idevicepair validate`'s success wording CHANGED between libimobiledevice versions: older builds print "SUCCESS: Host … is paired with device …", newer ones print "SUCCESS: Validated pairing with device …". Grepping output for "paired" only matches the old wording and reports false failures (a real bug hit in W0lfSword's usbtest). Always judge by exit status:

```bash
if idevicepair validate >/dev/null 2>&1; then ... paired ...; fi
if idevicepair pair >/dev/null 2>&1;  then ... paired now ...; fi
```

- First-time pairing: `idevicepair pair` → tap TRUST on the phone → sleep ~1 → validate again.
- A locked phone blocks pairing: "ERROR: Could not validate with device … because a passcode is set." → user must unlock first.
- `ideviceinfo -k ConnectionType` is NOT populated on every libimobiledevice build — don't gate on it; infer USB from `idevice_id -l`.

## USB SSH (iproxy) — the WiFi-free transport

```bash
iproxy 2222 22 &                     # keep the PID; kill on exit
ssh -p 2222 root@localhost "echo ok" # batch: -o BatchMode=yes -o StrictHostKeyChecking=no
scp -P 2222 root@localhost:/path local
```

CRITICAL: the tunnel replaces the NETWORK only. The device must still run sshd on port 22. Deploy-failure diagnosis ladder:

1. `ping <ip>` — offline → network problem.
2. IP pings but `ssh … port 22: Connection refused` → **no sshd listening** (stock iOS, or OpenSSH not installed/running). This is the #1 cause of scp/deploy failures, and NO transport fixes it — WiFi or USB.
3. USB tunnel gives "Connection reset by peer" on port 2222 → same cause (nothing on the far side).
4. "Permission denied (publickey)" → auth, not transport — needs key setup (ssh-copy-id / one interactive login); BatchMode can't enter passwords.

A stock (non-jailbroken) iOS device has NO sshd at all. USB SSH only becomes possible after a jailbreak or a tethered boot that ships SSH (usbliter8-style CFW: `iproxy 2222 22`, root/alpine).

Tunnel-aware wrapper pattern (make all ssh/scp calls transparently use the tunnel when up; verify before use, kill on failure and in the exit trap):

```bash
TUNNEL_PORT=""   # set to 2222 when the tunnel is verified up

ssh_safe() {  # host = "root@<ip>", rest = remote command
    local host="${1:-}"; shift
    if [ -n "$TUNNEL_PORT" ]; then
        ssh -p "$TUNNEL_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no "root@localhost" "$@"
    else
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no "$host" "$@"
    fi
}
scp_safe() {
    local remote="${1:-}"; shift
    if [ -n "$TUNNEL_PORT" ]; then
        scp -P "$TUNNEL_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no "root@localhost:${remote#*:}" "$@"
    else
        scp -o BatchMode=yes -o StrictHostKeyChecking=no "$remote" "$@"
    fi
}
```

Start the tunnel lazily and PROBE it (2s batch "echo ok") before setting TUNNEL_PORT; kill iproxy if the probe fails. Only auto-prefer USB when the caller's device discovery is itself USB-based — with multiple phones attached, an unverified tunnel can silently target the wrong device, while a WiFi-IP-addressed command stays pinned to the intended phone.

## Watching a live app run, then triaging the panic

`idevicesyslog` is a FEED, not a record: it does print an app's own os_log lines
(`AppName[pid] <Notice>: ...`), which is often the app's real output, but it drops and
throttles lines under load.

- Pipe through `stdbuf -o0` (`idevicesyslog -u $UDID -q --no-colors > run2.log` with
`background=true`, read with `grep -a "AppName\["`): with `-o FILE` the stdio buffer
leaves the file at 0 bytes for minutes. Start a FRESH file per session and run
`pgrep -af idevicesyslog` first — relays from earlier sessions are still alive and still
appending to their own files, so a stale file reads as this run's output. Add a second
`idevicesyslog -k -o kernel2.log` stream as a panic tripwire.
- The record is the app's own file log when it keeps one (fsync-per-line survives the
panic), pulled over USB in container mode:
`timeout 60 afcclient -u $UDID --container <bundle> get /Documents/<app>.log ./out.log`.
`--documents` with a bare `/file.log` answers `Not found (8)`, and the pull BLOCKS for
minutes while the app hammers the kernel — always keep the `timeout`.
- Such logs are usually APPEND-ACROSS-RUNS: filter by timestamp prefix before counting
any signature (`grep -ac '14:[0-9][0-9]:[0-9][0-9].*<signature>'`), or a previous run's
spam reads as this run's failure and sends you hunting something already fixed.
- A device that reboots mid-run panicked the kernel — not a hang, not an app crash, and
NOT the app being force-killed. `pymobiledevice3 usbmux list` confirms it is back, and
the report predates the reboot so it is already on the device:
`timeout 120 pymobiledevice3 crash pull ./crashes --match "(?i)(panic|<app>|jetsam)"`.
Attribute it from the report's `Panicked task ... pid N: <AppName>` line, and compare
`panicString` across reports to tell a repeat from a new class. Full recipe:
`references/device-panic-triage.md`.

## Harmless USB test battery (read-only)

usbmuxd up → `idevice_id -l` shows device → pair validate → `idevicediagnostics diagnostics All` round-trip → 2s `idevicesyslog` capture → 10× rapid `idevice_id` reads as a cable-flakiness probe. Writes nothing to the device. Run it: `scripts/usb_probe.sh [udid]` (see support file).

## Device identification

- `ideviceinfo -k HardwareModel` → board config: D27AP = iPhone SE 2 (A13), D79AP = iPhone 12 mini (A14). Check the model, not just the board.
- UDIDs differ per device (00008110-… vs 00008030-…). Never assume "the same phone" across sessions — re-read `idevice_id -l`.
- The kernelcache is SoC-shared: `kernelcache.release.t8030` covers every A13 device of a given build.

## Pitfalls

- `pgrep -f iproxy` also matches `/usr/bin/xembedsniproxy` (substring!) — use `pgrep -x iproxy`.
- `timeout(1)` does not exist on macOS — for syslog capture use background + sleep + kill (see usb_probe.sh).
- `ideviceinfo` with multiple `-k` flags honors only the LAST one — one key per call.
- Backing processes (iproxy) must be killed in the script's exit trap or they linger and hold port 2222.
- `idevicesyslog`/`idevicediagnostics` need pairing; on an unpaired device they fail silently — pair first, then probe.
- Host→device HTTP serving (static repro server + the host firewall rule that has to be opened for it) and its teardown live in the `local-server-teardown` skill. The tell: the device reports "connection refused" while the host's own `curl 127.0.0.1:<port>` returns 200 — that is the firewall, not the server.
