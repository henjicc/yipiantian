#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Directory)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$allowed=[IO.Path]::GetFullPath((Join-Path $repo '.local/verification'))
$destination=[IO.Path]::GetFullPath($Directory)
if (-not $destination.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $destination)) { throw 'Use a fresh isolated directory below .local/verification.' }
New-Item -ItemType Directory -Path $destination | Out-Null
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=(Get-Process -Id $PID).Path
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
foreach($argument in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'start-isolated-game.ps1'),'-Directory',$destination,'-Phase','startup')) { $info.ArgumentList.Add($argument) }
$watch=[Diagnostics.Stopwatch]::StartNew()
$launcher=[Diagnostics.Process]::Start($info)
$stdout=$launcher.StandardOutput.ReadToEndAsync()
$stderr=$launcher.StandardError.ReadToEndAsync()
$metadataPath=Join-Path $destination 'startup.process.json'
$game=$null
try {
    # Release logs may remain buffered until exit. First-save existence is only
    # a load-progress cue, not interactive readiness. Send actual input and capture
    # the resulting menu after this cue. The
    # screenshot must be inspected before claiming a successful startup response.
    while ($watch.Elapsed.TotalSeconds -lt 20) {
        if ($launcher.HasExited) { throw 'Isolated launcher exited before startup observation.' }
        if ($null -eq $game -and (Test-Path -LiteralPath $metadataPath)) {
            try { $metadata=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json } catch { Start-Sleep -Milliseconds 50; continue }
            $game=Get-Process -Id ([int]$metadata.pid)
            if ($game.Path -ne [IO.Path]::GetFullPath((Join-Path $repo '.local/builds/windows/Farm.exe'))) { throw 'Unexpected startup executable.' }
        }
        if ($game) {
            $game.Refresh()
            if ($game.MainWindowHandle -ne [IntPtr]::Zero -and (Test-Path -LiteralPath $metadata.save_file)) { break }
        }
        Start-Sleep -Milliseconds 50
    }
    if ($null -eq $game -or $watch.Elapsed.TotalSeconds -ge 20) { throw 'No loaded native farm window within startup observation limit.' }
    Start-Sleep -Milliseconds 500
    & (Join-Path $PSScriptRoot 'native-game-window.ps1') -ProcessId $game.Id -ProcessMetadata $metadataPath -Action capture -Output (Join-Path $destination 'startup-farm.png')
    & (Join-Path $PSScriptRoot 'native-game-window.ps1') -ProcessId $game.Id -ProcessMetadata $metadataPath -Action click -X 1192 -Y 110
    & (Join-Path $PSScriptRoot 'native-game-window.ps1') -ProcessId $game.Id -ProcessMetadata $metadataPath -Action capture -Output (Join-Path $destination 'startup-response.png')
    $game.Refresh()
    $age=([DateTime]::UtcNow-$game.StartTime.ToUniversalTime()).TotalSeconds
    @{ pid=$game.Id; executable=$game.Path; executable_sha256=(Get-FileHash -LiteralPath $game.Path -Algorithm SHA256).Hash; pack_sha256=(Get-FileHash -LiteralPath ([IO.Path]::ChangeExtension($game.Path,'.pck')) -Algorithm SHA256).Hash; commit=(& git -C $repo rev-parse HEAD); observed_response_upper_bound_seconds=$age; outer_launch_elapsed_seconds=$watch.Elapsed.TotalSeconds; target_seconds=10; within_time_target=($age-le 10); screenshot_requires_visual_confirmation='startup-response.png must show settings menu, not loading screen'; method='Unmodified release, isolated APPDATA; real mouse opens menu, then native GDI capture completes'; working_set_bytes=$game.WorkingSet64 } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'startup-probe.json')
    Write-Output "RELEASE_STARTUP_CAPTURED pid=$($game.Id) upper_bound_seconds=$([Math]::Round($age,3)) evidence=$destination"
    # Keep the existing isolated launcher and its exact process handle alive while
    # the caller performs the remaining native checks and closes the game normally.
    $launcher.WaitForExit()
    if ($launcher.ExitCode -ne 0) { throw 'Isolated release launcher reported failure.' }
} finally {
    if ($launcher.HasExited) {
        $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'launcher.stdout.log')
        $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'launcher.stderr.log')
    } else {
        Write-Warning 'Owned isolated game remains open; use its process metadata to close it normally.'
    }
}
