param([Parameter(Mandatory)][int]$ProcessId,[ValidateSet('capture','click','close')][string]$Action='capture',[string]$Output,[int]$X,[int]$Y)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class FarmWindowCheck {
 [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L,T,R,B; }
 [StructLayout(LayoutKind.Sequential)] public struct Point { public int X,Y; }
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr context);
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect rect);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point point);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr h,int cmd);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint flags,uint dx,uint dy,uint data,UIntPtr extra);
}
'@
[FarmWindowCheck]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null
$target = Get-Process -Id $ProcessId
$expected = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.local/builds/windows/Farm.exe'))
if ($target.Path -ne $expected) { throw "Unexpected executable: $($target.Path)" }
$handle = $target.MainWindowHandle
if ($handle -eq 0) { throw 'Target has no native window.' }
if ($Action -eq 'close') {
 if (-not $target.CloseMainWindow()) { throw 'Native close failed.' }
 if (-not $target.WaitForExit(10000)) { throw 'Game did not complete its save and exit.' }
 Write-Output "CLOSED pid=$ProcessId exit=$($target.ExitCode)"
 return
}
[FarmWindowCheck]::ShowWindowAsync($handle,9) | Out-Null
[FarmWindowCheck]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Milliseconds 300
if ([FarmWindowCheck]::GetForegroundWindow() -ne $handle) { throw 'Target is not foreground; no input sent.' }
$rect = [FarmWindowCheck+Rect]::new()
$origin = [FarmWindowCheck+Point]::new()
if (-not [FarmWindowCheck]::GetClientRect($handle,[ref]$rect) -or -not [FarmWindowCheck]::ClientToScreen($handle,[ref]$origin)) { throw 'Cannot resolve client bounds.' }
$width = $rect.R-$rect.L
$height = $rect.B-$rect.T
if ($Action -eq 'click') {
 if ($X -lt 0 -or $Y -lt 0 -or $X -ge $width -or $Y -ge $height) { throw 'Click outside verified client.' }
 [FarmWindowCheck]::SetCursorPos($origin.X+$X,$origin.Y+$Y) | Out-Null
 [FarmWindowCheck]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
 Start-Sleep -Milliseconds 70
 [FarmWindowCheck]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Write-Output "CLICKED pid=$ProcessId client=$X,$Y"
 return
}
if (-not $Output) { throw 'Capture output required.' }
$bitmap = [Drawing.Bitmap]::new($width,$height)
$graphics = [Drawing.Graphics]::FromImage($bitmap)
try {
 $graphics.CopyFromScreen($origin.X,$origin.Y,0,0,$bitmap.Size)
 $bitmap.Save($Output,[Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $bitmap.Dispose() }
Write-Output "CAPTURED pid=$ProcessId size=${width}x${height} clientOrigin=$($origin.X),$($origin.Y) output=$Output"
