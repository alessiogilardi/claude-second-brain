<#
.SYNOPSIS
    Injects the "Second Brain" documentation system into a destination project.

.DESCRIPTION
    Copies the docs/ and .claude/ structure from the template into the
    destination folder (default: current folder), without overwriting
    existing user files, and hooks up the pre-commit git hook.

.PARAMETER TargetPath
    Destination project folder. Default: "." (current folder).

.EXAMPLE
    .\init.ps1
    .\init.ps1 ..\MyProject
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetPath = "."
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
$templateRoot = Join-Path $scriptRoot "template"
$templateDocs = Join-Path $templateRoot "docs"
$templateClaude = Join-Path $templateRoot ".claude"
$templateClaudeMd = Join-Path $templateRoot "CLAUDE.md"

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
        # Block already present (init.ps1 re-run): replace it in place,
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
        [string]$Destination
    )

    Get-ChildItem -Path $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length).TrimStart('\', '/')
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

# 2. Recursively copy docs/ and .claude/ without overwriting existing files
Write-Host ""
Write-Host "Copying template/docs/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateDocs -Destination (Join-Path $destination "docs")

Write-Host ""
Write-Host "Copying template/.claude/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateClaude -Destination (Join-Path $destination ".claude")

# 3. Merge the Second Brain block into CLAUDE.md, without replacing
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

# 4. Hook up the git hook (only if the destination is a Git repository)
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
