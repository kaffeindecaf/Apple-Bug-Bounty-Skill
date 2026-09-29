#!/bin/bash
# usb_probe.sh — harmless read-only USB + pairing + data-path probe.
# Usage: usb_probe.sh [udid]   (udid optional; first USB device by default)
# Exits 0 if the whole battery passes, 1 otherwise. Writes nothing to the device.
set -u
UDID="${1:-$(idevice_id -l 2>/dev/null | head -1)}"
pass=0; fail=0
ok(){ echo "  PASS  $1"; pass=$((pass+1)); }
no(){ echo "  FAIL  $1"; fail=$((fail+1)); }

# usbmuxd (Linux only — macOS runs it as a launchd service)
if [ "$(uname)" = "Linux" ]; then
  if pgrep -x usbmuxd >/dev/null 2>&1 || pgrep -f usbmuxd >/dev/null 2>&1; then
    ok "usbmuxd running"
  else
    no "usbmuxd not running (systemctl start usbmuxd, or: usbmuxd -f -v)"
  fi
fi

[ -n "$UDID" ] && ok "device visible on USB: $UDID" || { no "no USB device (Lightning cable, no hub)"; exit 1; }

# pairing — exit code, NOT output text (wording changed across libimobiledevice versions)
if idevicepair validate >/dev/null 2>&1; then
  ok "pairing valid — host is trusted"
else
  no "not paired — unlock the phone (passcode locks pairing) and tap TRUST, then: idevicepair pair"
fi

NAME=$(ideviceinfo -k DeviceName 2>/dev/null || echo "?")
VER=$(ideviceinfo -k ProductVersion 2>/dev/null || echo "?")
MODEL=$(ideviceinfo -k HardwareModel 2>/dev/null || echo "?")
echo "  info   $NAME  iOS $VER  ($MODEL)"

# read-only lockdown round-trip
if idevicediagnostics diagnostics All >/dev/null 2>&1; then
  ok "lockdown diagnostics round-trip (read-only)"
else
  no "diagnostics round-trip failed — USB data path broken?"
fi

# short syslog capture (no timeout(1) needed — portable to macOS)
LOG=$(mktemp 2>/dev/null || echo /tmp/usb_probe.$$)
idevicesyslog >"$LOG" 2>/dev/null & SP=$!
sleep 2
kill "$SP" 2>/dev/null || true
wait "$SP" 2>/dev/null || true
[ -s "$LOG" ] && ok "syslog stream received data" || no "syslog empty (logging may be off — not fatal)"
rm -f "$LOG"

# cable reliability: 10 rapid reads, a good cable never misses
good=0
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ "$(idevice_id -l 2>/dev/null | head -1)" = "$UDID" ] && good=$((good+1))
  sleep 0.1
done
if [ "$good" -ge 9 ]; then
  ok "cable stable ($good/10 reads)"
elif [ "$good" -ge 6 ]; then
  no "cable flaky ($good/10) — swap cable/port before deploying"
else
  no "bad USB connection ($good/10) — short MFI cable, direct port, no hub"
fi

echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
