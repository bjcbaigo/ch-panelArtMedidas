param(
    [string]$RepoPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Branch = "master",
    [string]$CommitMessagePrefix = "Actualiza datos del panel",
    [string]$LogPath = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "logs\update-panel.log")
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Write-Host $line

    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value $line
}

if ([string]::IsNullOrWhiteSpace($env:CHEMES_SQL_AXOFT_PASSWORD)) {
    throw "Falta CHEMES_SQL_AXOFT_PASSWORD. Definala como variable de entorno del usuario que ejecuta la tarea."
}

$repoFullPath = (Resolve-Path $RepoPath).Path
$exportScript = Join-Path $repoFullPath "scripts\export_articulos_panel.ps1"
$outputPath = Join-Path $repoFullPath "data\articulos-data.js"

Write-Log "Inicio de actualizacion en $repoFullPath"

Push-Location $repoFullPath
try {
    $currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
    if ($currentBranch -ne $Branch) {
        Write-Log "Cambiando rama de $currentBranch a $Branch"
        git checkout $Branch | ForEach-Object { Write-Log $_ }
    }

    Write-Log "Ejecutando exportador SQL"
    $exportOutput = & $exportScript -OutputPath $outputPath 2>&1
    foreach ($line in $exportOutput) {
        Write-Log ([string]$line)
    }

    $changes = git status --short -- data index.html
    if ([string]::IsNullOrWhiteSpace(($changes -join ""))) {
        Write-Log "Sin cambios para publicar"
        exit 0
    }

    Write-Log "Cambios detectados:"
    $changes | ForEach-Object { Write-Log $_ }

    git add data index.html | ForEach-Object { Write-Log $_ }

    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMessage = "$CommitMessagePrefix $generatedAt"
    git commit -m $commitMessage | ForEach-Object { Write-Log $_ }

    Write-Log "Publicando en origin/$Branch"
    git push origin $Branch | ForEach-Object { Write-Log $_ }
    Write-Log "Actualizacion publicada correctamente"
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Log $_.ScriptStackTrace
    }
    exit 1
}
finally {
    Pop-Location
}
