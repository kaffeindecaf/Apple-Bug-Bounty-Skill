---
name: apple-bounty-submission
description: "Use for filing an Apple Security Bounty report: portal field map, measured paste blocks, submission voice rules, payout-affecting framing, post-submit cadence."
version: 1.0.0
agent_compatibility: [claude-code, cursor, codex, opencode, copilot, windsurf, gemini, qwen, kimi]
token_budget: 7168
covers: [Apple Security Bounty, report portal field map, paste blocks, submission voice, impact framing, Lockdown Mode bonus, post-submit cadence]
learns_from:
  - projects/W0lfSword
platforms: [any host, iOS/macOS/iPadOS targets]
triggers:
  - apple bounty report
  - security.apple.com report
  - file a report
  - bounty submission
  - report portal
  - report form
  - impact statement
  - lockdown mode bonus
  - target flags
  - credit field
related_skills:
  - ios-variant-hunting
  - ios-security-pentesting
  - ios-research-methodology
cross_reference_rules:
  - If the affected-version sweep is still missing → load ios-variant-hunting (branch sweep + build-pair diffs)
  - If the bug still needs a repro or an on-device crash log → load ios-device-usb-tooling
  - If the target bug class is unclear or the finding is not yet confirmed → load ios-research-methodology
references:
  - skills/references/apple-bounty-submission/report-form-guide.md
research_first: true
---

# Apple Security Bounty Submission

Turns a confirmed finding into a filing package Apple can grade quickly. The
work is 20% technical and 80% text that survives triage.

## Deliverable shape (what a filing package contains)

1. `10-apple-bounty-message.txt` — the submission text: title + description +
   affected versions + steps + impact + Lockdown Mode note + attachment order.
2. `14-report-form-paste.txt` — per-field copy blocks for the portal, each with a
   MEASURED char count and a named cut-line ("if the field rejects this, delete
   sentence X — it survives in the attachments anyway"). Never make the user trim
   blind.
3. `13-apple-filing-sheet.md` — field-by-field paste map + zip recipe + post-submit
   cadence, kept open next to the browser while filling.
4. Full technical writeup (file:line citations, sha256 manifests) as attachment.
5. Package lives in a reports dir, one per finding per round. Tracker NEXT STEP
   updated the same day.

## Voice rules for Apple-facing text

Plain terse researcher prose. Short sentences, concrete numbers (4/4 loads, 3/3
runs, frame +1104, build 23A355). No em-dashes. No bullet spam in prose fields.

Banned AI-isms in bounty text — Apple triage reads them as padding:

```
"not a duplicate"          "honest boundary"         "severity is theirs to grade"
"verbatim"                 "deliberately"            "crucially"
"It is important to note"  "robust"                  defensiveness of any kind
```

Facts replace argument. Instead of "not a duplicate of CVE-X", write: "Apple's fix
for CVE-X (commit …) added a runtime check to <function A> and never touched
<function B>. The current shipping branch still has the vulnerable code."

## Report form field map (verify from a saved page DOM each round)

The portal is a JS web app: `web_extract` and headless browsers may not render it.
Log in, save the page as HTML, then grep `maxlength` / `aria-label` for the real
field set. Public JS bundles contain nothing useful. Field labels change between
portal versions — match by meaning, and deliver per-field copy blocks so the user
never composes text in the browser.

| Field | Guidance |
|---|---|
| platform (radio) | "Apple Devices and Software" for iOS/macOS/iPadOS bugs; the other choice is apple.com web services |
| affected area (select) | component list with ids (WebKit=29, Safari=30, JavaScriptCore=31, Sandbox=44). Pick the engine entry, never the OS/daemon bucket |
| title | text, max 100, live counter |
| "What is required to reproduce this issue" | textarea, min 6, max 200. Shortest honest repro; full numbered steps live in the description |
| "Detailed description" | textarea, min 50, max 10000. Comes PRE-FILLED with a `#`-heading template — keep its headings and fill in place |
| hasPoC (radio) | Yes/No. Attach a real repro, answer yes |
| file attachment | "Maximum size: 500MB" per file; one numbered zip is fine |
| credit | text, max 150. The public acknowledgment name |
| escalationJustification | max 1000, belongs to the report-QUOTA module, not the vuln form ("this form is not for reporting specific security vulnerabilities"). Never fill it for a bug |
| — | NO fields exist for affected version, impact, notes, related reports, or bug type. Fold all of it into Summary + Actual results |

Measure every block's char count and print it in the paste file
(`python3 -c "print(len(s))"`, splitting on the separator lines). Older filings
used an older form version — never assume a past round's field shapes still hold.

Full field map, paste-block pattern, required description structure and bounced-report
pitfalls: `skills/references/apple-bounty-submission/report-form-guide.md`.

## Field strategy (what maximizes payout without overclaiming)

- **Affected area / category:** pick the WebKit/Safari ENGINE entry, never the iOS
  platform entry — it routes to the team that owns the file and already knows the
  sibling CVEs. Do not pick "denial of service" as the bug type: triage grades the
  class, so label by bug class (memory safety / OOB deref), not by observed effect
  (crash).
- **Novelty card — incomplete-fix framing.** "Apple's own fixed branches still carry
  this bug", proven by a branch sweep, beats "similar to CVE-X". Cite the fix commit
  once; never lead with an rdar number.
- **Lockdown Mode +100% claim (exact wording pattern):** "Lockdown Mode was on
  system-wide for each run, Safari restarted between runs; identical crash 3/3 on the
  same device and iOS. Crash logs show interpreter-only JSC frames, so the bug does
  not depend on JIT." Apple decides the bonus; the report's job is unmissable evidence.
- **Honesty is a payout lever.** State what is proven (crash) and what is not
  (corruption/RCE). Overclaiming gets reports downrated or bounced; underclaiming with
  a clear class label lets Apple grade up.
- **Optional pre-filing upgrade:** run the remaining repro variant once on-device. One
  non-null fault-address `.ips` can move a crash-class finding toward
  controllable-deref. If it does not crash, file anyway on the confirmed variant.
- Toggles: acknowledgment YES; Target Flag checkboxes NO unless exploitation is
  actually demonstrated.

## Repro friction rule

Repro HTML must work from a local file (no server, no testRunner) so triage runs it
in under a minute. Include a no-crash control page and say so in the report — it is
the attribution baseline that proves the test setup is not at fault.

## Post-submit cadence

Ack in 1-3 business days (check spam). Triage questions days 3-21: answer within
24-48h with the test device nearby for re-runs — slow replies are the number one way
good reports stall. Fix + CVE land weeks to months later; the bounty decision follows
the fix (banking via the case). If an advisory ships without your credit: ONE polite
case reply asking about bounty review. Set a 14-day follow-up reminder at filing time
and record the case number immediately.

## Hard rules

1. Never invent an affected version, a build number, or a case id.
2. Never claim exploitation you have not reproduced; attach the raw `.ips`.
3. Verify the live form's field limits from a saved page before writing blocks.
4. Report only bugs you confirmed on shipping software — a source-only claim needs the
   on-device artifact beside it.
5. One finding per report. Sibling findings get their own report after the first is acked.
