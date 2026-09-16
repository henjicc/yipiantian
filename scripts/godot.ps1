[CmdletBinding()]
param(
    [ValidateSet('Editor', 'Run', 'Import', 'ExportWindows')]
    [string]$Action = 'Editor',
    [string]$GodotPath = $env:GODOT_EXE,
    [string[]]$ExtraArgs = @()
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $repoRoot '.godot-version') -Raw).Trim()
$projectPath = Join-Path $repoRoot 'Game'
if (-not $GodotPath) {
    $GodotPath = Join-Path $env:LOCALAPPDATA "Godot/$version/Godot_v${version}_win64_console.exe"
}
if (-not (Test-Path -LiteralPath $GodotPath -PathType Leaf)) {
    throw "Godot not found. Install $version or set GODOT_EXE to its console executable. See docs/development-setup.md."
}
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$actualVersion = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or -not ([string]$actualVersion).StartsWith($version.Replace('-', '.') + '.')) {
    throw "Expected Godot $version; got $actualVersion. Update the engine and templates together."
}

$nativeArgs = @('--path', $projectPath)
switch ($Action) {
    'Editor' { $nativeArgs += '--editor' }
    'Run' { }
    'Import' { $nativeArgs += @('--headless', '--import') }
    'ExportWindows' {
        $buildDirectory = Join-Path $repoRoot '.local/builds/windows'
        New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null
        $nativeArgs += @('--headless', '--export-release', 'Windows Desktop', (Join-Path $buildDirectory 'Farm.exe'))
    }
}
$nativeArgs += $ExtraArgs
if ($Action -eq 'Editor') {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    # Avoid a separate console window for interactive editing.
    $guiPath = $GodotPath -replace '_console\.exe$', '.exe'
    $startInfo.FileName = if (Test-Path -LiteralPath $guiPath) { $guiPath } else { $GodotPath }
    $startInfo.UseShellExecute = $false
    foreach ($argument in $nativeArgs) { $startInfo.ArgumentList.Add($argument) }
    $editorProcess = [System.Diagnostics.Process]::Start($startInfo)
    Write-Output "Godot editor started for $projectPath (PID $($editorProcess.Id))."
} else {
    & $GodotPath @nativeArgs
    if ($LASTEXITCODE -ne 0) { throw "Godot $Action failed with exit code $LASTEXITCODE." }
}
