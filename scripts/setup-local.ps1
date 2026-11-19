$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $repoRoot '.env'
if (Test-Path -LiteralPath $envPath) {
    Write-Host 'Existing .env preserved. Edit it locally if configuration needs to change.'
    exit 0
}
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$dbBytes = New-Object byte[] 24
$keyBytes = New-Object byte[] 32
$rng.GetBytes($dbBytes)
$rng.GetBytes($keyBytes)
$rng.Dispose()
$dbPassword = [BitConverter]::ToString($dbBytes).Replace('-', '').ToLowerInvariant()
$accessKey = [BitConverter]::ToString($keyBytes).Replace('-', '').ToLowerInvariant()
$envText = Get-Content -Raw (Join-Path $repoRoot '.env.example')
$envText = $envText.Replace('replace-with-generated-local-password', $dbPassword)
$envText = $envText.Replace('replace-with-a-random-secret-at-least-24-characters', $accessKey)
[System.IO.File]::WriteAllText($envPath, $envText)
Write-Host 'Created ignored .env with random local credentials. Add your Agora TEST configuration locally.'
