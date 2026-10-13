param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$backendRoot = Split-Path $PSScriptRoot -Parent
$workspaceRoot = Split-Path $backendRoot -Parent
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.10'
$settingsPath = Join-Path $workspaceRoot '.env'
if (Test-Path -LiteralPath $settingsPath) {
    foreach ($line in Get-Content -LiteralPath $settingsPath) {
        if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$' -and -not [string]::IsNullOrWhiteSpace($Matches[2])) {
            [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
        }
    }
}
if (-not $SkipBuild) {
    $gradleLaunch = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE '.gradle\wrapper\dists\gradle-9.7.1-bin') -Filter gradle.bat -Recurse |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not $gradleLaunch) { throw 'Gradle 9.7.1 is not installed.' }
    Push-Location $backendRoot
    try {
        & $gradleLaunch bootJar --offline
        if ($LASTEXITCODE -ne 0) { throw 'Backend build failed; current service was kept running.' }
    } finally { Pop-Location }
}
$sourceJar = Join-Path $backendRoot 'build\libs\taskly-backend-0.1.0-SNAPSHOT.jar'
if (-not (Test-Path -LiteralPath $sourceJar)) { throw 'Backend JAR is missing.' }
$runtimeRoot = Join-Path $backendRoot '.runtime'
New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
$runtimeJar = Join-Path $runtimeRoot ('taskly-backend-' + [guid]::NewGuid().ToString('N') + '.jar')
Copy-Item -LiteralPath $sourceJar -Destination $runtimeJar
# Stop only the TaskLy backend currently owning this project's API port.
$listeners = @(Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue)
foreach ($processId in ($listeners.OwningProcess | Select-Object -Unique)) {
    $serviceProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$processId"
    if ($serviceProcess.Name -ne 'java.exe' -or $serviceProcess.CommandLine -notmatch 'taskly-backend.*\.jar') {
        throw 'Port 8080 belongs to a different service; it was not stopped.'
    }
    if ($serviceProcess.CommandLine -notlike "*$workspaceRoot*" -and
        $serviceProcess.CommandLine -notmatch '-jar\s+backend\\build\\libs\\taskly-backend') {
        throw 'Backend process is not identified as this workspace.'
    }
    Stop-Process -Id $processId -Force
}
$service = Start-Process -FilePath (Join-Path $env:JAVA_HOME 'bin\java.exe') -ArgumentList @('-jar', ('"' + $runtimeJar + '"')) `
    -WorkingDirectory $workspaceRoot -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $backendRoot 'recruitment-runtime.out.log') `
    -RedirectStandardError (Join-Path $backendRoot 'recruitment-runtime.err.log')
Write-Output "Started TaskLy backend PID $($service.Id) using immutable runtime JAR."
