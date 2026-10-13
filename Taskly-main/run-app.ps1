param(
 [ValidateSet('customer','partner')][string]$Flavor = 'customer',
 [string]$Device,
 [ValidateSet('debug','profile','release')][string]$Mode = 'debug'
)
$ErrorActionPreference = 'Stop'
$adbPath = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Không tìm thấy Android SDK adb.' }
if (-not $Device) {
 $devices = @(& $adbPath devices | Where-Object { $_ -match '^([^\s]+)\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
 if ($devices.Count -ne 1) { throw 'Hãy chỉ định -Device khi có nhiều hoặc không có thiết bị.' }
 $Device = $devices[0]
}
& $adbPath -s $Device reverse tcp:8080 tcp:8080
if ($LASTEXITCODE -ne 0) { throw 'Không thiết lập được kết nối backend.' }
Push-Location $PSScriptRoot
try {
 & 'C:\flutter\bin\flutter.bat' run "--$Mode" --flavor $Flavor -d $Device --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
} finally { Pop-Location }
