#Requires -Version 7.0
param(
 [Parameter(Mandatory)][string]$Directory,
 [string]$Executable = '',
 [ValidateRange(3,180)][int]$Seconds=180,
 [ValidateRange(1,3)][int]$Repeats=3,
 [ValidateRange(0,8)][double]$SoakHours=0,
 [ValidateSet('1080','1440','2160','native')][string]$Resolution='1080',
 [ValidateSet('low','standard','high')][string]$Quality='standard',
 [switch]$Native,
 [switch]$Capacity,
 [switch]$VisibleOnly,
 [switch]$NoCaptures,
 [ValidateRange(5,180)][int]$IdleSeconds=180
)
$ErrorActionPreference = 'Stop'
$auditRepo = Split-Path -Parent $PSScriptRoot
$auditRoot = [IO.Path]::GetFullPath($Directory)
$allowed = [IO.Path]::GetFullPath((Join-Path $auditRepo '.local/verification'))
if (-not $auditRoot.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {throw 'Evidence must be below .local/verification.'}
if (Test-Path -LiteralPath $auditRoot) {throw 'Use a fresh evidence directory.'}
$Probe=Join-Path $PSScriptRoot 'wallpaper_budget_test.gd'
$runtime=if ($Executable) {'Release template with isolated measurement entry'} else {'Pinned Godot executable; source diagnostics only'}
New-Item -ItemType Directory -Path $auditRoot -Force | Out-Null
# Release templates intentionally ignore --script. A normal scene entry uses
# the actual release runtime and packed production resources instead.
$probeScene=Join-Path $auditRoot 'probe.tscn'
$probePath=$Probe.Replace('\','/')
$sceneText='[gd_scene load_steps=2 format=3]' + "`n" + '[ext_resource type="Script" path="' + $probePath + '" id="1"]' + "`n" + '[node name="WallpaperBudget" type="Node"]' + "`n" + 'script = ExtResource("1")'
[IO.File]::WriteAllText($probeScene,$sceneText,[Text.UTF8Encoding]::new($false))
$auditEngine = if ($Executable) {(Get-Item -LiteralPath $Executable).FullName} else {Join-Path $env:LOCALAPPDATA 'Godot/4.7.2-stable/Godot_v4.7.2-stable_win64.exe'}
if ($Executable) {
 $manifest=Join-Path (Split-Path -Parent $auditEngine) 'benchmark.json'
 if (-not (Test-Path -LiteralPath $manifest)) {throw 'Release measurement requires the isolated benchmark export.'}
 Copy-Item -LiteralPath $manifest -Destination (Join-Path $auditRoot 'benchmark.json')
}
$hardware = @{commit=(& git -C $auditRepo rev-parse HEAD);cpu=(Get-CimInstance Win32_Processor | Select-Object Name,NumberOfLogicalProcessors);os=(Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version);gpu=(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion);physical_memory=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;power_plan=(& powercfg /GETACTIVESCHEME);runtime=$runtime;policy='Isolated farm, owned nonfocusing cover when Native requested';native=[bool]$Native;capacity=[bool]$Capacity;resolution=$Resolution;quality=$Quality;soak_hours=$SoakHours;started=(Get-Date -Format o);measurement_keepawake='Temporary display/system request covers both idle baselines and game; power plan unchanged'}
$hardware.no_captures=[bool]$NoCaptures
$hardware | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $auditRoot 'hardware.json') -Encoding utf8
if (-not ('WallpaperMeasurementPower' -as [type])) {
 Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
public static class WallpaperMeasurementPower {
 [DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint flags);
}
'@
}
$previousExecutionState=[WallpaperMeasurementPower]::SetThreadExecutionState([uint32]2147483651)
if ($previousExecutionState -eq 0) {throw 'Cannot keep measurement and idle baselines under matching display conditions.'}
$process=$null
$gpuProcess=$null
$csv=$null
try {
$smiCommand=Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($smiCommand) {
$smiInfo = [Diagnostics.ProcessStartInfo]::new()
$smiInfo.FileName = $smiCommand.Source
$smiInfo.UseShellExecute=$false
$smiInfo.CreateNoWindow=$true
$smiInfo.RedirectStandardOutput=$true
$smiInfo.RedirectStandardError=$true
foreach($arg in @('--query-gpu=timestamp,index,pstate,utilization.gpu,power.draw,memory.used,clocks.current.graphics','--format=csv,nounits','--loop=1','--id=0')) {$smiInfo.ArgumentList.Add($arg)}
$gpuProcess=[Diagnostics.Process]::Start($smiInfo)
$gpuStdout=$gpuProcess.StandardOutput.ReadToEndAsync()
$gpuStderr=$gpuProcess.StandardError.ReadToEndAsync()
} else {
 'Whole-board power unavailable: no supported NVIDIA telemetry. Use external/target-device measurement.' | Set-Content -LiteralPath (Join-Path $auditRoot 'power-unavailable.txt')
}
$idleStart=Get-Date -Format o
Start-Sleep -Seconds $IdleSeconds
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName=$auditEngine
$info.UseShellExecute=$false
$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true
$info.RedirectStandardError=$true
$info.WorkingDirectory=Split-Path -Parent $auditEngine
if ($Executable -and -not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $auditEngine) 'benchmark.json'))) {throw 'Release measurement requires the isolated benchmark export, not a normal package.'}
if (-not $Executable) {$info.ArgumentList.Add($probeScene)}
if (-not $Executable) {foreach($arg in @('--path',(Join-Path $auditRepo 'Game'))) {$info.ArgumentList.Add($arg)}}
foreach($arg in @('--screen','0','--audio-driver','Dummy','--log-file',(Join-Path $auditRoot 'engine.log'),'--',('--output='+$auditRoot),('--seconds='+$Seconds),('--repeats='+$Repeats),('--soak-hours='+$SoakHours.ToString([Globalization.CultureInfo]::InvariantCulture)),('--resolution='+$Resolution))) {$info.ArgumentList.Add($arg)}
if ($Native) {$info.ArgumentList.Add('--native')}
if ($Capacity) {$info.ArgumentList.Add('--capacity')}
$info.ArgumentList.Add('--quality='+$Quality)
if ($VisibleOnly) {$info.ArgumentList.Add('--visible-only')}
if ($NoCaptures) {$info.ArgumentList.Add('--no-captures')}
$info.Environment['APPDATA']=Join-Path $auditRoot 'profile/roaming'
$info.Environment['LOCALAPPDATA']=Join-Path $auditRoot 'profile/local'
New-Item -ItemType Directory -Path $info.Environment['APPDATA'],$info.Environment['LOCALAPPDATA'] -Force | Out-Null
$watch=[Diagnostics.Stopwatch]::StartNew()
$process=[Diagnostics.Process]::Start($info)
$process.Id | Set-Content -LiteralPath (Join-Path $auditRoot 'pid.txt') -Encoding ascii
$stdout=$process.StandardOutput.ReadToEndAsync()
$stderr=$process.StandardError.ReadToEndAsync()
$csv=[IO.StreamWriter]::new((Join-Path $auditRoot 'process.csv'),$false,[Text.UTF8Encoding]::new($false))
$csv.WriteLine('elapsed,phase,working_set,private_bytes,cpu_total_ms,handles,threads,gpu_dedicated,gpu_shared,game_cpu_total_ms,host_cpu_total_ms')
$lastPhase=''
$phase='startup'
$state=$null
$runStarted=Get-Date -Format o
try {
 while(-not $process.HasExited) {
  if($phase -eq 'startup' -and $watch.Elapsed.TotalSeconds -gt 120) {throw 'Probe did not reach ready; this is not valid performance evidence.'}
  if($watch.Elapsed.TotalSeconds -gt (4800+$SoakHours*3600)) {throw 'Audit exceeded bounded timeout.'}
  $process.Refresh()
  $phase='startup'
  try {$state=Get-Content -LiteralPath (Join-Path $auditRoot 'status.json') -Raw | ConvertFrom-Json; $phase=$state.phase} catch {}
  if ((Test-Path -LiteralPath (Join-Path $auditRoot 'engine.log')) -and (Select-String -LiteralPath (Join-Path $auditRoot 'engine.log') -Pattern 'SCRIPT ERROR:|^ERROR:' -Quiet)) {throw 'Runtime errors detected; measurement is invalid.'}
  if($phase -ne $lastPhase) {Write-Output "AUDIT_PHASE $phase elapsed=$([int]$watch.Elapsed.TotalSeconds)";$lastPhase=$phase}
  $dedicated=''
  $shared=''
  try {
   $counters=@((Get-Counter -Counter '\GPU Process Memory(*)\Dedicated Usage','\GPU Process Memory(*)\Shared Usage' -ErrorAction Stop).CounterSamples | Where-Object InstanceName -like "pid_$($process.Id)_*")
   if($counters.Count -gt 0) {
    $dedicated=[long](($counters | Where-Object Path -like '*\dedicated usage' | Measure-Object CookedValue -Sum).Sum)
    $shared=[long](($counters | Where-Object Path -like '*\shared usage' | Measure-Object CookedValue -Sum).Sum)
   }
  } catch {}
  if($process.HasExited) {break}
  $working=$process.WorkingSet64; $private=$process.PrivateMemorySize64; $cpu=$process.TotalProcessorTime.TotalMilliseconds
  $gameCpu=$cpu; $hostCpu=0
  if ($state.host -gt 0) {
   try {$hostProcess=[Diagnostics.Process]::GetProcessById([int]$state.host);$working+=$hostProcess.WorkingSet64;$private+=$hostProcess.PrivateMemorySize64;$hostCpu=$hostProcess.TotalProcessorTime.TotalMilliseconds;$cpu+=$hostCpu;$hostProcess.Dispose()} catch {}
  }
  $csv.WriteLine(([string]::Join(',',@($watch.Elapsed.TotalSeconds.ToString('F3',[Globalization.CultureInfo]::InvariantCulture),$phase,$working,$private,$cpu,$process.HandleCount,$process.Threads.Count,$dedicated,$shared,$gameCpu,$hostCpu))))
  $csv.Flush()
  Start-Sleep -Milliseconds 500
 }
 $process.WaitForExit()
} finally {
 $csv.Dispose()
 if(-not $process.HasExited) {$process.Kill();$process.WaitForExit()}
 $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $auditRoot 'stdout.log') -Encoding utf8
 $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $auditRoot 'stderr.log') -Encoding utf8
 $idleAfter=Get-Date -Format o
 if ($process.ExitCode -eq 0) {Start-Sleep -Seconds $IdleSeconds}
 if ($gpuProcess) {
  if(-not $gpuProcess.HasExited) {$gpuProcess.Kill();$gpuProcess.WaitForExit()}
  $gpuStdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $auditRoot 'whole-gpu.csv') -Encoding utf8
  $gpuStderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $auditRoot 'whole-gpu-errors.log') -Encoding utf8
 }
 @{before_started=$idleStart;run_started=$runStarted;after_started=$idleAfter;finished=(Get-Date -Format o);idle_seconds=$IdleSeconds} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'sample-times.json')
 @{exit_code=$process.ExitCode;seconds=$watch.Elapsed.TotalSeconds;pid=$process.Id} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $auditRoot 'completion.json') -Encoding utf8
}
Write-Output "AUDIT_EXIT $($process.ExitCode) seconds=$([int]$watch.Elapsed.TotalSeconds)"
if ($process.ExitCode -ne 0) {throw 'Benchmark process failed.'}
if (-not (Test-Path -LiteralPath (Join-Path $auditRoot 'results.json'))) {throw 'Benchmark exited without final evidence.'}
$result=Get-Content -LiteralPath (Join-Path $auditRoot 'results.json') -Raw | ConvertFrom-Json
if ($result.failures.Count -gt 0) {throw 'Benchmark functional checks failed.'}
} finally {
 # Also cover failures before the process-sampling loop was entered.
 if ($csv) {$csv.Dispose()}
 foreach ($owned in @($process,$gpuProcess)) {
  if ($owned) {
   if (-not $owned.HasExited) {$owned.Kill();$owned.WaitForExit()}
   $owned.Dispose()
  }
 }
 [void][WallpaperMeasurementPower]::SetThreadExecutionState($previousExecutionState)
}
