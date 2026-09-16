#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateLength(1, 60)][string]$Title,
    [Parameter(Mandatory)][ValidateLength(1, 1000)][string]$Description,
    [Parameter(Mandatory)][ValidateLength(1, 1000)][string]$Contribution,
    [ValidateRange(2, 120)][int]$Seconds = 24,
    [switch]$Demo,
    [ValidateRange(-1, 15)][int]$Screen = -1,
    [string]$FFmpegPath,
    [string]$GodotPath = $env:GODOT_EXE
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if ($Title.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $Title -match '[\r\n]' -or $Title.TrimEnd(' ', '.') -ne $Title) {
    throw 'Title must be a plain filename without slashes, newlines or trailing dots/spaces.'
}
if ($Title -notmatch '[\p{IsCJKUnifiedIdeographs}]') { throw 'Use a Chinese milestone title.' }
if ($Demo -and $Seconds -lt 24) { throw 'The paced overview/focus tour needs at least 24 seconds.' }
$version = (Get-Content -LiteralPath (Join-Path $repo '.godot-version') -Raw).Trim()
if (-not $GodotPath) { $GodotPath = Join-Path $env:LOCALAPPDATA "Godot/$version/Godot_v${version}_win64_console.exe" }
if (-not $FFmpegPath) { $FFmpegPath = Join-Path $repo '.local/tools/ffmpeg/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe' }
foreach ($toolPath in @($GodotPath, $FFmpegPath)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw "Tool missing: $toolPath. See docs/development-setup.md." }
}
$ffprobe = Join-Path (Split-Path -Parent $FFmpegPath) 'ffprobe.exe'
if (-not (Test-Path -LiteralPath $ffprobe -PathType Leaf)) { throw 'Matching ffprobe.exe is required beside ffmpeg.exe.' }
$actualVersion = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or -not ([string]$actualVersion).StartsWith($version.Replace('-', '.') + '.')) { throw 'Godot version does not match .godot-version.' }
# The console executable is a wrapper with a different PID from its GUI child.
# Query its version above, but own the GUI process directly for HWND validation.
$gamePath = $GodotPath -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $gamePath -PathType Leaf)) { throw 'The matching Godot GUI executable is required.' }
if (-not $Demo) {
    $captureHelp = & $FFmpegPath -hide_banner -h filter=gfxcapture 2>&1 | Out-String
    if ($captureHelp -notmatch 'hwnd\s+<uint64>') { throw 'This FFmpeg build does not support gfxcapture window capture.' }
}

function Start-Tool([string]$File, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.WorkingDirectory = $repo
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($info)
    return @{ Process=$process; Out=$process.StandardOutput.ReadToEndAsync(); Err=$process.StandardError.ReadToEndAsync() }
}

function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Save-Json([string]$Path, $Data) { $Data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding utf8 }

$archive = Join-Path $repo '制作留档/05_开发录屏'
New-Item -ItemType Directory -Path $archive -Force | Out-Null
# Timestamped directories and non-forced creation prevent overwriting prior takes.
$numbers = @(Get-ChildItem -LiteralPath $archive -Directory | ForEach-Object { if ($_.Name -match '^(\d+)_') { [int]$Matches[1] } })
$number = if ($numbers.Count) { ($numbers | Measure-Object -Maximum).Maximum + 1 } else { 1 }
$name = '{0:D3}_{1}_{2}' -f [int]$number, (Get-Date -Format 'yyyyMMdd_HHmmss'), $Title
$outputDir = Join-Path $archive $name
New-Item -ItemType Directory -Path $outputDir | Out-Null
$sessionDir = Join-Path $repo ('.local/recordings/' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
Save-Json (Join-Path $sessionDir 'config.json') @{ demo=[bool]$Demo; screen=$Screen }
$movieSource = Join-Path $sessionDir 'source.avi'
$candidate = Join-Path $outputDir '待校验.mp4'
$video = Join-Path $outputDir ($name + '.mp4')
$progressPath = Join-Path $sessionDir 'progress.log'
$commit = (& git -C $repo rev-parse HEAD).Trim()
$dirty = [bool](& git -C $repo status --porcelain | Out-String).Trim()
$record = [ordered]@{
    status='starting'; title=$Title; description=$Description; contribution=$Contribution
    session_directory=$sessionDir
    created_at=(Get-Date -Format o); commit=$commit; working_tree_dirty=$dirty
    duration_requested=$Seconds; demo=[bool]$Demo
    capture=$(if ($Demo) { 'Godot Movie Maker / fixed 60 fps / offline demonstration' } else { 'Windows.Graphics.Capture / HWND / realtime' })
    encoder='h264_nvenc'; preset='p5'; cq=18; fps=60; audio='none'
    ffmpeg=(& $FFmpegPath -version | Select-Object -First 1); godot=[string]$actualVersion
}
$metadata = Join-Path $outputDir '录制信息.json'
Save-Json $metadata $record
$game = $null
$encoder = $null
$success = $false
try {
    Write-Output "准备 4K 全屏录制：$Title；F9 提前结束。"
    $gameArgs = @('--path', (Join-Path $repo 'Game'), '--log-file', (Join-Path $outputDir 'Godot.log'))
    if ($Demo) { $gameArgs += @('--write-movie', $movieSource, '--fixed-fps', '60', '--resolution', '3840x2160', '--quit-after', [string]($Seconds * 60)) }
    $gameArgs += @('--', "--record-session=$sessionDir")
    $renderStarted = [DateTime]::UtcNow
    $game = Start-Tool $gamePath $gameArgs
    $readyPath = Join-Path $sessionDir 'ready.json'
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while (-not (Test-Path -LiteralPath $readyPath)) {
        if (Test-Path -LiteralPath (Join-Path $sessionDir 'error.json')) { throw (Read-Json (Join-Path $sessionDir 'error.json')).error }
        if ($game.Process.HasExited) { throw "Game exited before capture was ready: $($game.Err.GetAwaiter().GetResult())" }
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Timed out waiting for a native 4K game window.' }
        Start-Sleep -Milliseconds 100
    }
    $ready = Read-Json $readyPath
    if ($ready.width -ne 3840 -or $ready.height -ne 2160 -or $ready.render_width -ne 3840 -or $ready.render_height -ne 2160 -or $ready.pid -ne $game.Process.Id) { throw 'Capture target failed size/process validation.' }
    $record.window = $ready
    $record.status = 'recording'
    Save-Json $metadata $record
    $stopReason = 'duration'
    $codecArgs = @('-c:v', 'h264_nvenc', '-preset', 'p5', '-tune', 'hq', '-rc', 'vbr', '-cq', '18', '-b:v', '0',
        '-profile:v', 'high', '-g', '120', '-fps_mode', 'cfr', '-r', '60',
        '-color_primaries', 'bt709', '-color_trc', 'bt709', '-colorspace', 'bt709', '-color_range', 'tv',
        '-an', '-movflags', '+faststart')
    if ($Demo) {
        Write-Output '逐帧生成展示镜头；完成后由显卡编码。此模式不作为实时性能测量。'
        $lastSize = 0L
        $lastProgress = [DateTime]::UtcNow
        while (-not $game.Process.HasExited) {
            $size = if (Test-Path -LiteralPath $movieSource) { (Get-Item -LiteralPath $movieSource).Length } else { 0L }
            if ($size -gt $lastSize) { $lastSize=$size; $lastProgress=[DateTime]::UtcNow }
            if ($size -gt 3800000000L) { throw 'Movie Maker AVI is approaching its 4 GB limit. Record a shorter take.' }
            if (([DateTime]::UtcNow - $lastProgress).TotalSeconds -gt 30) { throw 'Movie Maker made no progress for 30 seconds.' }
            Start-Sleep -Milliseconds 100
        }
        $game.Process.WaitForExit()
        $record.render_wall_seconds = ([DateTime]::UtcNow - $renderStarted).TotalSeconds
        if ($game.Process.ExitCode -ne 0) { throw 'Movie Maker failed; see Godot.log.' }
        $stopPath = Join-Path $sessionDir 'stop.json'
        if (Test-Path -LiteralPath $stopPath) { $stopReason = (Read-Json $stopPath).reason }
        # MJPEG is an intermediate only. Final H.264 compression uses NVENC.
        $encoderArgs = @('-hide_banner', '-n', '-i', $movieSource, '-vf', 'scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p') + $codecArgs + @($candidate)
        $record.ffmpeg_arguments = $encoderArgs
        Save-Json $metadata $record
        Write-Output '正在以 NVIDIA 硬件编码输出 4K60 H.264。'
        $encoder = Start-Tool $FFmpegPath $encoderArgs
        $started = $true
        if (-not $encoder.Process.WaitForExit(120000)) { throw 'Hardware encoding timed out; intermediate retained in the session directory.' }
    } else {
        Write-Warning '实时窗口采集仍可能重复帧，素材需预览；预设展示镜头请使用 -Demo。'
        # Live capture keeps textures on the GPU; its CFR timeline cannot guarantee unique frames.
        $graph = "gfxcapture=hwnd=$($ready.hwnd):capture_cursor=0:capture_border=0:max_framerate=60:output_fmt=bgra,fps=60"
        $encoderArgs = @('-hide_banner', '-n', '-filter_complex', $graph, '-t', [string]$Seconds) + $codecArgs + @('-rgb_mode', 'yuv420', '-stats_period', '0.25', '-progress', $progressPath, $candidate)
        $record.ffmpeg_arguments = $encoderArgs
        Save-Json $metadata $record
        $encoder = Start-Tool $FFmpegPath $encoderArgs
        $started = $false
        $stopReason = 'duration'
        $stopSent = $false
        $lastFrame = 0
        $lastProgress = [DateTime]::UtcNow
        while (-not $encoder.Process.HasExited) {
            if (Test-Path -LiteralPath $progressPath) {
                $frames = @(Get-Content -LiteralPath $progressPath | Select-String '^frame=(\d+)$')
                $frame = if ($frames.Count) { [int]$frames[-1].Matches[0].Groups[1].Value } else { 0 }
                if ($frame -gt $lastFrame) { $lastFrame=$frame; $lastProgress=[DateTime]::UtcNow }
                if (-not $started -and $frame -gt 0) {
                    Set-Content -LiteralPath (Join-Path $sessionDir 'start') -Value 'capture-ready'
                    $started = $true
                    Write-Output '正在录制：3840×2160 / 60 CFR / NVIDIA H.264。'
                }
            }
            $stopPath = Join-Path $sessionDir 'stop.json'
            if (-not $stopSent -and ((Test-Path -LiteralPath $stopPath) -or $game.Process.HasExited)) {
                $stopReason = if (Test-Path -LiteralPath $stopPath) { (Read-Json $stopPath).reason } else { 'window_closed' }
                $encoder.Process.StandardInput.WriteLine('q')
                $encoder.Process.StandardInput.Flush()
                $stopSent = $true
            }
            if (([DateTime]::UtcNow - $lastProgress).TotalSeconds -gt 30) { throw 'Capture made no progress for 30 seconds; unfinished file retained.' }
            Start-Sleep -Milliseconds 100
        }
    }
    $encoder.Process.WaitForExit()
    $encoder.Err.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $outputDir '编码.log') -Encoding utf8
    if ($encoder.Process.ExitCode -ne 0 -or -not $started) { throw 'Hardware recording failed; see 编码.log. No software fallback was used.' }
    Set-Content -LiteralPath (Join-Path $sessionDir 'finish') -Value 'encoding-finished'
    $probeText = & $ffprobe -v error -select_streams v:0 -show_streams -show_format -of json $candidate
    if ($LASTEXITCODE -ne 0) { throw 'ffprobe could not read the recorded video.' }
    $probe = $probeText | ConvertFrom-Json
    $stream = $probe.streams[0]
    if ($stream.codec_name -ne 'h264' -or $stream.width -ne 3840 -or $stream.height -ne 2160 -or $stream.pix_fmt -ne 'yuv420p' -or $stream.avg_frame_rate -ne '60/1' -or $stream.r_frame_rate -ne '60/1') { throw 'Video format validation failed; unfinished file retained.' }
    # Check every presentation timestamp, rather than trusting the container FPS label.
    $timestamps = @(& $ffprobe -v error -select_streams v:0 -show_entries packet=pts_time -of csv=p=0 $candidate | Where-Object { $_ -match '^-?\d+\.\d+$' } | ForEach-Object { [double]::Parse($_, [Globalization.CultureInfo]::InvariantCulture) } | Sort-Object)
    if ($LASTEXITCODE -ne 0 -or $timestamps.Count -lt 2) { throw 'Video timestamp validation failed.' }
    for ($i=1; $i -lt $timestamps.Count; $i++) {
        if ([Math]::Abs(($timestamps[$i]-$timestamps[$i-1])-1.0/60.0) -gt 0.000002) { throw 'Video is not constant 60 fps.' }
    }
    $duration = [double]::Parse($stream.duration, [Globalization.CultureInfo]::InvariantCulture)
    if ($stopReason -eq 'duration' -and [Math]::Abs($duration - $Seconds) -gt 0.1) { throw 'Recording ended before its requested duration.' }
    if ($stopReason -notin @('duration', 'user_f9')) { throw "Recording interrupted ($stopReason); inspect the retained candidate before using it." }
    if ($Demo -and $stopReason -eq 'duration') {
        $motion = & (Join-Path $PSScriptRoot 'check-recording-motion.ps1') -VideoPath $candidate -FFmpegPath $FFmpegPath
        Save-Json (Join-Path $outputDir '运动流畅度检查.json') $motion
        if (-not $motion.passed) { throw 'Camera movement contains near-repeated frames; see 运动流畅度检查.json. CFR metadata alone is not sufficient.' }
        $record.motion_check = 'passed'
    } else {
        $record.motion_check = 'manual_review_required'
    }
    # Atomic final naming only after all format checks; existing clips are never overwritten.
    Move-Item -LiteralPath $candidate -Destination $video
    $record.status = 'complete'
    $record.stop_reason = $stopReason
    $record.duration_seconds = $duration
    $record.frames = $timestamps.Count
    $record.video = Split-Path -Leaf $video
    $record.sha256 = (Get-FileHash -LiteralPath $video).Hash
    Save-Json $metadata $record
    Save-Json (Join-Path $outputDir '视频规格.json') $probe
    $shots = if ($Demo) { '约 0–4 秒全景停留；4–6 秒缓慢聚焦；6–9 秒近景停留；9–14 秒小角度转动；14–17 秒停留；17–19 秒返回；19 秒后全景收尾。Godot 固定时间步逐帧渲染的自动演示，非实时录屏 / 性能证明；按画面切点。完整自动演示另检查推进和转动区间的重复画面；提前结束的片段仍需人工预览。' } else { '手动操作素材；剪辑前预览选择片段并检查运动连续性。F9 可提前结束。' }
    @("# $name", '', $Description, '', '## 工具贡献', '', $Contribution, '', '## 镜头与剪辑', '', $shots, '', "规格：3840×2160，H.264 High / yuv420p，60 fps 恒定帧率，NVENC p5 / CQ18，实际 $duration 秒。当前项目无声音，本条不录麦克风或桌面音频。", '', "代码基线：$commit；录制时工作区有改动：$dirty。", '', "[播放视频]($name.mp4)") | Set-Content -LiteralPath (Join-Path $outputDir '剪辑说明.md') -Encoding utf8
    $index = Join-Path $archive '录屏索引.md'
    if (-not (Test-Path -LiteralPath $index)) { @('# 开发录屏索引', '', '只记录关键变化，最新完成的成片可用于视频开头；过程按编号回溯。失败或中断文件留在各自目录，不加入成片清单。', '') | Set-Content -LiteralPath $index -Encoding utf8 }
    $link = "$name/剪辑说明.md"
    $reviewNote = if ($record.motion_check -eq 'manual_review_required') { '【运动连续性待人工复核】' } else { '【离线演示，运动检查通过】' }
    Add-Content -LiteralPath $index -Value "- [$name]($link) — $reviewNote $($Description -replace '[\r\n]+', ' ')" -Encoding utf8
    if ($Demo -and (Test-Path -LiteralPath $movieSource)) {
        try { Remove-Item -LiteralPath $movieSource } catch { Write-Warning "成片已完成，但中间文件清理失败：$movieSource" }
    }
    $success = $true
    Write-Output "录制完成：$video"
} catch {
    $record.status = 'failed'
    $record.error = $_.Exception.Message
    Save-Json $metadata $record
    throw
} finally {
    # Only touch processes launched by this call. No process-name-wide termination.
    if ($encoder -and -not $encoder.Process.HasExited) {
        try {
            $encoder.Process.StandardInput.WriteLine('q')
            $encoder.Process.StandardInput.Flush()
        } catch {
            Write-Warning "Encoder input closed during cleanup: $($_.Exception.Message)"
        }
        if (-not $encoder.Process.WaitForExit(5000)) {
            $encoder.Process.Kill()
            $encoder.Process.WaitForExit()
        }
    }
    if ($encoder) { $encoder.Err.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $outputDir '编码.log') -Encoding utf8 }
    if ($game -and -not $game.Process.HasExited) {
        Set-Content -LiteralPath (Join-Path $sessionDir 'finish') -Value 'launcher-finished'
        if (-not $game.Process.WaitForExit(5000)) {
            $null = $game.Process.CloseMainWindow()
            if (-not $game.Process.WaitForExit(3000)) { $game.Process.Kill() }
        }
    }
    if ($game) { $game.Out.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $outputDir '启动输出.log') -Encoding utf8 }
    if ($game) { $game.Err.GetAwaiter().GetResult() | Set-Content -LiteralPath (Join-Path $outputDir '启动错误.log') -Encoding utf8 }
    if (-not $success) { Write-Warning "本次未成为成片，诊断与候选文件保留于：$outputDir" }
}
