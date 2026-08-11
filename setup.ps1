# Apple-Bug-Bounty-Skill — Interactive Setup (Windows PowerShell)
# Supports: Windows 10+, PowerShell 5.1+
# Configures: Claude Code, Cursor, Codex, OpenCode,
#              Windsurf, Copilot, Gemini, Qwen, Kimi

param()

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$SkillDir = "$env:USERPROFILE\.apple-bug-bounty-skill"
$RepoUrl  = "https://github.com/kaffeindecaf/Apple-Bug-Bounty-Skill.git"

# ─────────────────────────────────────────────────
# WOLF BANNER
# ─────────────────────────────────────────────────

function Show-Banner {
    Write-Host @"
                    / V\
                  / `  /
                 <<   |
                 /    |
               /      |
             /        |
           /    \  \ /
          (      ) | |
  ________|   _/_  | |
<__________\______)\__)
"@ -ForegroundColor Cyan

    Write-Host "          Apple-Bug-Bounty-Skill Setup" -ForegroundColor White
    Write-Host "    10 skills · 8 options · 9 agents · 0 fluff" -ForegroundColor Cyan
    Write-Host ""
}

# ─────────────────────────────────────────────────
# UTILITY FUNCTIONS
# ─────────────────────────────────────────────────

function Write-Info  { Write-Host "  [INFO]  $args" -ForegroundColor Blue }
function Write-Ok    { Write-Host "  [OK]    $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "  [WARN]  $args" -ForegroundColor Yellow }
function Write-Err   { Write-Host "  [ERROR] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "`n$('─' * 50)" -ForegroundColor Cyan; Write-Host "  $args" -ForegroundColor White }

# ─────────────────────────────────────────────────
# SYSTEM DETECTION
# ─────────────────────────────────────────────────

function Test-Command($cmd) {
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Detect-OS {
    Write-Step "Detecting System"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Info "OS: $($os.Caption) ($($os.OSArchitecture))"
    Write-Info "PowerShell: $($PSVersionTable.PSVersion)"

    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warn "Not running as Administrator. Some features may be limited."
        Write-Info "Re-run as Administrator if you encounter permission errors:"
        Write-Info "  Right-click PowerShell → Run as Administrator"
    }
}

# ─────────────────────────────────────────────────
# DEPENDENCY CHECK
# ─────────────────────────────────────────────────

function Check-Deps {
    Write-Step "Checking System Dependencies"

    $missing = @()

    if (Test-Command git) {
        Write-Ok "git found: $(git --version 2>&1)"
    } else {
        Write-Warn "git not found"
        $missing += "git"
    }

    if (Test-Command python) {
        Write-Ok "python found: $(python --version 2>&1)"
    } elseif (Test-Command python3) {
        Write-Ok "python3 found: $(python3 --version 2>&1)"
        Set-Alias -Name python -Value python3 -Scope Script
    } else {
        Write-Warn "python not found (needed for XPF/TSS/activation scripts)"
        $missing += "python"
    }

    if (Test-Command gh) {
        Write-Ok "gh (GitHub CLI) found: $(gh --version 2>&1 | Select-Object -First 1)"
    } else {
        Write-Warn "gh not found (needed for PR contributions)"
        $missing += "gh"
    }

    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Warn "Missing packages: $($missing -join ', ')"
        Write-Host "  Install them manually:"
        foreach ($pkg in $missing) {
            switch ($pkg) {
                "git"    { Write-Info "  winget install --id Git.Git -e --source winget" }
                "python" { Write-Info "  winget install --id Python.Python.3.12 -e --source winget" }
                "gh"     { Write-Info "  winget install --id GitHub.cli -e --source winget" }
            }
        }
        Write-Host ""
        $answer = Read-Host "  Continue anyway? [Y/n]"
        if ($answer -match '^[Nn]') {
            exit 0
        }
    }
}

# ─────────────────────────────────────────────────
# AGENT DETECTION
# ─────────────────────────────────────────────────

$Global:Agents = @()
$Global:AgentNames = @{}
$Global:AgentConfigs = @{}
$Global:AgentPaths = @{}
$Global:AgentDetect = @{}

function Detect-Agents {
    Write-Step "Detecting Installed AI Agents"
    $Global:Agents = @()

    # Claude Code
    if (Test-Command claude) {
        $Global:Agents += "claude"
        $Global:AgentNames["claude"] = "Claude Code"
        $Global:AgentConfigs["claude"] = ".claude/instructions.md"
        $Global:AgentPaths["claude"] = "$env:USERPROFILE\.claude"
        $Global:AgentDetect["claude"] = "cli at: $(Get-Command claude | Select-Object -ExpandProperty Source)"
        Write-Ok "Claude Code detected"
    } else {
        Write-Info "Claude Code not detected (install: npm install -g @anthropic-ai/claude-code)"
    }

    # Cursor
    $cursorPaths = @(
        "$env:LOCALAPPDATA\Programs\Cursor\Cursor.exe",
        "$env:APPDATA\Local\Programs\cursor\Cursor.exe",
        "${env:ProgramFiles}\Cursor\Cursor.exe"
    )
    $cursorFound = Test-Command cursor
    foreach ($p in $cursorPaths) {
        if (Test-Path $p) { $cursorFound = $true; break }
    }
    if ($cursorFound) {
        $Global:Agents += "cursor"
        $Global:AgentNames["cursor"] = "Cursor"
        $Global:AgentConfigs["cursor"] = ".cursorrules"
        $Global:AgentPaths["cursor"] = $SkillDir
        $Global:AgentDetect["cursor"] = "app detected"
        Write-Ok "Cursor detected"
    } else {
        Write-Info "Cursor not detected (download: https://cursor.com)"
    }

    # OpenAI Codex
    if (Test-Command codex) {
        $Global:Agents += "codex"
        $Global:AgentNames["codex"] = "OpenAI Codex"
        $Global:AgentConfigs["codex"] = ".codex.md"
        $Global:AgentPaths["codex"] = "$env:USERPROFILE\.codex"
        $Global:AgentDetect["codex"] = "cli at: $(Get-Command codex | Select-Object -ExpandProperty Source)"
        Write-Ok "OpenAI Codex detected"
    } else {
        Write-Info "OpenAI Codex not detected (install: npm install -g @openai/codex)"
    }

    # OpenCode
    if (Test-Command opencode) {
        $Global:Agents += "opencode"
        $Global:AgentNames["opencode"] = "OpenCode"
        $Global:AgentConfigs["opencode"] = "opencode.json"
        $Global:AgentPaths["opencode"] = $SkillDir
        $Global:AgentDetect["opencode"] = "cli at: $(Get-Command opencode | Select-Object -ExpandProperty Source)"
        Write-Ok "OpenCode detected"
    } else {
        Write-Info "OpenCode not detected (see: https://opencode.ai)"
    }

    # Windsurf
    $wsPaths = @(
        "$env:LOCALAPPDATA\Programs\Windsurf\Windsurf.exe",
        "${env:ProgramFiles}\Windsurf\Windsurf.exe"
    )
    $wsFound = Test-Command windsurf
    foreach ($p in $wsPaths) {
        if (Test-Path $p) { $wsFound = $true; break }
    }
    if ($wsFound) {
        $Global:Agents += "windsurf"
        $Global:AgentNames["windsurf"] = "Windsurf"
        $Global:AgentConfigs["windsurf"] = ".windsurfrules"
        $Global:AgentPaths["windsurf"] = $SkillDir
        $Global:AgentDetect["windsurf"] = "app detected"
        Write-Ok "Windsurf detected"
    } else {
        Write-Info "Windsurf not detected (download: https://codeium.com/windsurf)"
    }

    # GitHub Copilot
    if (Test-Command gh) {
        $ext = gh extension list 2>$null | Where-Object { $_ -match "copilot" }
        if ($ext) {
            $Global:Agents += "copilot"
            $Global:AgentNames["copilot"] = "GitHub Copilot"
            $Global:AgentConfigs["copilot"] = ".github/copilot-instructions.md"
            $Global:AgentPaths["copilot"] = $SkillDir
            $Global:AgentDetect["copilot"] = "gh extension detected"
            Write-Ok "GitHub Copilot detected"
        } else {
            Write-Info "GitHub Copilot CLI not detected (install: gh extension install github/gh-copilot)"
        }
    }

    # Gemini
    if (Test-Command gemini -or (Test-Path "$env:USERPROFILE\.gemini\config.json")) {
        $Global:Agents += "gemini"
        $Global:AgentNames["gemini"] = "Google Gemini"
        $Global:AgentConfigs["gemini"] = "GEMINI.md"
        $Global:AgentPaths["gemini"] = "$env:USERPROFILE\.gemini"
        $Global:AgentDetect["gemini"] = "detected"
        Write-Ok "Gemini detected"
    } else {
        Write-Info "Gemini CLI not detected (see: https://github.com/google-gemini/gemini-cli)"
    }

    # Qwen (always available — config only)
    $Global:Agents += "qwen"
    $Global:AgentNames["qwen"] = "Alibaba Qwen"
    $Global:AgentConfigs["qwen"] = "qwen-extension.json"
    $Global:AgentPaths["qwen"] = $SkillDir
    $Global:AgentDetect["qwen"] = "always available (config-only)"

    # Kimi (always available — config only)
    $Global:Agents += "kimi"
    $Global:AgentNames["kimi"] = "Moonshot Kimi"
    $Global:AgentConfigs["kimi"] = "kimi.plugin.json"
    $Global:AgentPaths["kimi"] = $SkillDir
    $Global:AgentDetect["kimi"] = "always available (config-only)"

    Write-Host ""
    Write-Info "Found $($Global:Agents.Count) compatible agent(s) to configure"
}

# ─────────────────────────────────────────────────
# INTERACTIVE SELECTION
# ─────────────────────────────────────────────────

$Global:SelectedAgents = @()

function Select-Agents {
    Write-Step "Select Agents to Configure"

    Write-Host ""
    Write-Host "  Available agents:" -ForegroundColor White
    Write-Host ""

    $idx = 1
    $Global:AgentIdx = @{}
    foreach ($agent in $Global:Agents) {
        $name = $Global:AgentNames[$agent]
        $detect = $Global:AgentDetect[$agent]
        $num = "{0,2}" -f $idx
        Write-Host "  $num) $($name.PadRight(25)) $detect" -ForegroundColor Cyan
        $Global:AgentIdx[$idx] = $agent
        $idx++
    }

    Write-Host ""
    Write-Host "   a)  All of the above" -ForegroundColor White
    Write-Host "   q)  Quit without configuring" -ForegroundColor White
    Write-Host ""

    $selection = Read-Host "  Your choice (comma/space-separated numbers, 'a' for all, or 'q')"

    if ($selection -eq 'q') {
        Write-Host ""
        Write-Info "No agents configured. Run this script again anytime."
        exit 0
    }

    $Global:SelectedAgents = @()
    if ($selection -eq 'a') {
        $Global:SelectedAgents = $Global:Agents
    } else {
        $nums = $selection -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        foreach ($n in $nums) {
            if ($Global:AgentIdx.ContainsKey($n)) {
                $Global:SelectedAgents += $Global:AgentIdx[$n]
            }
        }
    }

    Write-Host ""
    Write-Info "Will configure:"
    foreach ($agent in $Global:SelectedAgents) {
        Write-Host "    - $($Global:AgentNames[$agent])" -ForegroundColor Green
    }
    Write-Host ""

    $confirm = Read-Host "  Proceed? [Y/n]"
    if ($confirm -match '^[Nn]') {
        Write-Info "Aborted. Run this script again anytime."
        exit 0
    }
}

# ─────────────────────────────────────────────────
# SKILL INSTALLATION
# ─────────────────────────────────────────────────

function Clone-Or-Update {
    Write-Step "Setting Up Skill Repository"

    if (Test-Path "$SkillDir\.git") {
        Write-Info "Repository exists at $SkillDir"
        Write-Info "Pulling latest changes..."
        Push-Location $SkillDir
        try {
            $output = git pull --ff-only origin main 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "Pull may have had issues (exit code: $LASTEXITCODE), continuing"
            }
            if ($output) {
                $output | ForEach-Object { Write-Info "  git: $_" }
            }
            Write-Ok "Repository updated"
        } finally {
            Pop-Location
        }
    } else {
        Write-Info "Cloning into $SkillDir..."
        $output = git clone --depth 1 $RepoUrl $SkillDir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Clone failed (exit code: $LASTEXITCODE)"
            if ($output) { $output | ForEach-Object { Write-Err "  git: $_" } }
            exit 1
        }
        Write-Ok "Repository cloned"
    }

    Write-Info "Verifying repository integrity..."
    $required = @(
        "SKILL.md",
        "opencode.json",
        "options/SYSTEM.md",
        "offsets.yaml",
        "skills/ios-kernel-exploit.md",
        "skills/ios-sandbox-escape.md",
        "skills/ios-security-pentesting.md",
        "skills/ios-misc-tooling.md",
        "skills/ios-bootchain-exploit.md",
        "skills/ios-code-injection.md",
        "skills/ios-webkit-exploit.md",
        "skills/ios-puaf-exploit.md",
        "skills/ios-coretrust-bypass.md",
        "skills/ios-research-methodology.md"
    )
    foreach ($f in $required) {
        $full = Join-Path $SkillDir $f
        if (Test-Path $full) {
            Write-Ok "Found: $f"
        } else {
            Write-Err "Missing: $f — repository may be corrupted"
        }
    }
}

# ─────────────────────────────────────────────────
# OPencode SKILL SETUP
# ─────────────────────────────────────────────────

function Setup-OpenCodeSkills {
    Write-Step "Setting Up OpenCode Skill Discovery"
    Write-Info "OpenCode discovers skills from .opencode/skills/<name>/SKILL.md"
    Write-Info "Creating OpenCode skill directory structure..."

    $skillsDir = Join-Path $SkillDir ".opencode\skills"
    if (Test-Path $skillsDir) {
        Remove-Item -Recurse -Force $skillsDir
    }
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

    $skillMap = @{
        "master-router"              = "SKILL.md"
        "ios-kernel-exploit"         = "skills\ios-kernel-exploit.md"
        "ios-sandbox-escape"         = "skills\ios-sandbox-escape.md"
        "ios-security-pentesting"    = "skills\ios-security-pentesting.md"
        "ios-misc-tooling"           = "skills\ios-misc-tooling.md"
        "ios-bootchain-exploit"      = "skills\ios-bootchain-exploit.md"
        "ios-code-injection"         = "skills\ios-code-injection.md"
        "ios-webkit-exploit"         = "skills\ios-webkit-exploit.md"
        "ios-puaf-exploit"           = "skills\ios-puaf-exploit.md"
        "ios-coretrust-bypass"       = "skills\ios-coretrust-bypass.md"
        "ios-research-methodology"   = "skills\ios-research-methodology.md"
    }

    $total = $skillMap.Count
    $count = 0

    foreach ($name in $skillMap.Keys) {
        $src = Join-Path $SkillDir $skillMap[$name]
        $dstdir = Join-Path $skillsDir $name
        New-Item -ItemType Directory -Path $dstdir -Force | Out-Null

        if (Test-Path $src) {
            try {
                New-Item -ItemType SymbolicLink -Path (Join-Path $dstdir "SKILL.md") -Target $src -Force -ErrorAction Stop | Out-Null
            } catch {
                Copy-Item $src (Join-Path $dstdir "SKILL.md") -Force
            }
            $count++
        } else {
            Write-Warn "Skill source not found: $src"
        }
    }

    Write-Ok "Created $count OpenCode skill links in $skillsDir"

    $targetJson = Join-Path $SkillDir "opencode.json"
    if (Test-Path $targetJson) {
        $backup = "$targetJson.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $targetJson $backup
        Write-Info "Backed up existing opencode.json to $backup"
    }

    Write-Info "OpenCode skill discovery configured"
}

function Configure-Agent($agent) {
    $name = $Global:AgentNames[$agent]
    $config = $Global:AgentConfigs[$agent]
    $path = $Global:AgentPaths[$agent]

    Write-Step "Configuring $name"

    $src = Join-Path $SkillDir $config
    if (-not (Test-Path $src)) {
        Write-Err "Config file not found: $src"
        return
    }

    switch ($agent) {
        "claude" {
            $dest = "$env:USERPROFILE\.claude\instructions.md"
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
            Copy-Item $src $dest -Force
            Write-Ok "Copied $config → $dest"
            Write-Info "Claude Code will auto-load this on session start"
        }
        "cursor" {
            Write-Info "Cursor auto-ingests .cursorrules from the workspace directory."
            Write-Info "Open $SkillDir as a workspace in Cursor to activate."
            Write-Info "Skills available via: @skills/ios-kernel-exploit.md (etc.)"
        }
        "codex" {
            $dest = "$env:USERPROFILE\.codex\instructions.md"
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
            Copy-Item $src $dest -Force
            Write-Ok "Copied $config → $dest"
            Write-Info "Run: codex --instructions $env:USERPROFILE\.codex\instructions.md"
        }
        "opencode" {
            Write-Info "OpenCode auto-loads opencode.json from the project root."
            Write-Info "cd $SkillDir; opencode to start."
        }
        "windsurf" {
            Write-Info "Windsurf auto-ingests .windsurfrules from the workspace directory."
            Write-Info "Open $SkillDir as a workspace in Windsurf to activate."
        }
        "copilot" {
            $dest = Join-Path $SkillDir ".github\copilot-instructions.md"
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
            Copy-Item $src $dest -Force
            Write-Ok "Copied $config"
            Write-Info "GitHub Copilot will use these instructions on this repo."
        }
        "gemini" {
            $dest = "$env:USERPROFILE\.gemini\GEMINI.md"
            New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
            Copy-Item $src $dest -Force
            Write-Ok "Copied $config → $dest"
            Write-Info "Gemini will use this as an extension."
        }
        default {
            Write-Info "$name plugin config is at: $src"
            Write-Info "Import this file in $name's plugin settings."
        }
    }

    Write-Ok "$name configured successfully"
    Write-Host ""
}

# ─────────────────────────────────────────────────
# VERIFICATION
# ─────────────────────────────────────────────────

function Verify-Setup {
    Write-Step "Verifying Setup"

    Write-Host ""
    Write-Host "  Configured agents:" -ForegroundColor White
    foreach ($agent in $Global:SelectedAgents) {
        $name = $Global:AgentNames[$agent]
        $config = $Global:AgentConfigs[$agent]
        $path = $Global:AgentPaths[$agent]

        $src = Join-Path $SkillDir $config
        $exists = Test-Path $src

        $dest = switch ($agent) {
            "claude"  { "$env:USERPROFILE\.claude\instructions.md" }
            "codex"   { "$env:USERPROFILE\.codex\instructions.md" }
            "gemini"  { "$env:USERPROFILE\.gemini\GEMINI.md" }
            default   { $src }
        }
        $destExists = Test-Path $dest

        if ($exists -or $destExists) {
            Write-Host "  [+] $($name.PadRight(25)) $dest" -ForegroundColor Green
        } else {
            Write-Host "  [-] $($name.PadRight(25)) config missing" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "  Skill files:" -ForegroundColor White
    $skillCount = (Get-ChildItem "$SkillDir\skills\*.md" -ErrorAction SilentlyContinue).Count
    $optionCount = (Get-ChildItem "$SkillDir\options\*.md" -ErrorAction SilentlyContinue).Count
    $opencodeSkillCount = 0
    $opencodeSkillsDir = Join-Path $SkillDir ".opencode\skills"
    if (Test-Path $opencodeSkillsDir) {
        $opencodeSkillCount = (Get-ChildItem "$opencodeSkillsDir\*\SKILL.md" -ErrorAction SilentlyContinue).Count
    }
    Write-Host "  [+] $skillCount skills loaded" -ForegroundColor Green
    Write-Host "  [+] $optionCount options available" -ForegroundColor Green
    Write-Host "  [+] $opencodeSkillCount OpenCode skills linked" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Quick test commands:" -ForegroundColor White
    foreach ($agent in $Global:SelectedAgents) {
        switch ($agent) {
            "claude"   { Write-Host "    claude `"Load ios-kernel-exploit skill`"" -ForegroundColor Cyan }
            "cursor"   { Write-Host "    cursor $SkillDir   (open workspace)" -ForegroundColor Cyan }
            "codex"    { Write-Host "    codex --instructions `"$env:USERPROFILE\.codex\instructions.md`"" -ForegroundColor Cyan }
            "opencode" { Write-Host "    opencode                (cd `"$SkillDir`" first)" -ForegroundColor Cyan }
            "windsurf" { Write-Host "    windsurf $SkillDir  (open workspace)" -ForegroundColor Cyan }
            default    { Write-Host "    $agent config ready at $src" -ForegroundColor Cyan }
        }
    }
}

# ─────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────

function Show-Summary {
    Write-Host ""
    Write-Host ("=" * 52) -ForegroundColor Green
    Write-Host "          Setup Complete" -ForegroundColor Green
    Write-Host ("=" * 52) -ForegroundColor Green
    Write-Host ""
    Write-Host "  Skills location: $SkillDir" -ForegroundColor Cyan
    Write-Host "  Agents configured: $($Global:SelectedAgents.Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Options to try:" -ForegroundColor White
    Write-Host "    --adhd       ADHD-friendly, action-first output" -ForegroundColor Yellow
    Write-Host "    --verbose    Maximum detail, all offsets, full code" -ForegroundColor Yellow
    Write-Host "    --thinking   Deep chain-of-thought, multiple hypotheses" -ForegroundColor Yellow
    Write-Host "    --new        Audit mode, rank findings critical-to-low" -ForegroundColor Yellow
    Write-Host "    --idea       Project/feature idea generator" -ForegroundColor Yellow
    Write-Host "    --bug        Bug checker -> writes foundbugs.md" -ForegroundColor Yellow
    Write-Host "    --fix        Bug fixer (chained from --bug)" -ForegroundColor Yellow
    Write-Host "    --cash       Money-focused ideas + career paths" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To contribute back:" -ForegroundColor White
    Write-Host "    Fork $RepoUrl" -ForegroundColor Cyan
    Write-Host "    Run gh pr create --repo kaffeindecaf/Apple-Bug-Bounty-Skill" -ForegroundColor Cyan
    Write-Host ""
}

# ─────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────

function Main {
    Show-Banner
    Detect-OS
    Check-Deps
    Detect-Agents

    if ($Global:Agents.Count -eq 0) {
        Write-Err "No AI agents detected on this system."
        Write-Info "You can still clone the repository: git clone $RepoUrl"
        Write-Info "Then manually load SKILL.md into your preferred agent."
        exit 1
    }

    Select-Agents

    if ($Global:SelectedAgents.Count -eq 0) {
        Write-Info "Nothing to configure. Goodbye."
        exit 0
    }

    Clone-Or-Update

    if ($Global:SelectedAgents -contains "opencode") {
        Setup-OpenCodeSkills
    }

    foreach ($agent in $Global:SelectedAgents) {
        Configure-Agent $agent
    }

    Verify-Setup
    Show-Summary
}

Main
