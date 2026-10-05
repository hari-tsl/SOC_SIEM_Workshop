$ErrorActionPreference = 'Stop'
$cfg = Get-Content C:\SOC\settings.json -Raw | ConvertFrom-Json
$version = $cfg.elastic_version
$base = 'C:\Program Files\Winlogbeat'
if (-not (Test-Path "$base\winlogbeat.exe")) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-$version-windows-x86_64.zip"
    Invoke-WebRequest $url -OutFile C:\SOC\winlogbeat.zip -UseBasicParsing
    Invoke-WebRequest "$url.sha512" -OutFile C:\SOC\winlogbeat.sha512 -UseBasicParsing
    $expected = ((Get-Content C:\SOC\winlogbeat.sha512 -Raw).Trim() -split '\s+')[0]
    $actual = (Get-FileHash C:\SOC\winlogbeat.zip -Algorithm SHA512).Hash
    if ($actual -ne $expected) { throw 'Winlogbeat checksum mismatch' }
    Expand-Archive C:\SOC\winlogbeat.zip C:\SOC\unpacked -Force
    New-Item $base -ItemType Directory -Force | Out-Null
    Copy-Item "C:\SOC\unpacked\winlogbeat-$version-windows-x86_64\*" $base -Recurse -Force
}
Copy-Item C:\SOC\winlogbeat.yml "$base\winlogbeat.yml" -Force
Push-Location $base
try {
    & .\winlogbeat.exe test config -c .\winlogbeat.yml
    if ($LASTEXITCODE -ne 0) { throw 'Winlogbeat configuration invalid' }
    & .\winlogbeat.exe test output -c .\winlogbeat.yml
    if ($LASTEXITCODE -ne 0) { throw 'Logstash unreachable' }
    if (-not (Get-Service winlogbeat -ErrorAction SilentlyContinue)) { & .\install-service-winlogbeat.ps1 }
    Set-Service winlogbeat -StartupType Automatic
    Restart-Service winlogbeat
} finally { Pop-Location }

# Filebeat collects genuine IIS FTP W3C log files (Winlogbeat only reads event channels).
$fb = 'C:\Program Files\Filebeat'
if (-not (Test-Path "$fb\filebeat.exe")) {
    $url = "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$version-windows-x86_64.zip"
    Invoke-WebRequest $url -OutFile C:\SOC\filebeat.zip -UseBasicParsing
    Invoke-WebRequest "$url.sha512" -OutFile C:\SOC\filebeat.sha512 -UseBasicParsing
    $expected = ((Get-Content C:\SOC\filebeat.sha512 -Raw).Trim() -split '\s+')[0]
    if ((Get-FileHash C:\SOC\filebeat.zip -Algorithm SHA512).Hash -ne $expected) { throw 'Filebeat checksum mismatch' }
    Expand-Archive C:\SOC\filebeat.zip C:\SOC\unpacked -Force
    New-Item $fb -ItemType Directory -Force | Out-Null
    Copy-Item "C:\SOC\unpacked\filebeat-$version-windows-x86_64\*" $fb -Recurse -Force
}
Copy-Item C:\SOC\filebeat.yml "$fb\filebeat.yml" -Force
Push-Location $fb
try {
    & .\filebeat.exe test config -c .\filebeat.yml
    if ($LASTEXITCODE -ne 0) { throw 'Filebeat configuration invalid' }
    & .\filebeat.exe test output -c .\filebeat.yml
    if ($LASTEXITCODE -ne 0) { throw 'Filebeat output unreachable' }
    if (-not (Get-Service filebeat -ErrorAction SilentlyContinue)) { & .\install-service-filebeat.ps1 }
    Set-Service filebeat -StartupType Automatic
    Restart-Service filebeat
} finally { Pop-Location }
