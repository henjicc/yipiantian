#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Directory,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Phase,
    [string]$GamePath,
    [ValidateRange(0, 15)][int]$Screen = 0,
    [switch]$EnableAudio
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$allowedRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.local/verification'))
$profileRoot = [IO.Path]::GetFullPath($Directory)
if (-not $profileRoot.StartsWith($allowedRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'An isolated directory below .local/verification is required.'
}
if (-not $GamePath) { $GamePath = Join-Path $repoRoot '.local/builds/windows/Farm.exe' }
$GamePath = (Resolve-Path -LiteralPath $GamePath).Path
New-Item -ItemType Directory -Path (Join-Path $profileRoot 'profile/roaming') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $profileRoot 'profile/local') -Force | Out-Null
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $GamePath
$info.WorkingDirectory = Split-Path -Parent $GamePath
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
foreach ($argument in @('--screen', [string]$Screen)) { $info.ArgumentList.Add($argument) }
if (-not $EnableAudio) {
    foreach ($argument in @('--audio-driver', 'Dummy')) { $info.ArgumentList.Add($argument) }
}
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.Environment['APPDATA'] = Join-Path $profileRoot 'profile/roaming'
$info.Environment['LOCALAPPDATA'] = Join-Path $profileRoot 'profile/local'
$info.ArgumentList.Add('--log-file')
$info.ArgumentList.Add((Join-Path $profileRoot ($Phase + '.godot.log')))
$process = [Diagnostics.Process]::Start($info)
$outputTask = $process.StandardOutput.ReadToEndAsync()
$errorTask = $process.StandardError.ReadToEndAsync()
$saveFile = Join-Path $profileRoot 'profile/roaming/Godot/app_userdata/我有一片田/farm-v4/farm.json'
$metadata = @{ phase=$Phase; pid=$process.Id; executable=$GamePath; save_file=$saveFile; started=(Get-Date -Format o); status='running' }
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $profileRoot ($Phase + '.process.json')) -Encoding utf8
Write-Output "ISOLATED_GAME_STARTED phase=$Phase pid=$($process.Id) evidence=$profileRoot"
# Interact with the native game window and close it normally. Keep this exact
# process handle alive so completion and log capture cannot be confused with another game.
$process.WaitForExit()
$outputTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $profileRoot ($Phase + '.stdout.log')) -Encoding utf8
$errorTask.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $profileRoot ($Phase + '.stderr.log')) -Encoding utf8
$metadata.status = 'exited'
$metadata.exit_code = $process.ExitCode
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $profileRoot ($Phase + '.process.json')) -Encoding utf8
if ($process.ExitCode -ne 0) { throw "Isolated game exited with code $($process.ExitCode)" }
if (-not (Test-Path -LiteralPath $saveFile)) { throw 'Expected isolated user:// save was not created.' }
Copy-Item -LiteralPath $saveFile -Destination (Join-Path $profileRoot ($Phase + '.saved.json'))
Write-Output "ISOLATED_GAME_CLOSED phase=$Phase pid=$($process.Id) exit=0 save=$saveFile"
