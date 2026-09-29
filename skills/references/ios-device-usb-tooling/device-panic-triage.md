# Triaging a device panic

A device that reboots by itself during a test run has panicked the kernel. Read the
report before reporting a cause — including a cause the user offers (a force-kill of an
app does not panic a kernel, and an app "crash" that rebooted the phone was a panic).

## Pull the evidence

The report is written before the reboot, so it is already on the device once the device
is back on USB (`pymobiledevice3 usbmux list`):

```bash
mkdir -p crashes
# the timeout matters: the crash service hangs while a busy app is hammering the kernel
timeout 120 pymobiledevice3 crash pull ./crashes --match "(?i)(panic|<app>|jetsam)"
```

The panic file is `panic-full-<date>-<time>.0002.ips`, named for the moment of the
panic. The match also drags in `<App>.cpu_resource-*.ips`, `<App>.diskwrites_resource-*.ips`
and Jetsam events — read the newest panic and compare it against the older reports.

## Attribute it, or do not blame the app

An .ips is JSON: line 1 is a header (`timestamp`, `bug_type`, `incident_id`) and the body
carries `panicString` plus the task table. The line that decides who did it:

```
Panicked task 0xffffffde18292770: 19246 pages, 5 threads: pid 541: W0lfTerm
```

- `pid N: <AppName>` there = the app's own thread panicked the kernel. The app is the
  cause even when its own log shows no failure at all.
- no app name there = something else panicked (watchdog, another process) — read
  `panicString` before blaming the run.

`panicString` (first line, up to `@<file>:<line>`) is the class. Classes seen in this
device family:

| panicString | what it means |
| --- | --- |
| `imo_remref: imo 0x... negative refcnt @ip_output.c:2949` | a socket's ip_moptions refcount released twice, i.e. a field written without confirmation was clobbered; fires when the socket is torn down, a minute after the write, during socket churn |
| `0x... not in the expected zone data.kalloc.32[42], but found in kalloc.type3.1024[322] @zalloc.c:829` | a zone free of a pointer from another zone — a value written into a field the zone allocator owns |
| `pmap_tte_remove: Found inconsistent state in soon to be deleted L3 table ...` | page-table damage, the physical OOB write class |

Two reports with the same `panicString` and the same `file:line` are ONE bug, however
different the runs looked — that comparison is what separates a repeat from a new class.

## Cross-check the app's own log

Pull the app's file log (see SKILL.md) and read only the lines for THAT run, up to the
panic timestamp: a write/attempt counter and the last race or retry line bracket what was
in flight. A gap of minutes between the last log line and the panic is expected — the
panic fires when the damaged object is freed, so the trigger is teardown, not the write
that broke it.

## After the panic

- Report the panic string, the `.ips` path, the counter line and the last activity line
  together: the string names the class, the counters name what caused it.
- Do not re-run a run that writes anything (kernel memory, partitions, caches) "to see
  whether it repeats". Switch to the read-only mode the tool offers and treat the panic
  as a bug to fix in the component that wrote.
- Keep the `.ips` and the pulled log next to the session's other captures, so the fix can
  cite the artifact instead of the transcript.
