#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('acceptance','4k','smoke')][string]$Suite = 'acceptance',
    [Parameter(Mandatory)][string]$Directory,
    [string]$GodotPath = $env:GODOT_EXE
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$allowed = [IO.Path]::GetFullPath((Join-Path $repo '.local/verification'))
$destination = [IO.Path]::GetFullPath($Directory)
if (-not $destination.StartsWith($allowed + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Use a new directory below .local/verification.' }
if (Test-Path -LiteralPath $destination) { throw 'Evidence directory must be new; earlier runs cannot be overwritten.' }
New-Item -ItemType Directory -Path $destination | Out-Null
$version = (Get-Content -LiteralPath (Join-Path $repo '.godot-version') -Raw).Trim()
if (-not $GodotPath) { $GodotPath = Join-Path $env:LOCALAPPDATA "Godot/$version/Godot_v${version}_win64_console.exe" }
$actualVersion = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or -not ([string]$actualVersion).StartsWith($version.Replace('-','.')+'.')) { throw 'Godot version differs from the pinned project version.' }
$gui = $GodotPath -replace '_console\.exe$','.exe'
if (-not (Test-Path -LiteralPath $gui)) { throw 'Matching standard Godot GUI executable is required.' }

# The thread owning the known game window is sampled, not an arbitrary first thread.
# https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PerformanceWindowThread {
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
'@
$os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
$processor = Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors
$hardware = @{ os=$os; cpu=$processor; physical_memory_bytes=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; gpu=@(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,DriverDate); captured_at=(Get-Date -Format o); suite=$Suite; engine=[string]$actualVersion; commit=(& git -C $repo rev-parse HEAD); runtime='Godot standard executable, production scene; not exported release'; gpu_clock_sampling='unavailable unless nvidia-smi is present' }
$hardware.working_tree_status = @(& git -C $repo status --porcelain)
$hardware.measurement_script_sha256 = (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'performance_validation.gd') -Algorithm SHA256).Hash
$hardware.collector_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
$projectGame = [IO.Path]::GetFullPath((Join-Path $repo '.local/builds/windows/Farm.exe'))
$hardware.existing_project_game_processes = @(Get-CimInstance Win32_Process -Filter "Name='Farm.exe'" | Where-Object ExecutablePath -eq $projectGame | Select-Object ProcessId,ParentProcessId,CreationDate,ExecutablePath,CommandLine)
$hardware.background_load_scope = 'Existing user-owned project game instances are observed and left untouched. Foreground belongs to the validation process during samples; whole-GPU telemetry includes other existing desktop loads. Other agents do not render or encode during this run.'

function Read-EvidenceJson([string]$Path) {
    # Allow the game's atomic status replacement while sampling; the collector
    # must not introduce Windows sharing failures into the instrumented process.
    $stream = [IO.FileStream]::new($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    $reader = [IO.StreamReader]::new($stream)
    try { $jsonText=$reader.ReadToEnd() } finally { $reader.Dispose() }
    return $jsonText | ConvertFrom-Json
}

$profile = Join-Path $destination 'profile'
foreach ($relative in @('roaming','local')) { New-Item -ItemType Directory -Path (Join-Path $profile $relative) -Force | Out-Null }
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $gui
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$info.WorkingDirectory = $repo
$info.Environment['APPDATA'] = Join-Path $profile 'roaming'
$info.Environment['LOCALAPPDATA'] = Join-Path $profile 'local'
foreach ($argument in @('--path',(Join-Path $repo 'Game'),'--script',(Join-Path $PSScriptRoot 'performance_validation.gd'),'--',('--output='+$destination),('--suite='+$Suite))) { $info.ArgumentList.Add($argument) }
$watch = [Diagnostics.Stopwatch]::new()
$process = $null
$writer = $null
$gpuProcess = $null
try {
$watch.Start()
$process = [Diagnostics.Process]::Start($info)
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
$gpuProcess = $null
$gpuOutput = $null
$gpuError = $null
$smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($smi) {
    $gpuInfo = [Diagnostics.ProcessStartInfo]::new()
    $gpuInfo.FileName = $smi.Source
    $gpuInfo.UseShellExecute = $false
    $gpuInfo.CreateNoWindow = $true
    $gpuInfo.RedirectStandardOutput = $true
    $gpuInfo.RedirectStandardError = $true
    foreach ($argument in @('--query-gpu=timestamp,index,name,driver_version,pstate,clocks.current.graphics,clocks.current.memory,utilization.gpu,utilization.memory,power.draw,memory.used','--format=csv,nounits','--loop=1','--id=0')) { $gpuInfo.ArgumentList.Add($argument) }
    $gpuProcess = [Diagnostics.Process]::Start($gpuInfo)
    $gpuOutput = $gpuProcess.StandardOutput.ReadToEndAsync()
    $gpuError = $gpuProcess.StandardError.ReadToEndAsync()
    $hardware.gpu_clock_sampling = 'nvidia-smi whole GPU index 0 at 1Hz; clocks, power, usage, not per-process GPU utilization; no power-policy changes'
}
$hardware | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destination 'hardware.json') -Encoding utf8
$writer = [IO.StreamWriter]::new((Join-Path $destination 'windows-process.csv'),$false,[Text.UTF8Encoding]::new($false))
$writer.WriteLine('elapsed_seconds,phase,working_set_bytes,private_bytes,process_cpu_total_ms,window_thread_id,window_thread_cpu_total_ms,window_thread_available,frames_drawn,foreground')
$peak = 0L
$samples = [Collections.Generic.List[object]]::new()
$threadId = 0
$readySeen = $null
$lastPhase = ''
$previousMissingReady = 0.0
$deadline = if ($Suite -eq 'acceptance') { 2700 } elseif ($Suite -eq '4k') { 1200 } else { 180 }
Write-Output "PERFORMANCE_STARTED suite=$Suite pid=$($process.Id) evidence=$destination"
    while (-not $process.HasExited) {
        $elapsed = $watch.Elapsed.TotalSeconds
        if ($elapsed -gt $deadline) { throw "Validation exceeded bounded duration $deadline seconds." }
        $process.Refresh()
        $phase = 'starting'
        $drawn = 0
        $foreground = $false
        $statusPath = Join-Path $destination 'status.json'
        if (Test-Path -LiteralPath $statusPath) {
            $status = Read-EvidenceJson $statusPath
            if ($status.pid -ne $process.Id) { throw 'Status belongs to an unexpected process.' }
            $phase = $status.phase
            $drawn = $status.frames_drawn
            $foreground = $status.foreground
        }
        if ($phase -ne $lastPhase) { Write-Output "PERFORMANCE_PHASE elapsed=$([Math]::Round($elapsed,1)) phase=$phase"; $lastPhase=$phase }
        $readyPath = Join-Path $destination 'ready.json'
        if ($null -eq $readySeen) {
            if (Test-Path -LiteralPath $readyPath) {
                $ready = Read-EvidenceJson $readyPath
                if ($ready.pid -ne $process.Id) { throw 'Readiness belongs to an unexpected process.' }
                $readySeen = $elapsed
                @{ lower_bound_seconds=$previousMissingReady; observed_upper_bound_seconds=$readySeen; method='Process.Start to observed production scene readiness, includes fixture setup and first rendered image readback'; target_seconds=10; target_met=($readySeen -le 10); release_executable=$false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $destination 'startup.json') -Encoding utf8
            } else { $previousMissingReady=$elapsed }
        }
        if ($threadId -eq 0 -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
            [uint32]$windowProcess = 0
            $threadId = [PerformanceWindowThread]::GetWindowThreadProcessId($process.MainWindowHandle,[ref]$windowProcess)
            if ($windowProcess -ne $process.Id) { throw 'Window belongs to an unexpected process.' }
        }
        $threadCpu = $null
        $threadAvailable = $false
        if ($threadId -ne 0) {
            $thread = $process.Threads | Where-Object Id -eq $threadId | Select-Object -First 1
            if ($thread) { $threadCpu=$thread.TotalProcessorTime.TotalMilliseconds; $threadAvailable=$true }
        }
        $working = $process.WorkingSet64
        $peak = [Math]::Max($peak,$working)
        $sample = [pscustomobject]@{ elapsed=$elapsed; phase=$phase; working_set=$working; process_cpu_ms=$process.TotalProcessorTime.TotalMilliseconds; thread_cpu_ms=$threadCpu; thread_available=$threadAvailable; frames=$drawn }
        $samples.Add($sample)
        $writer.WriteLine(([string]::Join(',',@($elapsed.ToString('F6',[Globalization.CultureInfo]::InvariantCulture),$phase,$working,$process.PrivateMemorySize64,$sample.process_cpu_ms,$threadId,$threadCpu,[int]$threadAvailable,$drawn,[int]$foreground))))
        $writer.Flush()
        Start-Sleep -Milliseconds $(if ($null -eq $readySeen) { 250 } else { 1000 })
    }
    $process.WaitForExit()
} finally {
    if ($writer) { $writer.Dispose() }
    if ($process -and -not $process.HasExited) {
        # Only the exact owned validation process, never a name-wide game shutdown.
        $process.Kill()
        $process.WaitForExit()
    }
    if ($stdout) { $stdout.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'stdout.log') -Encoding utf8 }
    if ($stderr) { $stderr.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'stderr.log') -Encoding utf8 }
    if ($gpuProcess) {
        if (-not $gpuProcess.HasExited) { $gpuProcess.Kill(); $gpuProcess.WaitForExit() }
        $gpuOutput.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'gpu-telemetry.csv') -Encoding utf8
        $gpuError.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $destination 'gpu-telemetry.stderr.log') -Encoding utf8
    }
}

# Matched one-minute bins expose both transient peaks and long-term retained growth.
# Do not convert a fitted slope into an automatic claim of leak-free behavior.
$bins = @($samples | Group-Object { [Math]::Floor($_.elapsed/60) } | ForEach-Object {
    $ordered = @($_.Group.working_set | Sort-Object)
    [pscustomobject]@{ minute=[int]$_.Name; samples=$ordered.Count; median_working_set_bytes=$ordered[[int][Math]::Floor($ordered.Count/2)]; min_working_set_bytes=$ordered[0]; max_working_set_bytes=$ordered[-1] }
})
$report = @{ exit_code=$process.ExitCode; pid=$process.Id; elapsed_seconds=$watch.Elapsed.TotalSeconds; peak_working_set_bytes=$peak; working_set_target_bytes=2147483648; working_set_target_met=($peak -le 2147483648); startup_upper_bound_seconds=$readySeen; thread_id=$threadId; thread_cpu_samples=@($samples | Where-Object thread_available).Count; sample_count=$samples.Count; memory_minute_bins=$bins; continuous_growth_assessment='Review phase-matched bins and raw CSV; no hidden slope cutoff'; measurement='Windows resident working set, cumulative process CPU and window-owning thread CPU. Thread CPU can be divided by drawn-frame deltas over each 1Hz interval; it is not a per-frame CPU percentile.' }
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destination 'windows-summary.json') -Encoding utf8
if ($process.ExitCode -ne 0) { throw "Validation process failed with exit code $($process.ExitCode)." }
if (-not (Test-Path -LiteralPath (Join-Path $destination 'results.json'))) { throw 'Validation ended without results.' }
if ((Get-Content -LiteralPath (Join-Path $destination 'results.json') -Raw | ConvertFrom-Json).failures.Count -ne 0) { throw 'Scene reported failed validation checks.' }
if ($report.thread_cpu_samples -eq 0) { throw 'No Windows window-thread CPU samples were acquired; the CPU evidence is incomplete.' }
if (Select-String -LiteralPath (Join-Path $destination 'stderr.log') -Pattern '(^|\s)(ERROR:|SCRIPT ERROR:|Leaked instance:|resources still in use)' -Quiet) { throw 'Validation stderr contains errors requiring review.' }
if ($Suite -eq 'acceptance' -and ($peak -gt 2147483648 -or $null -eq $readySeen -or $readySeen -gt 10)) { throw 'The startup or working-set target was not met; retain and review evidence.' }
Write-Output "PERFORMANCE_FINISHED suite=$Suite seconds=$([Math]::Round($watch.Elapsed.TotalSeconds,1)) peak_working_set=$peak evidence=$destination"
