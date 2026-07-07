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

.PARAMETER ForceHooksPath
    Overwrite an existing git core.hooksPath (or a pre-existing
    .git/hooks/pre-commit) even if it isn't managed by Second Brain.
    Without this switch, install.ps1 warns and leaves it untouched.

.PARAMETER Force
    Overwrite system-owned files (.claude/hooks/pre-commit,
    .claude/hooks/session_reminder.py, .claude/skills/update-second-brain/
    SKILL.md) even when they were modified locally since the last install,
    or were never tracked by a Second Brain manifest at all. Without this
    switch, install.ps1 only upgrades a system-owned file when it is
    still byte-identical to what the previous install wrote.

.PARAMETER Uninstall
    Remove the Second Brain system from TargetPath instead of installing
    it: the CLAUDE.md block, the Stop-hook entry in .claude/settings.json,
    core.hooksPath (only if it's still ".claude/hooks"), and all
    system-owned files. docs/ is left in place -- pass -PurgeDocs to
    remove it too.

.PARAMETER PurgeDocs
    Only meaningful with -Uninstall: also delete docs/. Without it,
    uninstalling keeps docs/ since it's user-authored content, not a
    Second Brain system file.

.EXAMPLE
    .\install.ps1
    .\install.ps1 ..\MyProject
    .\install.ps1 ..\MyProject -Uninstall
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = ".",
    [switch]$InstallUv,
    [switch]$ForceHooksPath,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$PurgeDocs
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$templateRoot = Join-Path $scriptRoot "template"
$templateDocs = Join-Path $templateRoot "docs"
$templateClaude = Join-Path $templateRoot ".claude"
$templateGithub = Join-Path $templateRoot ".github"
$templateClaudeMd = Join-Path $templateRoot "CLAUDE.md"
$mergeSettingsScript = Join-Path $scriptRoot "scripts\merge_settings.py"

if (-not (Test-Path $TargetPath)) {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}
$destination = (Resolve-Path -Path $TargetPath).Path

$secondBrainBeginMarker = "<!-- BEGIN SECOND BRAIN SYSTEM"
$secondBrainEndMarker = "<!-- END SECOND BRAIN SYSTEM -->"

if ($Uninstall) {
    Write-Host "=== Second Brain - Uninstall ===" -ForegroundColor Cyan
    Write-Host "Target: $destination"
    Write-Host ""

    # 1. Remove the marker-delimited block from CLAUDE.md; delete the
    #    file entirely if the block was its only content.
    $destClaudeMd = Join-Path $destination "CLAUDE.md"
    if (Test-Path $destClaudeMd) {
        $content = Get-Content -Path $destClaudeMd -Raw
        $beginIndex = $content.IndexOf($secondBrainBeginMarker)
        $endIndex = $content.IndexOf($secondBrainEndMarker)

        if ($beginIndex -ge 0 -and $endIndex -ge 0) {
            $endIndex += $secondBrainEndMarker.Length
            $remaining = $content.Substring(0, $beginIndex) + $content.Substring($endIndex)

            if ([string]::IsNullOrWhiteSpace($remaining)) {
                Remove-Item -Path $destClaudeMd -Force
                Write-Host "[REMOVED] CLAUDE.md (Second Brain block was its only content)" -ForegroundColor Green
            }
            else {
                Set-Content -Path $destClaudeMd -Value $remaining -NoNewline
                Write-Host "[UPDATED] Removed Second Brain block from CLAUDE.md" -ForegroundColor Green
            }
        }
        else {
            Write-Host "[SKIP] No Second Brain block found in CLAUDE.md" -ForegroundColor Yellow
        }
    }

    # 2. Remove the Stop-hook entry matching session_reminder.py from
    #    .claude/settings.json, leaving any other hooks/config untouched.
    $destSettings = Join-Path $destination ".claude\settings.json"
    if (Test-Path $destSettings) {
        $stopHookMarker = "session_reminder.py"
        try {
            $settings = Get-Content -Path $destSettings -Raw | ConvertFrom-Json
        }
        catch {
            $settings = $null
        }

        $hadMarkerHook = $false
        if ($settings -and $settings.hooks -and $settings.hooks.Stop) {
            foreach ($entry in $settings.hooks.Stop) {
                foreach ($hook in $entry.hooks) {
                    if ($hook.command -like "*$stopHookMarker*") { $hadMarkerHook = $true }
                }
            }
        }

        if ($hadMarkerHook) {
            $settings.hooks.Stop = @($settings.hooks.Stop | ForEach-Object {
                $entry = $_
                $keptHooks = @($entry.hooks | Where-Object { $_.command -notlike "*$stopHookMarker*" })
                if ($keptHooks.Count -gt 0) {
                    $entry.hooks = $keptHooks
                    $entry
                }
            })
            $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $destSettings
            Write-Host "[UPDATED] Removed Stop-hook entry from .claude/settings.json" -ForegroundColor Green
        }
        else {
            Write-Host "[SKIP] No Second Brain Stop-hook entry found in .claude/settings.json" -ForegroundColor Yellow
        }
    }

    # 3. Unset core.hooksPath only if it's still Second Brain's.
    $gitDir = Join-Path $destination ".git"
    $desiredHooksPath = ".claude/hooks"
    if (Test-Path $gitDir) {
        Push-Location $destination
        try {
            $currentHooksPath = (git config --get core.hooksPath 2>$null)
            if ($currentHooksPath -eq $desiredHooksPath) {
                git config --unset core.hooksPath
                Write-Host "[GIT] core.hooksPath unset" -ForegroundColor Green
            }
            else {
                Write-Host "[GIT] core.hooksPath is not Second Brain's, leaving untouched" -ForegroundColor Yellow
            }
        }
        finally {
            Pop-Location
        }
    }

    # 4. Delete system-owned files, then prune the directories left empty.
    $systemOwnedRelativePaths = @(
        ".claude\hooks\pre-commit",
        ".claude\hooks\session_reminder.py",
        ".claude\skills\update-second-brain\SKILL.md",
        ".claude\skills\onboard-second-brain\SKILL.md",
        ".claude\.second-brain-manifest.json",
        ".github\workflows\second-brain.yml"
    )
    foreach ($relativePath in $systemOwnedRelativePaths) {
        $path = Join-Path $destination $relativePath
        if (Test-Path $path) {
            Remove-Item -Path $path -Force
            Write-Host "[REMOVED] $relativePath" -ForegroundColor Green
        }
    }

    $dirsToPruneIfEmpty = @(
        ".claude\skills\update-second-brain",
        ".claude\skills\onboard-second-brain",
        ".claude\skills",
        ".claude\hooks",
        ".github\workflows",
        ".github"
    )
    foreach ($relativePath in $dirsToPruneIfEmpty) {
        $path = Join-Path $destination $relativePath
        if ((Test-Path $path) -and ((Get-ChildItem -Path $path -Force | Measure-Object).Count -eq 0)) {
            Remove-Item -Path $path -Force
        }
    }

    # 5. docs/ is user-owned content: left in place unless -PurgeDocs.
    if ($PurgeDocs) {
        $docsPath = Join-Path $destination "docs"
        if (Test-Path $docsPath) {
            Remove-Item -Path $docsPath -Recurse -Force
            Write-Host "[REMOVED] docs/ (-PurgeDocs)" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[KEPT] docs/ (pass -PurgeDocs to remove it too)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "=== Second Brain uninstalled from: $destination ===" -ForegroundColor Cyan
    return
}

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

function Get-Sha256Hash {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Sync-SystemOwnedFile {
    # System-owned files (the pre-commit hook, the Stop-hook reminder,
    # the skill) get upgraded in place on re-run instead of being
    # skipped forever like Copy-WithoutOverwrite does for user-owned
    # files -- but only when the destination copy is still exactly what
    # the previous install wrote, tracked via a SHA-256 recorded in
    # .claude/.second-brain-manifest.json. A file that was hand-edited
    # (or never tracked, e.g. upgrading from a pre-manifest install) is
    # left alone unless -Force is passed.
    param(
        [string]$RelativePath,
        [string]$TemplateFile,
        [string]$DestFile,
        [hashtable]$Manifest,
        [bool]$Force
    )

    $templateHash = Get-Sha256Hash -Path $TemplateFile

    if (-not (Test-Path $DestFile)) {
        $destDir = Split-Path -Parent $DestFile
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item -Path $TemplateFile -Destination $DestFile
        $Manifest[$RelativePath] = $templateHash
        Write-Host "  [COPY] $RelativePath" -ForegroundColor Green
        return
    }

    $destHash = Get-Sha256Hash -Path $DestFile

    if ($destHash -eq $templateHash) {
        $Manifest[$RelativePath] = $templateHash
        Write-Host "  [OK] $RelativePath (up to date)" -ForegroundColor DarkGray
        return
    }

    $recordedHash = $Manifest[$RelativePath]
    $unmodifiedSinceInstall = $recordedHash -and ($destHash -eq $recordedHash)

    if ($unmodifiedSinceInstall -or $Force) {
        Copy-Item -Path $TemplateFile -Destination $DestFile -Force
        $Manifest[$RelativePath] = $templateHash
        if ($unmodifiedSinceInstall) {
            Write-Host "  [UPDATED] $RelativePath" -ForegroundColor Green
        }
        else {
            Write-Host "  [UPDATED] $RelativePath (overwritten with -Force)" -ForegroundColor Green
        }
        return
    }

    if ($recordedHash) {
        Write-Host "  [SKIP] $RelativePath was modified locally since install -- not overwriting (re-run with -Force to overwrite anyway)." -ForegroundColor Yellow
    }
    else {
        Write-Host "  [SKIP] $RelativePath isn't tracked by a Second Brain manifest yet, can't tell if it was hand-modified (re-run with -Force to adopt and overwrite)." -ForegroundColor Yellow
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
    (Join-Path $destination ".claude\skills\onboard-second-brain"),
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

# 3. Copy the user-owned docs/ and optional .github/ trees, never
#    overwriting a file that already exists in the destination. The
#    system-owned .claude files (hooks, skill) are synced separately
#    below (step 3b) since those *are* meant to be upgraded on re-run.
Write-Host ""
Write-Host "Copying template/docs/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateDocs -Destination (Join-Path $destination "docs")

Write-Host ""
Write-Host "Copying template/.github/ (optional CI backstop) ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateGithub -Destination (Join-Path $destination ".github")

# 3b. System-owned .claude files (pre-commit hook, Stop-hook reminder,
#     skill) are tracked in a manifest and upgraded in place on re-run,
#     unlike the never-overwrite docs/.github copy above. settings.json
#     is merged separately below (step 4), never through this path.
Write-Host ""
Write-Host "Syncing system-owned .claude files ..." -ForegroundColor Cyan

$manifestPath = Join-Path $destination ".claude\.second-brain-manifest.json"
$manifest = @{}
if (Test-Path $manifestPath) {
    $rawManifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
    if ($rawManifest) {
        $rawManifest.PSObject.Properties | ForEach-Object { $manifest[$_.Name] = $_.Value }
    }
}

$systemOwnedFiles = @(
    ".claude\hooks\pre-commit",
    ".claude\skills\update-second-brain\SKILL.md",
    ".claude\skills\onboard-second-brain\SKILL.md"
)
if ($uvAvailable) {
    $systemOwnedFiles += ".claude\hooks\session_reminder.py"
}

foreach ($relativePath in $systemOwnedFiles) {
    Sync-SystemOwnedFile `
        -RelativePath $relativePath `
        -TemplateFile (Join-Path $templateRoot $relativePath) `
        -DestFile (Join-Path $destination $relativePath) `
        -Manifest $manifest `
        -Force:$Force
}

$manifestDir = Split-Path -Parent $manifestPath
if (-not (Test-Path $manifestDir)) {
    New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
}
$manifest | ConvertTo-Json | Set-Content -Path $manifestPath

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
        "updated" { Write-Host "  [UPDATED] Stop-hook command refreshed in existing .claude/settings.json" -ForegroundColor Green }
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

# 6. Hook up the git hook (only if the destination is a Git repository).
#    Never silently overwrite a hooksPath/hook that isn't ours.
Write-Host ""
$gitDir = Join-Path $destination ".git"
$desiredHooksPath = ".claude/hooks"

if (Test-Path $gitDir) {
    Push-Location $destination
    try {
        $currentHooksPath = (git config --get core.hooksPath 2>$null)
        $legacyHookFile = Join-Path $destination ".git\hooks\pre-commit"
        $hasLegacyHook = (Test-Path $legacyHookFile) -and
            -not ((Get-Content $legacyHookFile -Raw) -match "SECOND BRAIN SYSTEM")

        if ([string]::IsNullOrWhiteSpace($currentHooksPath)) {
            if ($hasLegacyHook -and -not $ForceHooksPath) {
                Write-Host "[GIT] Found an existing .git/hooks/pre-commit not managed by Second Brain." -ForegroundColor Yellow
                Write-Host "      Setting core.hooksPath would make Git ignore it. Merge it manually," -ForegroundColor Yellow
                Write-Host "      or re-run with -ForceHooksPath to proceed anyway." -ForegroundColor Yellow
            }
            else {
                git config core.hooksPath $desiredHooksPath
                Write-Host "[GIT] core.hooksPath set to $desiredHooksPath" -ForegroundColor Green
            }
        }
        elseif ($currentHooksPath -eq $desiredHooksPath) {
            Write-Host "[GIT] core.hooksPath already set to $desiredHooksPath" -ForegroundColor Green
        }
        elseif ($ForceHooksPath) {
            git config core.hooksPath $desiredHooksPath
            Write-Host "[GIT] Overwritten core.hooksPath -> $desiredHooksPath (-ForceHooksPath)" -ForegroundColor Green
        }
        else {
            Write-Host "[GIT] core.hooksPath is already set to '$currentHooksPath' (not Second Brain's)." -ForegroundColor Yellow
            Write-Host "      Leaving it untouched to avoid breaking husky/pre-commit-framework/etc." -ForegroundColor Yellow
            Write-Host "      Re-run with -ForceHooksPath to overwrite, or merge manually." -ForegroundColor Yellow
        }
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
Write-Host ""
Write-Host "Recommended next step: run the onboard-second-brain skill now," -ForegroundColor Cyan
Write-Host "before your first commit, so the one-time bootstrap cost is paid" -ForegroundColor Cyan
Write-Host "here instead of inside a rejected first commit." -ForegroundColor Cyan
