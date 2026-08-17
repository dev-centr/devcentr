#Requires -Version 7
<#
.SYNOPSIS
  Stage DevCentr Windows payload, then emit setup.exe, portable zip, optional MSI, and SHA256SUMS.
#>
param(
    [string]$Version = "",
    [string]$RepoRoot = "",
    [string]$ExePath = "",
    [string]$FreetypePath = "",
    [string]$LicensePath = "",
    [string]$NsiPath = "",
    [string]$MsiGenerator = "",
    [string]$DistDir = ""
)

$ErrorActionPreference = "Stop"

function Resolve-RepoRoot([string]$hint) {
    if ($hint) { return (Resolve-Path $hint).Path }
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Slant([string]$path) {
    return $path.Replace("\", "/")
}

function Require-File([string]$path, [string]$label) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "$label not found: $path"
    }
}

if (-not $Version) {
    if ($env:GITHUB_REF_TYPE -eq "tag") {
        $Version = ($env:GITHUB_REF_NAME -replace "^v", "")
    } elseif ($env:GITHUB_REF_NAME -match "^v") {
        $Version = ($env:GITHUB_REF_NAME -replace "^v", "")
    } else {
        $Version = "0.0.0-ci"
    }
}

$root = Resolve-RepoRoot $RepoRoot
if (-not $ExePath) { $ExePath = Join-Path $root "app\DevCentr.exe" }
if (-not $FreetypePath) { $FreetypePath = Join-Path $root "packaging\windows\redist\libfreetype-6.dll" }
if (-not $LicensePath) { $LicensePath = Join-Path $root "LICENSE" }
if (-not $NsiPath) { $NsiPath = Join-Path $root "packaging\windows\DevCentr.nsi" }
if (-not $DistDir) { $DistDir = Join-Path $root "dist" }
if (-not $MsiGenerator) {
    $candidate = Join-Path $root "msi-generator\msi-generator.exe"
    if (Test-Path -LiteralPath $candidate) { $MsiGenerator = $candidate }
}

Require-File $ExePath "DevCentr.exe"
Require-File $FreetypePath "libfreetype-6.dll"
Require-File $LicensePath "LICENSE"
Require-File $NsiPath "NSIS script"

$payload = Join-Path $DistDir "payload"
$portableFolder = Join-Path $DistDir "DevCentr-windows-x64"
$upload = Join-Path $DistDir "upload"
$setupName = "DevCentr-windows-x64-setup.exe"
$zipName = "DevCentr-windows-x64.zip"
$msiName = "DevCentr-windows-x64.msi"
$setupPath = Join-Path $DistDir $setupName
$zipPath = Join-Path $DistDir $zipName
$msiPath = Join-Path $DistDir $msiName

foreach ($dir in @($payload, $portableFolder, $upload, $DistDir)) {
    if (Test-Path -LiteralPath $dir) {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
New-Item -ItemType Directory -Force -Path $payload | Out-Null
New-Item -ItemType Directory -Force -Path $portableFolder | Out-Null
New-Item -ItemType Directory -Force -Path $upload | Out-Null

Copy-Item -LiteralPath $ExePath -Destination (Join-Path $payload "DevCentr.exe")
Copy-Item -LiteralPath $FreetypePath -Destination (Join-Path $payload "libfreetype-6.dll")
Copy-Item -LiteralPath $LicensePath -Destination (Join-Path $payload "LICENSE")

$portableReadme = Join-Path $root "packaging\windows\portable-readme.txt"
Copy-Item -Path (Join-Path $payload "*") -Destination $portableFolder
if (Test-Path -LiteralPath $portableReadme) {
    Copy-Item -LiteralPath $portableReadme -Destination (Join-Path $portableFolder "README.txt")
}

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
Compress-Archive -Path (Join-Path $portableFolder "*") -DestinationPath $zipPath -CompressionLevel Optimal

$makensis = @(
    "$env:ProgramFiles\NSIS\makensis.exe",
    "${env:ProgramFiles(x86)}\NSIS\makensis.exe"
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $makensis) {
    $cmd = Get-Command makensis -ErrorAction SilentlyContinue
    if ($cmd) { $makensis = $cmd.Source }
}
if (-not $makensis) {
    throw "makensis not found. Install NSIS (choco install nsis)."
}

$payloadArg = Slant ((Resolve-Path $payload).Path)
$outArg = Slant $setupPath
$nsiArg = (Resolve-Path $NsiPath).Path
& $makensis `
    "/DPAYLOAD_DIR=$payloadArg" `
    "/DOUT_FILE=$outArg" `
    "/DPRODUCT_VERSION=$Version" `
    $nsiArg
if ($LASTEXITCODE -ne 0) {
    throw "makensis failed with exit code $LASTEXITCODE"
}

$fourPart = (($Version -replace "[^0-9.]", ".") -split "\." | Where-Object { $_ -ne "" })
while ($fourPart.Count -lt 4) { $fourPart += "0" }
$msiVersion = ($fourPart | Select-Object -First 4) -join "."

if ($MsiGenerator -and (Test-Path -LiteralPath $MsiGenerator)) {
    $specPath = Join-Path $DistDir "devcentr-msi-spec.json"
    $exeUnix = Slant ((Join-Path $payload "DevCentr.exe"))
    $ftUnix = Slant ((Join-Path $payload "libfreetype-6.dll"))
    $spec = @"
{
  "name": "DevCentr",
  "manufacturer": "DevCentr.org",
  "productVersion": "$msiVersion",
  "productCode": "{C0DD4421-D590-471A-B708-0BCA094867CA}",
  "upgradeCode": "{82432E2B-9B94-4F7A-BF1A-CD6D9EEB81D1}",
  "rootFolder": {
    "id": "INSTALLDIR",
    "name": "DevCentr",
    "parentId": "",
    "subfolders": []
  },
  "components": [
    {
      "id": "MainComponent",
      "guid": "{D14A301E-7AC2-41AA-AB57-9C2796E98B7C}",
      "directoryId": "INSTALLDIR",
      "files": [
        { "id": "MainExe", "sourcePath": "$exeUnix", "targetName": "DevCentr.exe" },
        { "id": "FreeType", "sourcePath": "$ftUnix", "targetName": "libfreetype-6.dll" }
      ],
      "registryEntries": []
    }
  ],
  "features": [
    {
      "id": "Complete",
      "title": "DevCentr",
      "description": "Development Orchestration Suite",
      "level": 1,
      "componentIds": ["MainComponent"]
    }
  ]
}
"@
    Set-Content -LiteralPath $specPath -Value $spec -Encoding utf8
    $msiOut = Slant $msiPath
    & $MsiGenerator --type=msi --spec="$specPath" --output="$msiOut"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "msi-generator failed with exit code $LASTEXITCODE (setup.exe and zip still produced)"
        if (Test-Path -LiteralPath $msiPath) { Remove-Item -LiteralPath $msiPath -Force }
    }
} else {
    Write-Warning "msi-generator not found; skipping MSI"
}

$sums = Join-Path $DistDir "SHA256SUMS"
$releaseFiles = @($setupPath, $zipPath)
if (Test-Path -LiteralPath $msiPath) { $releaseFiles += $msiPath }
$lines = foreach ($file in $releaseFiles) {
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    "{0}  {1}" -f $hash, (Split-Path $file -Leaf)
}
Set-Content -LiteralPath $sums -Value $lines -Encoding ascii

Copy-Item -LiteralPath $setupPath -Destination (Join-Path $upload $setupName)
Copy-Item -LiteralPath $zipPath -Destination (Join-Path $upload $zipName)
Copy-Item -LiteralPath $sums -Destination (Join-Path $upload "SHA256SUMS")
if (Test-Path -LiteralPath $msiPath) {
    Copy-Item -LiteralPath $msiPath -Destination (Join-Path $upload $msiName)
}

Write-Host "Version $Version"
Get-ChildItem -LiteralPath $upload | Format-Table Name, Length -AutoSize
