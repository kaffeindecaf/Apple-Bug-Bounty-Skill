# Apple report portal — field map and paste-block pattern

The form at security.apple.com/report is JS-rendered; field labels vary between
portal versions — match by meaning, and give the user per-field blocks so they
never compose text in the browser.

## Portal basics

- security.apple.com/report -> Submit a Report -> Apple ID sign-in (required; use
  the email that payout/banking mail should reach). The case number appears after
  submit; record it in the tracker immediately.
- A headless web_extract/browser may not render the app. Deliver text as copy
  blocks instead of describing fields from memory.

## Field map (verified from a saved page DOM - maxlength/aria-label grep)

| Field | Guidance |
|---|---|
| platform (radio) | "Apple Devices and Software" for iOS/macOS bugs; the other is apple.com web services |
| affected area (select) | component ids: WebKit=29, Safari=30, JavaScriptCore=31, Sandbox=44. Pick the engine entry |
| title | max 100, live counter |
| What is required to reproduce this issue | textarea, min 6, max 200. Shortest honest repro; full numbered steps live in the description |
| Detailed description | textarea, min 50, max 10000, PRE-FILLED with the #-heading template - fill in place, keep headings |
| hasPoC (radio) | Yes/No. Attach real repros, answer yes |
| file attachment | max 500MB per file; one numbered zip |
| credit | max 150; the public acknowledgment name |
| (NO fields for affected version / impact / notes / related reports / bug type) | fold all of it into the description Summary + Actual results, incl. related case ids |
| escalationJustification (max 1000) | report-QUOTA request module, NOT the vuln form ("this form is not for reporting specific security vulnerabilities") - never fill it for a bug |
| Toggles | acknowledgment YES; Target Flag checkboxes NO (not applicable without demonstrated exploitation) |

## Paste-block pattern (the deliverable Apple text comes in)

Separate file, one block per field, each block: verbatim text, a MEASURED char
count (`python3 -c "print(len(s))"`), and a named cut-line for when a field limit
rejects the block. Example measured sizes from a filed report: title 76,
version 203, description 1524, steps 408, impact 299, LM 148.

## Required description structure (verified against the live form)

The detailed-description field demands this exact layout (markdown headings, blank
lines as shown). Title max 100 chars; "What is required to reproduce this" max 400
chars on the version that was checked:

```
# Summary

# Steps to reproduce
1. ...
2. ...
3. ...

# Expected results

# Actual results
```

Older filings used free text because the form version differed; check the live form
each round and conform. Put the honest boundary and the missed-sibling point in
Summary and Actual results, not in Expected.

## Repro friction rules

- Repro HTML standalone, works from a local file, no server, no testRunner.
- Include a no-crash control page; state "control page did not crash" in the report -
  it is the attribution baseline.
- Attach `.ips` files verbatim; explain odd process names once (e.g. a WebContent
  CaptivePortal suffix) so triage does not stall on them.

## Pitfalls that get reports bounced or downrated

1. No minimal repro, or a repro that needs a server.
2. Calling a crash RCE, or claiming corruption without proof.
3. Duplicate dismissal - countered by naming the separate function, the fixing
   commit, and proving fixed branches still carry the bug (branch sweep).
4. Unclear version scope or source-only claims - pair a source sweep with a stock
   on-device `.ips`.
5. Unexplained process/crash attribution details.
6. Slow triage replies (answer in 24-48h).
7. AI-sounding submission text (see the voice rules in the skill).

## Post-submit timeline

Ack 1-3 business days (check spam) -> triage questions days 3-21 -> fix + CVE in a
security update (weeks-months) -> bounty decision follows the fix, banking via the
case -> if the advisory ships without credit, one polite case reply asking for bounty
review. Set a 14-day follow-up at filing time.
