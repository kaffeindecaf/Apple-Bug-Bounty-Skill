# ─────────────────────────────────────────────────
# Apple-Bug-Bounty-Skill — Uninstaller (Windows)
# Removes: skill repo, OpenCode global skill links,
#          agent config files created by setup.ps1
# ─────────────────────────────────────────────────

$ErrorActionPreference = "Stop"

$SkillDir = Join-Path $env:USERPROFILE ".apple-bug-bounty-skill"

$SkillNames = @(
    "master-router",
    "ios-kernel-exploit",
    "ios-sandbox-escape",
    "ios-security-pentesting",
    "ios-misc-tooling",
    "ios-bootchain-exploit",
    "ios-code-injection",
    "ios-webkit-exploit",
    "ios-puaf-exploit",
    "ios-coretrust-bypass",
    "ios-research-methodology"
)

function Write-Info { Write-Host "  [INFO]  $args" -ForegroundColor Blue }
function Write-Ok   { Write-Host "  [OK]    $args" -ForegroundColor Green }
function Write-Warn { Write-Host "  [WARN]  $args" -ForegroundColor Yellow }
function Write-Step { Write-Host ""; Write-Host "─── $args ───" -ForegroundColor Cyan }

# ─────────────────────────────────────────────────
# REMOVE OPENCODE GLOBAL SKILL LINKS
# ─────────────────────────────────────────────────

function Remove-OpenCodeSkills {
    Write-Step "Removing OpenCode Skill Links"
    $globalSkillsDir = Join-Path $env:USERPROFILE ".config\opencode\skills"
    $removed = 0

    if (Test-Path $globalSkillsDir) {
        foreach ($name in $SkillNames) {
            $dir = Join-Path $globalSkillsDir $name
            $link = Join-Path $dir "SKILL.md"
            if (Test-Path $link) {
                Remove-Item -Force $link -ErrorAction SilentlyContinue
                if ((Test-Path $dir) -and ((Get-ChildItem $dir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)) {
                    Remove-Item -Force $dir -ErrorAction SilentlyContinue
                }
                $removed++
                Write-Ok "Removed $name"
            }
        }
    } else {
        Write-Info "No global OpenCode skills directory found"
    }

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
