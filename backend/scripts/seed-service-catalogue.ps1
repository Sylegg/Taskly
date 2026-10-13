param(
    [string]$PostgresContainer = 'taskly-postgres-1',
    [string]$RedisContainer = 'taskly-redis-1'
)

$ErrorActionPreference = 'Stop'
$settings = @{}
$settingsPath = Join-Path $PSScriptRoot '..\..\.env'
foreach ($line in Get-Content -LiteralPath $settingsPath -Encoding UTF8) {
    if ($line -match '^([A-Z][A-Z0-9_]*)=(.*)$') {
        $settings[$Matches[1]] = $Matches[2].Trim().Trim('"').Trim("'")
    }
}
foreach ($key in @('POSTGRES_USER', 'POSTGRES_DB')) {
    if ([string]::IsNullOrWhiteSpace($settings[$key])) {
        throw "Missing $key in workspace .env."
    }
}

$previousEncoding = $OutputEncoding
try {
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $sqlPath = Join-Path $PSScriptRoot 'seed-service-catalogue.sql'
    Get-Content -LiteralPath $sqlPath -Raw -Encoding UTF8 |
        docker exec -i $PostgresContainer psql -X --set=ON_ERROR_STOP=1 --username $settings['POSTGRES_USER'] --dbname $settings['POSTGRES_DB'] --file -
    if ($LASTEXITCODE -ne 0) {
        throw 'Catalogue import failed; PostgreSQL rolled back the transaction.'
    }
} finally {
    $OutputEncoding = $previousEncoding
}

# Refresh only catalogue caches; keep login sessions and all other Redis data.
foreach ($pattern in @('publicCatalogue::*', 'publicService::*')) {
    $keys = @(docker exec $RedisContainer redis-cli --raw --scan --pattern $pattern)
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Data imported, but Redis could not be reached. Catalogue caches will expire according to CATALOGUE_CACHE_TTL.'
        break
    }
    foreach ($key in $keys) {
        if (-not [string]::IsNullOrWhiteSpace($key)) {
            $null = docker exec $RedisContainer redis-cli DEL $key
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Data imported, but catalogue cache refresh failed for $key."
            }
        }
    }
}
