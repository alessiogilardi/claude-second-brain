<#
.SYNOPSIS
    Injects the "Second Brain" documentation system into a destination project.

.DESCRIPTION
    Copies the docs/ and .claude/ structure from the template into the
    destination folder (default: current folder), without overwriting
    existing user files, and hooks up the pre-commit git hook.

.PARAMETER TargetPath
    Destination project folder. Default: "." (current folder).

.PARAMETER InstallUv
    Install uv automatically via the official installer if it isn't
    found on PATH, without prompting for confirmation. Useful for
    automation/CI. Without this switch, a missing uv triggers an
    interactive (y/N) prompt instead.

.EXAMPLE
    .\install.ps1
    .\install.ps1 ..\MyProject
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [switch]$InstallUv
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$templateRoot = Join-Path $scriptRoot "template"
$templateDocs = Join-Path $templateRoot "docs"
$templateClaude = Join-Path $templateRoot ".claude"
$templateClaudeMd = Join-Path $templateRoot "CLAUDE.md"
$mergeSettingsScript = Join-Path $scriptRoot "scripts\merge_settings.py"

if (-not (Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}
$destination = (Resolve-Path -Path $TargetPath).Path

$secondBrainBeginMarker = "<!-- BEGIN SECOND BRAIN SYSTEM"
$secondBrainEndMarker = "<!-- END SECOND BRAIN SYSTEM -->"

function Merge-SecondBrainBlock {
    param(
        [string]$ExistingContent,
        [string]$Block
    )

    if ([string]::IsNullOrWhiteSpace($ExistingContent)) {
        return $Block
    }

    $beginIndex = $ExistingContent.IndexOf($secondBrainBeginMarker)
    $endIndex = $ExistingContent.IndexOf($secondBrainEndMarker)

    if ($beginIndex -ge 0 -and $endIndex -ge 0) {
        # Block already present (install.ps1 re-run): replace it in place,
        # leaving the rest of the user-written file untouched.
        $endIndex += $secondBrainEndMarker.Length
        $before = $ExistingContent.Substring(0, $beginIndex)
        $after = $ExistingContent.Substring($endIndex)
        return $before + $Block + $after
    }

    # No block present: append it at the end without touching existing content.
    return $ExistingContent.TrimEnd() + "`n`n" + $Block + "`n"
}

function Copy-WithoutOverwrite {
    param(
        [string]$Source,
        [string]$Destination,
        [string[]]$ExcludeRelative = @()
    )

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length).TrimStart('\', '/')

        if ($ExcludeRelative -contains $relativePath) {
            return
        }

        $destFile = Join-Path $Destination $relativePath
        $destDir = Split-Path -Parent $destFile

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if (Test-Path $destFile) {
            Write-Host "  [SKIP] $relativePath (already exists)" -ForegroundColor Yellow
        }
        else {
            Copy-Item -Path $_.FullName -Destination $destFile
            Write-Host "  [COPY] $relativePath" -ForegroundColor Green
        }
    }
}

function Install-Uv {
    Write-Host "  Installing uv via the official installer..." -ForegroundColor Cyan
    try {
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    }
    catch {
        Write-Host "  [UV] Installer failed: $_" -ForegroundColor Red
        return $false
    }
    # Refresh PATH for this process in case the installer only updated it
    # for future shells.
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Process") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    return [bool](Get-Command uv -ErrorAction SilentlyContinue)
}

Write-Host "=== Second Brain - Initialization ===" -ForegroundColor Cyan
Write-Host "Destination: $destination"
Write-Host ""

# 1. Create the required folders in the destination project
$foldersToCreate = @(
    (Join-Path $destination ".claude\hooks"),
    (Join-Path $destination ".claude\skills\update-second-brain"),
    (Join-Path $destination "docs\adr")
)

foreach ($folder in $foldersToCreate) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "[CREATED] $folder"
    }
}

# 2. Check for uv -- required for the Stop-hook end-of-session reminder
#    (session_reminder.py) and for merging .claude/settings.json reliably.
Write-Host ""
Write-Host "Checking for uv ..." -ForegroundColor Cyan
$uvAvailable = [bool](Get-Command uv -ErrorAction SilentlyContinue)

if (-not $uvAvailable) {
    Write-Host "  [UV] Not found on PATH." -ForegroundColor Yellow
    Write-Host "       uv is required to run the Stop-hook reminder" -ForegroundColor Yellow
    Write-Host "       (.claude/hooks/session_reminder.py) and to merge" -ForegroundColor Yellow
    Write-Host "       .claude/settings.json safely." -ForegroundColor Yellow

    $shouldInstall = $InstallUv
    if (-not $shouldInstall) {
        try {
            $answer = Read-Host "  Install uv now via the official installer? (y/N)"
            $shouldInstall = $answer -match '^(y|yes)$'
        }
        catch {
            Write-Host "  [UV] Non-interactive shell, can't prompt -- skipping (pass -InstallUv to install automatically)." -ForegroundColor Yellow
            $shouldInstall = $false
        }
    }

    if ($shouldInstall) {
        $uvAvailable = Install-Uv
        if ($uvAvailable) {
            Write-Host "  [UV] Installed successfully." -ForegroundColor Green
        }
        else {
            Write-Host "  [UV] Still not available after install attempt." -ForegroundColor Red
        }
    }

    if (-not $uvAvailable) {
        Write-Host "  [UV] Skipping .claude/settings.json and the Stop-hook reminder." -ForegroundColor Yellow
        Write-Host "       Install uv manually (https://docs.astral.sh/uv/getting-started/installation/)" -ForegroundColor Yellow
        Write-Host "       and re-run install.ps1 to enable the end-of-session reminder." -ForegroundColor Yellow
    }
}
else {
    Write-Host "  [UV] Found." -ForegroundColor Green
}

# 3. Recursively copy docs/ and .claude/ without overwriting existing files.
#    settings.json (and, if uv is unavailable, session_reminder.py) are
#    excluded here and handled separately below.
Write-Host ""
Write-Host "Copying template/docs/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateDocs -Destination (Join-Path $destination "docs")

Write-Host ""
Write-Host "Copying template/.claude/ ..." -ForegroundColor Cyan
$claudeExclude = @("settings.json")
if (-not $uvAvailable) {
    $claudeExclude += "hooks\session_reminder.py"
}
Copy-WithoutOverwrite -Source $templateClaude -Destination (Join-Path $destination ".claude") -ExcludeRelative $claudeExclude

# 4. Merge .claude/settings.json via uv (reliable JSON round-trip), only
#    if uv is available.
if ($uvAvailable) {
    Write-Host ""
    Write-Host "Merging .claude/settings.json ..." -ForegroundColor Cyan
    $templateSettings = Join-Path $templateClaude "settings.json"
    $destSettings = Join-Path $destination ".claude\settings.json"
    $mergeOutput = uv run $mergeSettingsScript --template $templateSettings --destination $destSettings
    switch ($mergeOutput) {
        "created" { Write-Host "  [CREATED] .claude/settings.json" -ForegroundColor Green }
        "merged" { Write-Host "  [MERGED] Stop-hook entry added to existing .claude/settings.json" -ForegroundColor Green }
        "skip-already-present" { Write-Host "  [SKIP] .claude/settings.json already has the Stop-hook entry" -ForegroundColor Yellow }
        default { Write-Host "  [WARN] merge_settings.py: $mergeOutput" -ForegroundColor Red }
    }
}

# 5. Merge the Second Brain block into CLAUDE.md, without replacing
#    content the user has already written.
$destClaudeMd = Join-Path $destination "CLAUDE.md"
Write-Host ""

$templateBlock = Get-Content -Path $templateClaudeMd -Raw
$existingClaudeMd = if (Test-Path $destClaudeMd) { Get-Content -Path $destClaudeMd -Raw } else { "" }
$alreadyMerged = $existingClaudeMd.Contains($secondBrainBeginMarker)

$mergedClaudeMd = Merge-SecondBrainBlock -ExistingContent $existingClaudeMd -Block $templateBlock
Set-Content -Path $destClaudeMd -Value $mergedClaudeMd -NoNewline

if ([string]::IsNullOrWhiteSpace($existingClaudeMd)) {
    Write-Host "[CREATED] CLAUDE.md" -ForegroundColor Green
}
elseif ($alreadyMerged) {
    Write-Host "[UPDATED] Second Brain block in CLAUDE.md (already present, replaced)" -ForegroundColor Green
}
else {
    Write-Host "[MERGED] Second Brain block appended to existing CLAUDE.md" -ForegroundColor Green
}

# 6. Hook up the git hook (only if the destination is a Git repository)
Write-Host ""
$gitDir = Join-Path $destination ".git"
if (Test-Path $gitDir) {
    Push-Location $destination
    try {
        git config core.hooksPath .claude/hooks
        Write-Host "[GIT] core.hooksPath set to .claude/hooks" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[GIT] No Git repository found in $destination, skipping hook setup." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Second Brain successfully set up in: $destination ===" -ForegroundColor Cyan
