# Advisory wave → fix-commit map

Goal: for every `WebKit Bugzilla: N` line in a security.apple.com advisory entry,
produce a CONFIRMED commit or an explicit UNVERIFIED. The traps below are the whole
value of this playbook — each one cost a round to learn.

## Method

1. Render the advisory text with the SAME sed pipeline every round
   (`sed -e 's/<[^>]*>/\n/g' | sed -e 's/^[[:space:]]*//' -e '/^$/d'`), then `cmp`
   it against the previous round's copy. A different stripper (e.g. a regex over the
   whole document instead of per line) shifts every line number and invalidates every
   citation in earlier reports.
2. Resolve each id: `gh api repos/WebKit/WebKit/commits/<sha> --jq '.commit.message'`
   and require the `bugs.webkit.org/show_bug.cgi?id=<id>` line.
3. Prove the fix location by fetching the file AT that commit
   (`raw.githubusercontent.com/WebKit/WebKit/<sha>/<path>`) and grepping the added line
   for its absolute line number. Patch hunk headers are not `file:line` evidence.
4. Confirm the guard is still live on today's main (see trap 4).
5. Every commit gives a second independent handle: the `Canonical link:
   https://commits.webkit.org/N@main` line plus the sha. Cite both so a supervisor can
   re-check either without your scripts.

## Traps

1. **Search hits collide with canonical numbers.** `gh api -X GET search/commits -f
   q="repo:WebKit/WebKit <bz>"` also matches the bug number inside `Canonical link:
   …@main` commit numbers. Filter hits for `show_bug.cgi?id=<bz>` in the message before
   believing them.
2. **Ancestry is not liveness.** `compare/main...<sha>` with
   `merge_base_commit.sha == sha && ahead_by == 0` proves the commit is an ancestor of
   main — it does NOT prove the guard is still there. Reverts exist, and a fix plus its
   revert the same day both pass the ancestry check; only the revert's own message tells
   you which state main is in. Also fetch today's main copy of each file and grep the
   guard — this is how a post-fix rewrite that deletes the guard gets caught.
3. **Superseded fixes.** A fix commit can be superseded weeks later in the same area.
   Check the touched path's later history (`commits?path=…`): a second, differently
   shaped crash there means the class survived its first fix.
4. **Branch sweeps need full commit messages.** The Bugzilla URL is on message line 3,
   so a subject-only grep misses every hit. Always run controls (a known branch commit
   sha + a known id) in the same sweep — otherwise "0 hits" proves nothing.
5. **A release-window sweep can be empty and still be correct.** An August release is
   authored in June: a sweep with `since=<July>` returns zero hits INCLUDING its
   controls, because the branch commit is a June rebase/cherry-pick. Widen to
   `since=<release-4mo>&until=<release+1mo>` and run the controls in the same window. A
   control returning zero means the window or the method is broken, not that the id is
   absent.
6. **The Bugzilla REST API is auth-walled for security bugs.**
   `https://bugs.webkit.org/rest/bug/<id>` returns HTTP 401 / code 102 for security
   bugs INCLUDING resolved ones. Query a bug you already have a fix for as a control,
   or the 401 reads as "not found".
7. **Not a mapping: a commit fixing the same DEFECT under a different Bugzilla id.**
   Check `show_bug.cgi?id=` in its own message and count occurrences of the advisory's
   id before claiming it fixes that id.
8. **Consecutive `CVE-…:` lines share one Impact/Description block.** A page renders
   `WebKit Bugzilla: N` then 1..n `CVE-…` lines under a single block, so the block
   belongs to every CVE line after it until the next block, and an id belongs only to
   the FIRST CVE line that follows it. Parse forward with a carried block (reset the
   pending id on emit); a naive "look back N lines" parser mis-attributes descriptions
   and ids, making distinct-looking rows that actually share one description.
9. **Never resolve ids from a search-result snippet.** Filtering a truncated snippet
   yields FALSE NEGATIVES — an id can appear unresolvable while the commit's message
   line 3 is that exact bug URL. When two hunters disagree on one id, the parent's own
   `gh api` read decides.
10. **Advisory pages publish no build numbers**, and betas get no advisory at all.
    Never map release → build → advisory from the page; take the build from the
    device/update side.
11. **Re-count a hunter's scope claim before it reaches the tracker.** A branch-sweep
    report claiming a certain branch count is checked against the on-disk sweep files:
    `cut -d'|' -f1 sweep-*.txt | sort -u | wc -l`. The negative result often survives
    while the number does not.

## Independent re-verification transcript

`curl https://api.github.com/...` (unauth, 60/h per IP, separate from `gh`'s token
quota) plus `raw.githubusercontent.com` reproduce every claim with no `gh` and no
helper script. Put that transcript in the report as the independent-verification
section. A 12-char sha prefix is enough for `github.com/.../commit/<sha>.patch`.

## Evidence dir per round

`reports/<topic>-<YYYYMMDD>/` with SESSION-REPORT + raw evidence + fix-commit
provenance + hunter reports. Save a plain `grep -n` dump (with the file's sha256) into
the evidence dir and cite that path alongside the quote — a symbol that exists only
inside staged files gets reported as "not found in workspace".
