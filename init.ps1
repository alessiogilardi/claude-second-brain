<#
.SYNOPSIS
    Inietta il sistema di documentazione "Second Brain" in un progetto di destinazione.

.DESCRIPTION
    Copia la struttura docs/ e .claude/ dal template verso la cartella di
    destinazione (default: cartella corrente), senza sovrascrivere file
    dell'utente gia' esistenti, e aggancia il git hook di pre-commit.

.PARAMETER TargetPath
    Cartella del progetto di destinazione. Default: "." (cartella corrente).

.EXAMPLE
    .\init.ps1
    .\init.ps1 ..\MioProgetto
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
        # Blocco gia' presente (re-run di init.ps1): lo sostituisce sul posto,
        # lasciando intatto il resto del file scritto dall'utente.
        $endIndex += $secondBrainEndMarker.Length
        $before = $ExistingContent.Substring(0, $beginIndex)
        $after = $ExistingContent.Substring($endIndex)
        return $before + $Block + $after
    }

    # Nessun blocco presente: lo aggiunge in coda senza toccare il contenuto esistente.
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
            Write-Host "  [SKIP] $relativePath (esiste gia')" -ForegroundColor Yellow
        }
        else {
            Copy-Item -Path $_.FullName -Destination $destFile
            Write-Host "  [COPY] $relativePath" -ForegroundColor Green
        }
    }
}

Write-Host "=== Second Brain - Inizializzazione ===" -ForegroundColor Cyan
Write-Host "Destinazione: $destination"
Write-Host ""

# 1. Crea le cartelle richieste nel progetto di destinazione
$foldersToCreate = @(
    (Join-Path $destination ".claude\hooks"),
    (Join-Path $destination ".claude\skills\update-second-brain"),
    (Join-Path $destination "docs\adr")
)

foreach ($folder in $foldersToCreate) {
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Write-Host "[CREATA] $folder"
    }
}

# 2. Copia ricorsiva di docs/ e .claude/ senza sovrascrivere file esistenti
Write-Host ""
Write-Host "Copio template/docs/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateDocs -Destination (Join-Path $destination "docs")

Write-Host ""
Write-Host "Copio template/.claude/ ..." -ForegroundColor Cyan
Copy-WithoutOverwrite -Source $templateClaude -Destination (Join-Path $destination ".claude")

# 3. Integrazione del blocco Second Brain in CLAUDE.md, senza sostituire
#    contenuto che l'utente ha gia' scritto nel file.
$destClaudeMd = Join-Path $destination "CLAUDE.md"
Write-Host ""

$templateBlock = Get-Content -Path $templateClaudeMd -Raw
$existingClaudeMd = if (Test-Path $destClaudeMd) { Get-Content -Path $destClaudeMd -Raw } else { "" }
$alreadyMerged = $existingClaudeMd.Contains($secondBrainBeginMarker)

$mergedClaudeMd = Merge-SecondBrainBlock -ExistingContent $existingClaudeMd -Block $templateBlock
Set-Content -Path $destClaudeMd -Value $mergedClaudeMd -NoNewline

if ([string]::IsNullOrWhiteSpace($existingClaudeMd)) {
    Write-Host "[CREATO] CLAUDE.md" -ForegroundColor Green
}
elseif ($alreadyMerged) {
    Write-Host "[AGGIORNATO] Blocco Second Brain in CLAUDE.md (gia' presente, sostituito)" -ForegroundColor Green
}
else {
    Write-Host "[INTEGRATO] Blocco Second Brain aggiunto in coda a CLAUDE.md esistente" -ForegroundColor Green
}

# 4. Aggancio del git hook (solo se la destinazione e' una repository Git)
Write-Host ""
$gitDir = Join-Path $destination ".git"
if (Test-Path $gitDir) {
    Push-Location $destination
    try {
        git config core.hooksPath .claude/hooks
        Write-Host "[GIT] core.hooksPath impostato su .claude/hooks" -ForegroundColor Green
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host "[GIT] Nessuna repository Git trovata in $destination, salto la configurazione degli hook." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Second Brain configurato con successo in: $destination ===" -ForegroundColor Cyan
