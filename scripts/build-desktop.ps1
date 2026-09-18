#Requires -Version 7.0
[CmdletBinding()]
param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo '.local/builds/windows' }
$build = Join-Path $repo '.local/builds/desktop-native'
& cmake -S (Join-Path $repo 'native/desktop') -B $build -G 'Visual Studio 17 2022' -A x64
if ($LASTEXITCODE -ne 0) { throw 'Desktop host configuration failed. Install Visual Studio C++ Build Tools and Windows SDK.' }
& cmake --build $build --config Release
if ($LASTEXITCODE -ne 0) { throw 'Desktop host compilation failed.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$compiled = Join-Path $build 'Release/FarmDesktop.exe'
$destination = Join-Path $OutputDirectory 'FarmDesktop.exe'
if (-not (Test-Path -LiteralPath $destination) -or (Get-FileHash -LiteralPath $compiled).Hash -ne (Get-FileHash -LiteralPath $destination).Hash) {
    Copy-Item -LiteralPath $compiled -Destination $destination
}
Write-Output "DESKTOP_HOST_BUILT $OutputDirectory"
