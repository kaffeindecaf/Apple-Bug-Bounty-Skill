# USB enumeration triage — charging-but-invisible phone

Hit 2026-09-05: SE2 plugged in "still charging", but every userspace tool
reported dead. Root cause was BELOW the userspace stack.

## The rung-0 check

```bash
lsusb | grep -i apple    # expect: Bus ... ID 05ac:12a8 Apple, Inc. ...
```

- Apple vendor ID = `05ac`. ANY Apple line in lsusb = the USB bus sees the
  phone and userspace debugging can proceed.
- NO `05ac:` line while the phone is clearly charging = charge-only cable
  (power pins only, no data) or a powered-off / not-yet-booted phone.
  NO userspace tool fixes this: usbmuxd, idevice_id, iproxy, idevicepair all
  report dead because the device never enumerates on the bus.

## Order of checks (cheapest first)

1. `lsusb | grep -i 05ac` — bus-level enumeration. Nothing works without it.
2. `pgrep -x usbmuxd` — daemon up? (Linux: `sudo systemctl start usbmuxd`;
   the W0lfSword CLI prints this exact hint itself.)
3. `idevice_id -l` — a UDID here proves the full USB + usbmuxd path.
4. `idevicepair validate` — judge by EXIT CODE, never output text.
5. iproxy tunnel + ssh probe — sshd on the far side (JB devices only).

## Fixes for the no-enumeration case

- Swap to a known data cable (charge-only cables are common with
  power-bank-style leads).
- If the phone was powered off, wait for it to boot; it enumerates once the
  OS is up, even locked.
- A locked phone may refuse lockdown/pairing but still enumerates at the
  bus level — enumeration and trust are separate rungs.
