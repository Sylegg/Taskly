$ErrorActionPreference = 'Stop'
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.10'
$settingsPath = Join-Path $PSScriptRoot '..\.env'
if (Test-Path -LiteralPath $settingsPath) {
    foreach ($line in Get-Content -LiteralPath $settingsPath) {
        if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
            if (-not [string]::IsNullOrWhiteSpace($Matches[2])) {
                [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
            }
        }
    }
}
$env:TASKLY_LOCAL_STORAGE_DIRECTORY = Join-Path $PSScriptRoot 'data/private-images'
Push-Location $PSScriptRoot
try {
    & .\gradlew.bat bootRun
} finally {
    Pop-Location
}
