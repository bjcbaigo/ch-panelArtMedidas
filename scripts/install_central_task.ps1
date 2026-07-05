param(
    [string]$InstallPath = "F:\Tarea\DashBoard_comercial\Articulos_Medidas",
    [string]$RepoUrl = "https://github.com/bjcbaigo/ch-panelArtMedidas.git",
    [string]$Branch = "master",
    [string]$TaskName = "CHEMES - Actualizar Panel Articulos",
    [int]$EveryMinutes = 60,
    [string]$SqlPassword,
    [string]$TaskUser,
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

function Convert-ToNativeArgument {
    param([string]$Value)

    if ($null -eq $Value) {
        return '""'
    }
    if ($Value -notmatch '[\s"]') {
        return $Value
    }
    $escaped = $Value -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Invoke-NativeStep {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = (($Arguments | ForEach-Object { Convert-ToNativeArgument $_ }) -join " ")
    $startInfo.WorkingDirectory = (Get-Location).Path
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $output = @()
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        $output += ($stdout -split "`r?`n" | Where-Object { $_ -ne "" })
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $output += ($stderr -split "`r?`n" | Where-Object { $_ -ne "" })
    }

    foreach ($line in $output) {
        Write-Host ([string]$line)
    }
    if ($process.ExitCode -ne 0) {
        throw "$FilePath $($Arguments -join ' ') finalizo con codigo $($process.ExitCode)."
    }
    return $output
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

function Resolve-WindowsAccountName {
    param([string]$AccountName)

    if ([string]::IsNullOrWhiteSpace($AccountName)) {
        return [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    $candidates = New-Object System.Collections.ArrayList
    [void]$candidates.Add($AccountName)
    if ($AccountName -notmatch '\\' -and $AccountName -notmatch '@') {
        if (-not [string]::IsNullOrWhiteSpace($env:USERDOMAIN)) {
            [void]$candidates.Add("$env:USERDOMAIN\$AccountName")
        }
        if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
            [void]$candidates.Add("$env:COMPUTERNAME\$AccountName")
        }
        [void]$candidates.Add(".\$AccountName")
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        try {
            $account = [System.Security.Principal.NTAccount]::new($candidate)
            [void]$account.Translate([System.Security.Principal.SecurityIdentifier])
            return $candidate
        }
        catch {
            continue
        }
    }

    throw "No se pudo resolver la cuenta '$AccountName'. Use el formato DOMINIO\usuario o $env:COMPUTERNAME\usuario. En CENTRAL puede ejecutar 'whoami' para ver el nombre exacto."
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
        Invoke-NativeStep git @("config", "user.name", "CHEMES Panel Bot")
        Invoke-NativeStep git @("config", "user.email", "panel-articulos@chemes.local")

        $localChanges = git status --short -- data index.html
        if (-not [string]::IsNullOrWhiteSpace(($localChanges -join ""))) {
            Write-Step "Guardando cambios locales previos de data/index.html antes de actualizar"
            $localChanges | ForEach-Object { Write-Host $_ }
            Invoke-NativeStep git @("stash", "push", "-m", "autostash-panel-install", "--", "data", "index.html")
        }

        Invoke-NativeStep git @("fetch", "origin")
        Invoke-NativeStep git @("checkout", $Branch)
        Invoke-NativeStep git @("pull", "--ff-only", "origin", $Branch)
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step "Inicializando repositorio en $InstallPath"
    Push-Location $InstallPath
    try {
        Invoke-NativeStep git @("init")
        $remotes = git remote
        if ($remotes -notcontains "origin") {
            Invoke-NativeStep git @("remote", "add", "origin", $RepoUrl)
        }
        else {
            Invoke-NativeStep git @("remote", "set-url", "origin", $RepoUrl)
        }
        Invoke-NativeStep git @("fetch", "origin")
        Invoke-NativeStep git @("checkout", "-B", $Branch, "origin/$Branch")
        Invoke-NativeStep git @("config", "user.name", "CHEMES Panel Bot")
        Invoke-NativeStep git @("config", "user.email", "panel-articulos@chemes.local")
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

$resolvedTaskUser = Resolve-WindowsAccountName $TaskUser
Write-Step "Usuario de tarea resuelto: $resolvedTaskUser"

if ([string]::IsNullOrWhiteSpace($TaskPassword)) {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Force `
        -ErrorAction Stop | Out-Null
}
else {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -User $resolvedTaskUser `
        -Password $TaskPassword `
        -RunLevel Highest `
        -Force `
        -ErrorAction Stop | Out-Null
}

Write-Step "Tarea creada. Ejecutando una prueba desde el Programador de tareas"
Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
$taskInfo = $null
for ($i = 0; $i -lt 12; $i++) {
    Start-Sleep -Seconds 10
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
    if ($taskInfo.LastTaskResult -ne 267009) {
        break
    }
    Write-Step "La tarea sigue en ejecucion. Esperando..."
}
$taskInfo | Format-List LastRunTime,LastTaskResult,NextRunTime
if ($taskInfo.LastTaskResult -ne 0 -and $taskInfo.LastTaskResult -ne 267009) {
    throw "La prueba de la tarea termino con LastTaskResult $($taskInfo.LastTaskResult). Revise logs\update-panel.log."
}

Write-Step "Instalacion finalizada"
