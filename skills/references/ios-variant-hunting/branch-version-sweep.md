# Proving affected versions across Apple shipping branches

Method for "what versions does this affect" claims. The claim that wins a duplicate
dismissal is "Apple's own fixed branches still carry this bug", and a branch sweep is
how you prove it.

## Why sweep instead of guessing

Branch number → OS version mapping is NOT safe to infer. Anchor only what your own
evidence fixes (e.g. "the 7624.x line ships in iOS 26.x", established from a known fix
release attribution) and mark every other mapping UNVERIFIED. The branch table with
byte-identical sha256s is the defensible artifact; the OS-version mapping is a courtesy
note.

## Commands (read-only, gh + raw fetches)

1. Enumerate branches once and save the list:
   `for p in $(seq 1 10); do gh api "repos/WebKit/WebKit/branches?per_page=100&page=$p" --jq '.[].name'; done > tmp-branches-all.txt`
2. Check which lines exist. Point-release naming varies: main lines are
   `safari-76XX-branch`, but some generations only have `.x` point branches.
3. Byte-fetch the target file from each candidate branch + main:
   `curl -sf "https://raw.githubusercontent.com/WebKit/WebKit/<branch>/Source/WebCore/<path>.cpp" -o file.cpp`
   An HTTP 404 on an old branch means the file (or path) did not exist there — that is
   the "not affected / pre-refactor" boundary evidence.
4. `sha256sum` all copies. Identical hash across branches = byte-identical code, the
   strongest single claim available ("same code on every line X..Y").
5. Grep the guard/site of interest with line numbers and record branch-vs-main
   line-number drift (files move):
   `grep -nE "ASSERT\(|results\[0\]|convert<IDLSequence" file.cpp`
6. Anchor the introduction with the file's commit history:
   `gh api "repos/WebKit/WebKit/commits?path=Source/WebCore/<path>.cpp&per_page=100" --jq '.[] | [.sha[0:10], .commit.author.date, (.commit.message|split("\n")[0])] | @tsv'`
   The oldest commit is when the generation entered main. Reverts + re-lands show up as
   pairs — check both sides.
7. Branch head dates for the table:
   `gh api "repos/WebKit/WebKit/branches/<name>" --jq '[.name, .commit.sha[0:10], .commit.commit.committer.date] | @tsv'`

## Sibling-fix control

Grep the branch that carries the sibling fix. The pattern that proves the incomplete-fix
frame:

- sibling fix present on the newest point branch (runtime guard added)
- target site still ASSERT-only on the main `safari-76XX-branch` of the same generation

That pairing is the report's novelty card. Without it you are claiming a duplicate.

## Evidence artifact

Persist the fetched `.cpp` files + a sha256 manifest into the round dir (e.g.
`12-branch-sweep/`), NOT `/tmp`. The report's version section then cites:

- tested OS/build on-device
- branch table with hashes
- 404 boundary (pre-refactor / not affected)
- commit anchor (when the code entered main)
- a re-grep of the branch carrying the sibling fix, proving no fixed branch exists

## Notes

- Newest branches may not exist yet for the current release: verify with a 404 rather
  than assuming a naming scheme.
- A reverted-then-relanded file has multiple entry dates; the useful one is the
  re-land, because that is the code shipping today.
