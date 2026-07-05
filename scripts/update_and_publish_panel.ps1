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

function Invoke-LoggedNative {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $FilePath @Arguments 2>&1
    foreach ($line in $output) {
        Write-Log ([string]$line)
    }
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        throw "$FilePath $($Arguments -join ' ') finalizo con codigo $LASTEXITCODE."
    }
    return $output
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
    Invoke-LoggedNative git @("config", "user.name", "CHEMES Panel Bot")
    Invoke-LoggedNative git @("config", "user.email", "panel-articulos@chemes.local")

    $currentBranch = (& git rev-parse --abbrev-ref HEAD 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "No se pudo detectar la rama Git actual: $currentBranch"
    }
    $currentBranch = ([string]$currentBranch).Trim()
    if ($currentBranch -ne $Branch) {
        Write-Log "Cambiando rama de $currentBranch a $Branch"
        Invoke-LoggedNative git @("checkout", $Branch)
    }

    $preExistingChanges = git status --short -- data index.html
    if (-not [string]::IsNullOrWhiteSpace(($preExistingChanges -join ""))) {
        Write-Log "Hay cambios locales previos en data/index.html. Se guardan temporalmente antes de sincronizar:"
        $preExistingChanges | ForEach-Object { Write-Log $_ }
        Invoke-LoggedNative git @("stash", "push", "-m", "autostash-panel-before-refresh", "--", "data", "index.html")
    }

    Write-Log "Sincronizando origin/$Branch"
    Invoke-LoggedNative git @("fetch", "origin")
    Invoke-LoggedNative git @("pull", "--ff-only", "origin", $Branch)

    Write-Log "Ejecutando exportador SQL"
    $exportOutput = & $exportScript -OutputPath $outputPath 2>&1
    foreach ($line in $exportOutput) {
        Write-Log ([string]$line)
    }
    if ($LASTEXITCODE -ne 0) {
        throw "El exportador SQL finalizo con codigo $LASTEXITCODE."
    }

    $changes = git status --short -- data index.html
    if ([string]::IsNullOrWhiteSpace(($changes -join ""))) {
        Write-Log "Sin cambios para publicar"
        exit 0
    }

    Write-Log "Cambios detectados:"
    $changes | ForEach-Object { Write-Log $_ }

    Invoke-LoggedNative git @("add", "data", "index.html")

    $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm"
    $commitMessage = "$CommitMessagePrefix $generatedAt"
    Invoke-LoggedNative git @("commit", "-m", $commitMessage)

    Write-Log "Publicando en origin/$Branch"
    Invoke-LoggedNative git @("push", "origin", $Branch)
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
