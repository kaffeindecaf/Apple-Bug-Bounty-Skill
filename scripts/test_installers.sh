#!/usr/bin/env bash
# Installer round-trip test.
#
# Runs setup + uninstall in a throwaway HOME and asserts the result, including
# the failures that already shipped once:
#   - a skill module linked by setup but never removed by uninstall
#   - reference symlinks left behind after the repo is gone
#   - a foreign skill dir in ~/.config/opencode/skills being deleted
#
# Usage: scripts/test_installers.sh [--ps]
#   --ps   also test setup.ps1 / uninstall.ps1 (needs pwsh on PATH)
#
# Exit status: 0 = all assertions passed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/abbs-test.XXXXXX")"
EXPECTED_LINKS=18      # 17 skill modules + master-router
EXPECTED_REFS=5        # skills that carry a references/ tree
FAILED=0
TEST_PS=0
[ "${1:-}" = "--ps" ] && TEST_PS=1

# shellcheck disable=SC2329  # invoked by the EXIT trap below
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

ok()    { printf '  ok    %s\n' "$1"; }
fail()  { printf '  FAIL  %s\n' "$1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($3)"; else fail "$1: expected $3, got $2"; fi; }
assert(){ if [ "$2" = "0" ]; then ok "$1"; else fail "$1"; fi; }

# git-lfs configured, as it is on the CI runner and on any machine that has it
# installed. projects/ tracks large binaries with git-lfs, so a clone that lets
# the smudge filter run dies with "Clone succeeded, but checkout failed" (128)
# and the install is dead. Every clone in this test happens under this config.
cat > "$SANDBOX/.gitconfig" <<'GITCONFIG'
[filter "lfs"]
	process = git-lfs filter-process
	required = true
GITCONFIG

# A stub `opencode` on PATH is what makes setup exercise the OpenCode branch.
mkdir -p "$SANDBOX/bin"
printf '#!/bin/sh\necho "1.18.16"\n' > "$SANDBOX/bin/opencode"
chmod +x "$SANDBOX/bin/opencode"

sandbox_env() { env -i HOME="$SANDBOX" USERPROFILE="$SANDBOX" PATH="$SANDBOX/bin:/usr/bin:/bin" TERM=dumb "$@"; }

links_dir()      { echo "$SANDBOX/.config/opencode/skills"; }
count_links()    { find "$(links_dir)" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' '; }
count_refs()     { find "$(links_dir)" -maxdepth 2 -name references 2>/dev/null | wc -l | tr -d ' '; }
count_dangling() { find "$(links_dir)" -xtype l 2>/dev/null | wc -l | tr -d ' '; }
readable()       { head -1 "$1" >/dev/null 2>&1; }
show_log() {
    # \r -> \n first: the progress spinner rewrites one long line, so a raw tail
    # would dump the whole spin history instead of the error
    printf '  ---- %s ----\n' "$1"
    tr '\r' '\n' < "$SANDBOX/$1" 2>/dev/null \
        | grep -aiE 'fatal|error|denied|unable|failed|timed out|not found' \
        | tail -6 | cut -c1-160 | sed 's/^/  ! /'
    tr '\r' '\n' < "$SANDBOX/$1" 2>/dev/null | tail -4 | cut -c1-160 | sed 's/^/  | /'
}

# Caller sets SETUP_CMD / UNINSTALL_CMD to a command + args before calling.
run_roundtrip() {
    local label="$1"

    printf '\n[%s] setup -> uninstall round trip\n' "$label"
    ( cd "$REPO" && printf 'a\ny\n' | sandbox_env "${SETUP_CMD[@]}" ) > "$SANDBOX/$label.setup.log" 2>&1
    local rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "setup exit 0"
    else
        fail "setup exited $rc"
        show_log "$label.setup.log"
    fi

    check "linked dirs" "$(count_links)" "$EXPECTED_LINKS"
    check "references trees" "$(count_refs)" "$EXPECTED_REFS"
    check "project-local links" "$(find "$SANDBOX/.apple-bug-bounty-skill/.opencode/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')" "$EXPECTED_LINKS"
    readable "$(links_dir)/ios-kernel-exploit/SKILL.md" && assert "SKILL.md symlink resolves" 0
    readable "$(links_dir)/ios-variant-hunting/references/branch-version-sweep.md" && assert "reference reachable through the symlinked skill" 0

    # a skill dir the user installed by hand must never be touched
    mkdir -p "$(links_dir)/foreign-skill"
    echo "# mine" > "$(links_dir)/foreign-skill/SKILL.md"

    ( cd "$REPO" && printf 'y\ny\n' | sandbox_env "${UNINSTALL_CMD[@]}" ) > "$SANDBOX/$label.uninstall.log" 2>&1
    rc=$?
    if [ "$rc" -eq 0 ]; then
        ok "uninstall exit 0"
    else
        fail "uninstall exited $rc"
        show_log "$label.uninstall.log"
    fi

    check "remaining entries (foreign only)" "$(count_links)" "1"
    if [ -f "$(links_dir)/foreign-skill/SKILL.md" ]; then ok "foreign skill survived"; else fail "foreign skill was deleted"; fi
    check "dangling links" "$(count_dangling)" "0"
    if [ -d "$SANDBOX/.apple-bug-bounty-skill" ]; then fail "repo dir survived"; else ok "repo dir removed"; fi
}

mkdir -p "$SANDBOX"
printf 'sandbox: %s\n' "$SANDBOX"
SETUP_CMD=( ./setup ); UNINSTALL_CMD=( ./uninstall )
run_roundtrip "bash"

printf '\n[bash] second setup is idempotent\n'
rm -rf "$(links_dir)/foreign-skill"
( cd "$REPO" && printf 'a\ny\n' | sandbox_env ./setup ) > "$SANDBOX/bash.setup2.log" 2>&1
check "linked dirs after re-run" "$(count_links)" "$EXPECTED_LINKS"
check "references trees after re-run" "$(count_refs)" "$EXPECTED_REFS"

printf '\n[bash] repo deleted first: dangling links are still cleaned up\n'
rm -f "$(links_dir)/.apple-bug-bounty-skill.links"     # simulate an install by an older setup
rm -rf "$SANDBOX/.apple-bug-bounty-skill"
check "dangling before uninstall" "$(count_dangling)" "$((EXPECTED_LINKS + EXPECTED_REFS))"
( cd "$REPO" && printf 'y\n' | sandbox_env ./uninstall ) > "$SANDBOX/bash.uninstall2.log" 2>&1
check "remaining entries" "$(count_links)" "0"
check "dangling after uninstall" "$(count_dangling)" "0"

if [ "$TEST_PS" -eq 1 ]; then
    PW_SH="$(command -v pwsh || true)"
    if [ -n "$PW_SH" ]; then
        # absolute path: the sandbox env strips PATH down to /usr/bin:/bin
        SETUP_CMD=( "$PW_SH" -NoProfile -File "$REPO/setup.ps1" )
        UNINSTALL_CMD=( "$PW_SH" -NoProfile -File "$REPO/uninstall.ps1" )
        run_roundtrip "ps"
    else
        printf '\n[ps] SKIPPED: pwsh not on PATH\n'
    fi
fi

printf '\n'
if [ "$FAILED" -eq 0 ]; then
    echo "installer tests: PASS"
    exit 0
fi
echo "installer tests: $FAILED FAILURE(S)"
exit 1
