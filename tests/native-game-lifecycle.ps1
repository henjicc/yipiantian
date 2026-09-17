#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProcessMetadata,
    [ValidateSet('info','minimize','restore','resize','move-monitor','minimum-probe','escape','pause')][string]$Action='info',
    [ValidateRange(960,3840)][int]$Width=1920,
    [ValidateRange(600,2160)][int]$Height=1080,
    [ValidateRange(0,8)][int]$Monitor=0,
    [ValidateRange(1,30)][int]$PauseSeconds=15
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$allowed=[IO.Path]::GetFullPath((Join-Path $repo '.local/verification'))
$metadataPath=[IO.Path]::GetFullPath($ProcessMetadata)
if (-not $metadataPath.StartsWith($allowed+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Use start-isolated-game process metadata below .local/verification.' }
$metadata=Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$expected=[IO.Path]::GetFullPath((Join-Path $repo '.local/builds/windows/Farm.exe'))
if ($metadata.status -ne 'running' -or $metadata.executable -ne $expected) { throw 'Metadata must identify a running isolated Farm.exe.' }
$target=Get-Process -Id ([int]$metadata.pid)
if ($target.Path -ne $expected -or [Math]::Abs(($target.StartTime.ToUniversalTime()-([DateTimeOffset]::Parse($metadata.started)).UtcDateTime).TotalSeconds) -gt 3) { throw 'Process identity/start time no longer matches the owned test launch.' }

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FarmLifecycleCheck {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h,out Rect rect);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect rect);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll",EntryPoint="GetWindowLongW")] public static extern int GetWindowStyle(IntPtr h,int index);
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int command);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint processId);
 [DllImport("user32.dll")] public static extern void keybd_event(byte key,byte scan,uint flags,UIntPtr extra);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int width,int height,uint flags);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr OpenThread(uint rights,bool inherit,uint threadId);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern uint SuspendThread(IntPtr thread);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern uint ResumeThread(IntPtr thread);
 [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr handle);
}
'@
[FarmLifecycleCheck]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
$window=$target.MainWindowHandle
if ($window -eq [IntPtr]::Zero) { throw 'Owned process has no native window.' }
$pauseEvidence=$null
switch ($Action) {
    'minimize' { [FarmLifecycleCheck]::ShowWindowAsync($window,6) | Out-Null }
    'restore' {
        [FarmLifecycleCheck]::ShowWindowAsync($window,9) | Out-Null
        [FarmLifecycleCheck]::SetForegroundWindow($window) | Out-Null
    }
    'resize' {
        $client=[FarmLifecycleCheck+Rect]::new()
        $outer=[FarmLifecycleCheck+Rect]::new()
        if (-not [FarmLifecycleCheck]::GetClientRect($window,[ref]$client) -or -not [FarmLifecycleCheck]::GetWindowRect($window,[ref]$outer)) { throw 'Cannot measure window borders.' }
        $borderWidth=($outer.R-$outer.L)-($client.R-$client.L)
        $borderHeight=($outer.B-$outer.T)-($client.B-$client.T)
        if (-not [FarmLifecycleCheck]::SetWindowPos($window,[IntPtr]::Zero,0,0,$Width+$borderWidth,$Height+$borderHeight,0x0016)) { throw 'Native window resize failed.' }
    }
    'move-monitor' {
        $screens=[Windows.Forms.Screen]::AllScreens
        if ($Monitor -ge $screens.Count) { throw 'Requested physical monitor is unavailable.' }
        $bounds=$screens[$Monitor].WorkingArea
        if (-not [FarmLifecycleCheck]::SetWindowPos($window,[IntPtr]::Zero,$bounds.X+48,$bounds.Y+48,0,0,0x0015)) { throw 'Native monitor move failed.' }
    }
    'minimum-probe' {
        if (-not [FarmLifecycleCheck]::SetWindowPos($window,[IntPtr]::Zero,0,0,640,360,0x0016)) { throw 'Minimum-size probe failed.' }
    }
    'escape' {
        [uint32]$foregroundProcess=0
        [FarmLifecycleCheck]::GetWindowThreadProcessId([FarmLifecycleCheck]::GetForegroundWindow(),[ref]$foregroundProcess) | Out-Null
        if ($foregroundProcess -ne $target.Id) { throw 'Owned game/popup must already be foreground before Escape.' }
        [FarmLifecycleCheck]::keybd_event(0x1B,0,0,[UIntPtr]::Zero)
        Start-Sleep -Milliseconds 70
        [FarmLifecycleCheck]::keybd_event(0x1B,0,2,[UIntPtr]::Zero)
    }
    'pause' {
        # Debugger-style scheduling suspension of this isolated process only.
        # No machine sleep, clock change, registry write or production-data access.
        $handles=[Collections.Generic.List[object]]::new()
        $timer=[Diagnostics.Stopwatch]::StartNew()
        try {
            foreach ($thread in $target.Threads) {
                $handle=[FarmLifecycleCheck]::OpenThread(0x0002,$false,[uint32]$thread.Id)
                if ($handle -eq [IntPtr]::Zero) { throw "Cannot open owned thread $($thread.Id)." }
                $entry=@{ handle=$handle; id=$thread.Id; suspended=$false; previous_count=0 }
                $handles.Add($entry)
                $previous=[FarmLifecycleCheck]::SuspendThread($handle)
                if ($previous -eq [uint32]::MaxValue) { throw "Cannot suspend owned thread $($thread.Id)." }
                $entry.suspended=$true
                $entry.previous_count=$previous
                if ($previous -ne 0) { throw 'Thread was already suspended; do not change another suspension owner.' }
            }
            Start-Sleep -Seconds $PauseSeconds
        } finally {
            $resumeFailures=[Collections.Generic.List[int]]::new()
            foreach ($entry in $handles) {
                if ($entry.suspended -and [FarmLifecycleCheck]::ResumeThread($entry.handle) -eq [uint32]::MaxValue) { $resumeFailures.Add($entry.id) }
                [FarmLifecycleCheck]::CloseHandle($entry.handle) | Out-Null
            }
            if ($resumeFailures.Count) { throw "Could not resume owned thread handles: $($resumeFailures -join ',')" }
        }
        $pauseEvidence=@{ requested_seconds=$PauseSeconds; elapsed_seconds=$timer.Elapsed.TotalSeconds; suspended_threads=$handles.Count; all_owned_suspensions_resumed=$true; actual_os_sleep=$false }
    }
}
Start-Sleep -Milliseconds 500
$target.Refresh()
$clientNow=[FarmLifecycleCheck+Rect]::new()
$outerNow=[FarmLifecycleCheck+Rect]::new()
if (-not [FarmLifecycleCheck]::GetClientRect($window,[ref]$clientNow) -or -not [FarmLifecycleCheck]::GetWindowRect($window,[ref]$outerNow)) { throw 'Window disappeared before result inspection.' }
if ($Action -eq 'resize' -and (($clientNow.R-$clientNow.L) -ne $Width -or ($clientNow.B-$clientNow.T) -ne $Height)) { throw 'Requested client size was not applied.' }
if ($Action -eq 'minimum-probe' -and (($clientNow.R-$clientNow.L) -ne 960 -or ($clientNow.B-$clientNow.T) -ne 600)) { throw 'Native window did not clamp to 960x600 minimum.' }
if ($Action -eq 'minimize' -and -not [FarmLifecycleCheck]::IsIconic($window)) { throw 'Window did not minimize.' }
$monitorInfo=@()
$screens=[Windows.Forms.Screen]::AllScreens
for ($index=0; $index -lt $screens.Count; $index++) { $bounds=$screens[$index].Bounds; $monitorInfo+=@{ index=$index; name=$screens[$index].DeviceName; primary=$screens[$index].Primary; bounds=@($bounds.X,$bounds.Y,$bounds.Width,$bounds.Height) } }
@{ pid=$target.Id; action=$Action; timestamp=(Get-Date -Format o); client_size=@(($clientNow.R-$clientNow.L),($clientNow.B-$clientNow.T)); outer_rect=@($outerNow.L,$outerNow.T,$outerNow.R,$outerNow.B); dpi=[FarmLifecycleCheck]::GetDpiForWindow($window); native_caption=(([FarmLifecycleCheck]::GetWindowStyle($window,-16) -band 0x00C00000) -eq 0x00C00000); monitors=$monitorInfo; minimized=[FarmLifecycleCheck]::IsIconic($window); responding=$target.Responding; working_set_bytes=$target.WorkingSet64; pause=$pauseEvidence } | ConvertTo-Json -Depth 6
