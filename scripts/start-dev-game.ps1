#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][int]$Screen,
    [string[]]$NativeArgs = @()
)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath($ProjectPath).TrimEnd('\', '/')
$gui = $GodotPath -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $gui)) { throw "Godot GUI executable missing: $gui" }

# Parse Windows quoting exactly; a substring of another project's path is not ownership.
if (-not ('FarmDevCommandLine' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class FarmDevCommandLine {
    [DllImport("shell32.dll", SetLastError=true)] static extern IntPtr CommandLineToArgvW([MarshalAs(UnmanagedType.LPWStr)] string line, out int count);
    [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr memory);
    public static string[] Split(string line) {
        int count; IntPtr memory = CommandLineToArgvW(line, out count);
        if (memory == IntPtr.Zero) throw new System.ComponentModel.Win32Exception();
        try {
            var result = new string[count];
            for (int i=0;i<count;i++) result[i]=Marshal.PtrToStringUni(Marshal.ReadIntPtr(memory,i*IntPtr.Size));
            return result;
        } finally { LocalFree(memory); }
    }
}
'@
}
foreach ($candidate in Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%win64%.exe'") {
    if (-not $candidate.CommandLine) { continue }
    $arguments = [FarmDevCommandLine]::Split($candidate.CommandLine)
    # Keep editors, test tools and recordings. Only restart interactive game instances.
    if (@($arguments | Where-Object { $_ -in @('--editor', '-e', '--project-manager', '-p', '--headless', '--script', '-s', '--write-movie', '--check-only') }).Count) { continue }
    $pathIndex = [Array]::IndexOf($arguments, '--path')
    if ($pathIndex -lt 0 -or $pathIndex + 1 -ge $arguments.Count) { continue }
    $candidatePath = $arguments[$pathIndex + 1]
    if (-not [IO.Path]::IsPathFullyQualified($candidatePath)) { continue }
    if ([IO.Path]::GetFullPath($candidatePath).TrimEnd('\', '/') -ine $project) { continue }
    $previous = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue
    if (-not $previous) { continue }
    # Recheck creation time before acting: enumeration must not kill a reused PID.
    if ([Math]::Abs(($previous.StartTime - $candidate.CreationDate).TotalSeconds) -gt 1) { continue }
    [void]$previous.CloseMainWindow()
    if (-not $previous.WaitForExit(4000)) {
        $stillRunning = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue
        if ($stillRunning -and $stillRunning.StartTime -eq $previous.StartTime) {
            Stop-Process -InputObject $stillRunning -Force
            [void]$stillRunning.WaitForExit(4000)
        }
    }
    Write-Output "Closed this project's development game (PID $($candidate.ProcessId))."
}

# Rebuild only after the previous game has released its bundled desktop host.
& (Join-Path $PSScriptRoot 'build-desktop.ps1')
$output = Join-Path (Split-Path -Parent $project) '.local/dev-preview'
New-Item -ItemType Directory -Path $output -Force | Out-Null
$log = Join-Path $output ('game-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
$launchArgs = [Collections.Generic.List[string]]::new()
$launchArgs.AddRange([string[]]$NativeArgs)
if ($launchArgs -notcontains '--log-file') {
    $separator = $launchArgs.IndexOf('--')
    if ($separator -lt 0) { $separator = $launchArgs.Count }
    $launchArgs.InsertRange($separator, [string[]]@('--log-file', $log))
}
else { $log = $launchArgs[$launchArgs.IndexOf('--log-file') + 1] }
if ($launchArgs -notcontains '--') { $launchArgs.Add('--') }
$launchArgs.Add('--dev-preview')
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $gui
$info.WorkingDirectory = Split-Path -Parent $project
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
foreach ($argument in $launchArgs) { $info.ArgumentList.Add($argument) }
$game = [Diagnostics.Process]::Start($info)
$deadline = [DateTime]::UtcNow.AddSeconds(45)
do {
    Start-Sleep -Milliseconds 200
    $game.Refresh()
    if ($game.HasExited) { throw "Development game exited; see $log" }
    $ready = $false
    if (Test-Path -LiteralPath $log) {
        $ready = [bool](Select-String -LiteralPath $log -Pattern ('DEV_PREVIEW_READY screen=' + $Screen + ' mode=4 ') -Quiet)
    }
} until (($ready -and $game.MainWindowHandle -ne 0) -or [DateTime]::UtcNow -ge $deadline)
if (-not $ready -or $game.MainWindowHandle -eq 0) { throw "Development game did not confirm exclusive fullscreen on screen $Screen; see $log" }
$state = [ordered]@{ pid=$game.Id; started_at=$game.StartTime.ToString('o'); project=$project; screen=$Screen; window_mode='exclusive_fullscreen'; log=$log }
$state | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'current.json') -Encoding utf8
Write-Output "Development game ready: PID $($game.Id), fullscreen on screen $Screen."
