param(
    [string]$InstallPath = "C:\CH\ch-panelArtMedidas",
    [string]$RepoUrl = "https://github.com/bjcbaigo/ch-panelArtMedidas.git",
    [string]$Branch = "master",
    [string]$TaskName = "CHEMES - Actualizar Panel Articulos",
    [int]$EveryMinutes = 60,
    [string]$SqlPassword,
    [string]$TaskUser = $env:USERNAME,
    [string]$TaskPassword
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

if ([string]::IsNullOrWhiteSpace($SqlPassword)) {
    throw "Debe indicar -SqlPassword para guardar CHEMES_SQL_AXOFT_PASSWORD en CENTRAL."
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    throw "Git no esta instalado o no esta en PATH. Instale Git for Windows en CENTRAL antes de continuar."
}

Write-Step "Preparando carpeta $InstallPath"
if (-not (Test-Path -LiteralPath $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
}

if (Test-Path -LiteralPath (Join-Path $InstallPath ".git")) {
    Write-Step "Repositorio existente: actualizando $Branch"
    Push-Location $InstallPath
    try {
        git fetch origin
        git checkout $Branch
        git pull --ff-only origin $Branch
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step "Clonando repositorio"
    $parent = Split-Path -Parent $InstallPath
    $leaf = Split-Path -Leaf $InstallPath
    Push-Location $parent
    try {
        if ((Get-ChildItem -LiteralPath $InstallPath -Force | Select-Object -First 1)) {
            throw "La carpeta $InstallPath existe pero no es un repo Git y no esta vacia."
        }
        git clone --branch $Branch $RepoUrl $leaf
    }
    finally {
        Pop-Location
    }
}

Write-Step "Guardando variable CHEMES_SQL_AXOFT_PASSWORD para el usuario actual"
[Environment]::SetEnvironmentVariable("CHEMES_SQL_AXOFT_PASSWORD", $SqlPassword, "User")
$env:CHEMES_SQL_AXOFT_PASSWORD = $SqlPassword

$updateScript = Join-Path $InstallPath "scripts\update_and_publish_panel.ps1"
if (-not (Test-Path -LiteralPath $updateScript)) {
    throw "No se encontro $updateScript."
}

Write-Step "Probando actualizador antes de crear la tarea"
Push-Location $InstallPath
try {
    & $updateScript
}
finally {
    Pop-Location
}

Write-Step "Creando tarea programada $TaskName cada $EveryMinutes minutos"
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$updateScript`""

$startAt = (Get-Date).Date.AddMinutes(1)
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At $startAt `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes)

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

if ([string]::IsNullOrWhiteSpace($TaskPassword)) {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Force | Out-Null
}
else {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $TaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force | Out-Null
}

Write-Step "Tarea creada. Ejecutando una prueba desde el Programador de tareas"
Start-ScheduledTask -TaskName $TaskName
Start-Sleep -Seconds 10
Get-ScheduledTaskInfo -TaskName $TaskName | Format-List LastRunTime,LastTaskResult,NextRunTime

Write-Step "Instalacion finalizada"
