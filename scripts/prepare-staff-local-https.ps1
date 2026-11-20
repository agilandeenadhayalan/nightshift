param([string]$OpenSsl = 'C:/Program Files/Git/usr/bin/openssl.exe')
$ErrorActionPreference = 'Stop'
# A private development CA, not an OS trust installation. Only its public
# certificate enters an ignored debug source overlay; no key enters the APK.
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$privateRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'NightShift/staff-local-https'))
$expectedParent = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'NightShift'))
if (![IO.Path]::GetDirectoryName($privateRoot).Equals($expectedParent, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unexpected private directory' }
if (!(Test-Path -LiteralPath $OpenSsl -PathType Leaf)) { throw 'OpenSSL executable is required' }
New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$owner = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl.SetOwner($owner)
foreach ($sid in @($owner, (New-Object Security.Principal.SecurityIdentifier 'S-1-5-18'))) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $privateRoot -AclObject $acl
$caKey = Join-Path $privateRoot 'ca-key.pem'
$ca = Join-Path $privateRoot 'ca.pem'
$key = Join-Path $privateRoot 'localhost-key.pem'
$cert = Join-Path $privateRoot 'localhost-cert.pem'
$files = @($caKey, $ca, $key, $cert)
$existing = @($files | Where-Object { Test-Path -LiteralPath $_ })
function Invoke-OpenSsl([string[]]$Arguments) {
    & $OpenSsl @Arguments 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Local TLS certificate operation failed' }
}
if ($existing.Count -eq 0) {
    Invoke-OpenSsl @('genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-out', $caKey)
    Invoke-OpenSsl @('req', '-x509', '-new', '-key', $caKey, '-sha256', '-days', '30', '-out', $ca, '-subj', '/CN=NightShift Private Debug CA', '-addext', 'basicConstraints=critical,CA:TRUE,pathlen:0', '-addext', 'keyUsage=critical,keyCertSign,cRLSign')
    Invoke-OpenSsl @('genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:prime256v1', '-out', $key)
    $csr = Join-Path $privateRoot 'localhost.csr'
    $extensions = Join-Path $privateRoot 'localhost-extensions.cnf'
    @('basicConstraints=critical,CA:FALSE', 'keyUsage=critical,digitalSignature', 'extendedKeyUsage=serverAuth', 'subjectAltName=IP:127.0.0.1,DNS:localhost') | Set-Content -LiteralPath $extensions -Encoding ascii
    Invoke-OpenSsl @('req', '-new', '-key', $key, '-out', $csr, '-subj', '/CN=127.0.0.1')
    Invoke-OpenSsl @('x509', '-req', '-in', $csr, '-CA', $ca, '-CAkey', $caKey, '-CAcreateserial', '-out', $cert, '-days', '7', '-sha256', '-extfile', $extensions)
} elseif ($existing.Count -ne $files.Count) { throw 'Incomplete local certificate set; inspect the private directory before regenerating' }
Invoke-OpenSsl @('verify', '-CAfile', $ca, '-verify_ip', '127.0.0.1', $cert)
Invoke-OpenSsl @('x509', '-in', $cert, '-checkend', '3600', '-noout')
$publicCa = Get-Content -LiteralPath $ca -Raw
if ($publicCa -notmatch '^-----BEGIN CERTIFICATE-----' -or $publicCa -match 'PRIVATE KEY') { throw 'Public CA expected' }
$overlay = Join-Path $workspace 'apps/mobile/android/app/src/staffLocalDebug'
New-Item -ItemType Directory -Path (Join-Path $overlay 'res/raw'), (Join-Path $overlay 'res/xml') -Force | Out-Null
Copy-Item -LiteralPath $ca -Destination (Join-Path $overlay 'res/raw/nightshift_staff_dev_ca.pem')
@'
<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools">
    <application android:usesCleartextTraffic="true" android:networkSecurityConfig="@xml/nightshift_staff_network_security" tools:replace="android:usesCleartextTraffic" />
    <uses-permission android:name="android.permission.INTERNET" />
</manifest>
'@ | Set-Content -LiteralPath (Join-Path $overlay 'AndroidManifest.xml') -Encoding utf8
@'
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors><certificates src="system" /></trust-anchors>
    </base-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <trust-anchors><certificates src="system" /><certificates src="@raw/nightshift_staff_dev_ca" /></trust-anchors>
    </domain-config>
</network-security-config>
'@ | Set-Content -LiteralPath (Join-Path $overlay 'res/xml/nightshift_staff_network_security.xml') -Encoding utf8
Write-Output 'Prepared private localhost HTTPS certificate and public debug-only trust overlay.'
Write-Output ('Certificate directory: ' + $privateRoot)
Write-Output 'No operating-system trust store was changed.'
