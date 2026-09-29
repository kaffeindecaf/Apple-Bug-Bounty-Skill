# ─────────────────────────────────────────────────
# Apple-Bug-Bounty-Skill — Uninstaller (Windows)
# Removes: skill repo, OpenCode global skill links,
#          agent config files created by setup.ps1
# ─────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$SkillDir = Join-Path $env:USERPROFILE ".apple-bug-bounty-skill"

# Identify our own symlinks by their target instead of a hardcoded name list.
# The list drifted twice (a module added to setup.ps1 but not here left dangling
# links behind) and a stale link still carries this path even when it is broken.
$SkillDirMarker = ".apple-bug-bounty-skill"
# setup.ps1 also records every name it linked, as a fallback for link targets a
# given PowerShell version cannot read back.
$ManifestName = ".apple-bug-bounty-skill.links"

function Write-Info { Write-Host "  [INFO]  $args" -ForegroundColor Blue }
function Write-Ok   { Write-Host "  [OK]    $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  [WARN]  $args" -ForegroundColor Yellow }
function Write-Step { Write-Host ""; Write-Host "─── $args ───" -ForegroundColor Cyan }

# ─────────────────────────────────────────────────
# REMOVE OPENCODE GLOBAL SKILL LINKS
# ─────────────────────────────────────────────────

function Get-LinkTarget {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return "" }
    # LinkTarget is PowerShell 6+, Target covers 5.1 reparse points
    return "$($item.LinkTarget)$($item.Target)"
}

function Remove-OpenCodeSkills {
    Write-Step "Removing OpenCode Skill Links"
    $globalSkillsDir = Join-Path $env:USERPROFILE ".config\opencode\skills"
    $removed = 0

    if (-not (Test-Path -LiteralPath $globalSkillsDir)) {
        Write-Info "No global OpenCode skills directory found"
        return
    }

    # Names recorded by setup.ps1 (covers dangling links whose target is gone)
    $recorded = @{}
    $manifest = Join-Path $globalSkillsDir $ManifestName
    if (Test-Path -LiteralPath $manifest) {
        Get-Content -LiteralPath $manifest -ErrorAction SilentlyContinue |
            Where-Object { $_ -and $_.Trim() } |
            ForEach-Object { $recorded[$_.Trim()] = $true }
    }

    foreach ($dir in Get-ChildItem -LiteralPath $globalSkillsDir -Directory -Force -ErrorAction SilentlyContinue) {
        $link = Join-Path $dir.FullName "SKILL.md"
        $target = Get-LinkTarget $link

        $isOurs = ($target -like "*$SkillDirMarker*") -or $recorded.ContainsKey($dir.Name)
        if (-not $isOurs) { continue }

        Remove-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
        # setup.ps1 adds a references link for skills that carry reference files.
        # Remove it explicitly: a leftover entry makes the directory rmdir fail.
        Remove-Item -LiteralPath (Join-Path $dir.FullName "references") -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $dir.FullName -Force -Recurse -ErrorAction SilentlyContinue
        $removed++
        Write-Ok "Removed $($dir.Name)"
    }

    Remove-Item -LiteralPath $manifest -Force -ErrorAction SilentlyContinue

    if ($removed -gt 0) {
        Write-Ok "Removed $removed global skill link(s)"
    } else {
        Write-Info "No OpenCode skill links found"
    }
}

# ─────────────────────────────────────────────────
# REMOVE AGENT CONFIG FILES
# ─────────────────────────────────────────────────

function Remove-AgentConfigs {
    Write-Step "Removing Agent Config Files"

    $files = @(
        @{ Path = Join-Path $env:USERPROFILE ".claude\instructions.md"; Label = "Claude Code instructions" },
        @{ Path = Join-Path $env:USERPROFILE ".codex\instructions.md";  Label = "OpenAI Codex instructions" },
        @{ Path = Join-Path $env:USERPROFILE ".gemini\GEMINI.md";       Label = "Google Gemini extension" }
    )

    foreach ($item in $files) {
        $f = $item.Path
        if (Test-Path $f) {
            $content = Get-Content $f -Raw -ErrorAction SilentlyContinue
            if ($content -match "Apple-Bug-Bounty-Skill") {
                Remove-Item -Force $f
                Write-Ok "Removed $($item.Label) ($f)"
            } else {
                Write-Warn "Skipping $f — does not look like an Apple-Bug-Bounty-Skill file"
            }
        } else {
            Write-Info "$($item.Label) not present"
        }
    }
}

# ─────────────────────────────────────────────────
# REMOVE SKILL REPOSITORY
# ─────────────────────────────────────────────────

function Remove-Repository {
    Write-Step "Removing Skill Repository"

    if (Test-Path $SkillDir) {
        Write-Info "Found repository at $SkillDir"
        $answer = Read-Host "  Remove the repository and all its contents? [y/N]"
        if ($answer -match "^[Yy]") {
            Remove-Item -Recurse -Force $SkillDir
            Write-Ok "Removed $SkillDir"
        } else {
            Write-Info "Kept repository at $SkillDir"
        }
    } else {
        Write-Info "Repository not found at $SkillDir"
    }
}

# ─────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────

Write-Host "          Apple-Bug-Bounty-Skill Uninstall"
Write-Host "        Removes skills, links, and configs" -ForegroundColor Cyan
Write-Host ""

Write-Info "This will remove everything installed by setup.ps1"
Write-Host ""

$confirm = Read-Host "  Continue? [y/N]"
if ($confirm -notmatch "^[Yy]") {
    Write-Info "Aborted. Nothing was removed."
    exit 0
}

Remove-OpenCodeSkills
Remove-AgentConfigs
Remove-Repository

Write-Host ""
Write-Host "          Uninstall Complete" -ForegroundColor Green
Write-Host ""
Write-Host "  Note: project-local copies (.opencode\skills inside"
Write-Host "  a cloned repo) are removed with the repository."
Write-Host ""
