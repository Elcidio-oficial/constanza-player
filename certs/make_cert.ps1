# Gera/exporta o certificado de teste auto-assinado para empacotar o MSIX.
# Reexecutável: reaproveita o cert existente com o mesmo Subject se houver.
$ErrorActionPreference = 'Stop'

$subject = 'CN=Constanza, O=Constanza, C=BR'
$pfxPath = Join-Path $PSScriptRoot 'constanza.pfx'
$cerPath = Join-Path $PSScriptRoot 'constanza.cer'
$password = 'constanza123'

$existing = Get-ChildItem Cert:\CurrentUser\My |
  Where-Object { $_.Subject -eq $subject } |
  Sort-Object NotAfter -Descending |
  Select-Object -First 1

if ($null -ne $existing) {
  $cert = $existing
  Write-Output "Reusing existing cert: $($cert.Thumbprint)"
} else {
  $cert = New-SelfSignedCertificate `
    -Type Custom `
    -Subject $subject `
    -KeyUsage DigitalSignature `
    -FriendlyName 'Constanza Musicas Sideload' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
  Write-Output "Created new cert: $($cert.Thumbprint)"
}

$secure = ConvertTo-SecureString -String $password -Force -AsPlainText
$store = "Cert:\CurrentUser\My\$($cert.Thumbprint)"

Export-PfxCertificate -Cert $store -FilePath $pfxPath -Password $secure | Out-Null
Export-Certificate   -Cert $store -FilePath $cerPath | Out-Null

Write-Output "PFX: $pfxPath"
Write-Output "CER: $cerPath"
