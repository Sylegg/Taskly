$ErrorActionPreference = 'Stop'

# Load local backend settings without displaying credentials.
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

$senderEmail = $env:MAIL_USERNAME
if ([string]::IsNullOrWhiteSpace($senderEmail)) {
    $senderEmail = Read-Host 'Gmail gui OTP (vi du taskly@gmail.com)'
}
if ($senderEmail -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
    throw 'Dia chi email khong hop le.'
}
$appSecret = $null
$secretPointer = [IntPtr]::Zero
try {
    if ([string]::IsNullOrWhiteSpace($env:MAIL_PASSWORD)) {
        $appSecret = Read-Host 'Gmail App Password (nhap an)' -AsSecureString
        $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($appSecret)
        $env:MAIL_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
    }
    $env:MAIL_PASSWORD = $env:MAIL_PASSWORD.Replace(' ', '')
    if ([string]::IsNullOrWhiteSpace($env:MAIL_PASSWORD)) { throw 'Can nhap App Password.' }
    $env:MAIL_HOST = 'smtp.gmail.com'
    $env:MAIL_PORT = '587'
    $env:MAIL_USERNAME = $senderEmail
    $env:MAIL_FROM = $senderEmail
    $env:MAIL_SMTP_AUTH = 'true'
    $env:MAIL_STARTTLS_ENABLE = 'true'
    $env:MAIL_STARTTLS_REQUIRED = 'true'
    Push-Location $PSScriptRoot
    try {
        & .\gradlew.bat bootRun
        if ($LASTEXITCODE -ne 0) { throw 'Backend khoi dong khong thanh cong.' }
    } finally { Pop-Location }
} finally {
    if ($secretPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer)
    }
    Remove-Item Env:\MAIL_PASSWORD -ErrorAction SilentlyContinue
    if ($null -ne $appSecret) { $appSecret.Dispose() }
}
