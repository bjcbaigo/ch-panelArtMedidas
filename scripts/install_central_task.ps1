param(
    [string]$InstallPath = "F:\Tarea\DashBoard_comercial\Articulos_Medidas",
    [string]$RepoUrl = "https://github.com/bjcbaigo/ch-panelArtMedidas.git",
    [string]$Branch = "master",
    [string]$TaskName = "CHEMES - Actualizar Panel Articulos",
    [int]$EveryMinutes = 60,
    [string]$SqlPassword,
    [string]$TaskUser = $env:USERNAME,
    [string]$TaskPassword,
    [switch]$SkipGitInstall,
    [string]$GitInstallerPath,
    [string]$GitInstallerUrl
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = @($machinePath, $userPath) -join ";"
}

function Get-GitCommand {
    Update-ProcessPath
    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCommand) {
        return $gitCommand
    }

    $knownPaths = @(
        "${env:ProgramFiles}\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
    )
    foreach ($path in $knownPaths) {
        if (Test-Path -LiteralPath $path) {
            return Get-Item -LiteralPath $path
        }
    }

    return $null
}

function Install-GitForWindows {
    if ($SkipGitInstall) {
        throw "Git no esta instalado y se indico -SkipGitInstall."
    }

    $gitCommand = Get-GitCommand
    if ($gitCommand) {
        Write-Step "Git ya esta instalado: $($gitCommand.Source)"
        return
    }

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Step "Git no esta instalado. Instalando Git for Windows con winget"
        winget install --id Git.Git --exact --source winget --scope machine --silent --accept-package-agreements --accept-source-agreements
        $gitCommand = Get-GitCommand
        if ($gitCommand) {
            Write-Step "Git instalado: $($gitCommand.Source)"
            return
        }
        Write-Step "winget termino, pero git todavia no aparece en PATH. Probando alternativas"
    }

    $installerToRun = $GitInstallerPath
    if ([string]::IsNullOrWhiteSpace($installerToRun) -and -not [string]::IsNullOrWhiteSpace($GitInstallerUrl)) {
        Write-Step "Descargando instalador de Git desde $GitInstallerUrl"
        $installerToRun = Join-Path $env:TEMP "GitForWindows.exe"
        Invoke-WebRequest -Uri $GitInstallerUrl -OutFile $installerToRun -UseBasicParsing
    }

    if ([string]::IsNullOrWhiteSpace($installerToRun)) {
        throw "No se pudo instalar Git automaticamente. Instale Git for Windows o pase -GitInstallerPath con el .exe."
    }

    if (-not (Test-Path -LiteralPath $installerToRun)) {
        throw "No existe el instalador indicado: $installerToRun"
    }

    Write-Step "Instalando Git for Windows desde $installerToRun"
    $process = Start-Process `
        -FilePath $installerToRun `
        -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/CLOSEAPPLICATIONS", "/RESTARTAPPLICATIONS" `
        -Wait `
        -PassThru

    if ($process.ExitCode -ne 0) {
        throw "El instalador de Git finalizo con codigo $($process.ExitCode)."
    }

    $gitCommand = Get-GitCommand
    if (-not $gitCommand) {
        throw "Git se instalo, pero no se encontro git.exe en PATH."
    }
    Write-Step "Git instalado: $($gitCommand.Source)"
}

if ([string]::IsNullOrWhiteSpace($SqlPassword)) {
    throw "Debe indicar -SqlPassword para guardar CHEMES_SQL_AXOFT_PASSWORD en CENTRAL."
}

Install-GitForWindows

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
    Write-Step "Inicializando repositorio en $InstallPath"
    Push-Location $InstallPath
    try {
        git init
        $remotes = git remote
        if ($remotes -notcontains "origin") {
            git remote add origin $RepoUrl
        }
        else {
            git remote set-url origin $RepoUrl
        }
        git fetch origin
        git checkout -B $Branch "origin/$Branch"
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
