#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateLength(1, 60)][string]$Title,
    [Parameter(Mandatory)][ValidateLength(1, 1000)][string]$Description,
    [Parameter(Mandatory)][ValidateLength(1, 1000)][string]$Contribution,
    [ValidateRange(2, 120)][int]$Seconds = 24,
    [switch]$Demo,
    [switch]$FarmDemo,
    [switch]$CourtyardDemo,
    [switch]$FinalDemo,
    [switch]$RealtimeProbe,
    [switch]$WithAudio,
    [ValidateRange(-1, 15)][int]$Screen = -1,
    [string]$FFmpegPath,
    [string]$GodotPath = $env:GODOT_EXE
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if ($FarmDemo) { $Demo = $true }
if ($CourtyardDemo) { $Demo = $true }
if ($FinalDemo) { $Demo = $true }
if ($RealtimeProbe -and ($Demo -or $WithAudio -or $Seconds -lt 14 -or $Seconds -gt 20)) { throw 'RealtimeProbe is a silent 14-20 second bounded live capture; do not combine it with offline demonstrations.' }
if ((@($FarmDemo, $CourtyardDemo, $FinalDemo) | Where-Object { $_ }).Count -gt 1) { throw 'Select one demonstration.' }
if ($FinalDemo -and $Seconds -lt 56) { throw 'The final gameplay and atmosphere demonstration needs at least 56 seconds.' }
if ($CourtyardDemo -and $Seconds -lt 40) { throw 'The courtyard and arrangement demonstration needs at least 40 seconds.' }
if ($WithAudio -and -not $Demo) { throw 'WithAudio requires Movie Maker demonstration capture.' }
if ($FarmDemo -and $Seconds -lt 28) { throw 'The sow/water/harvest demonstration needs at least 28 seconds.' }
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
Save-Json (Join-Path $sessionDir 'config.json') @{ demo=[bool]($Demo -or $RealtimeProbe); farm_demo=[bool]$FarmDemo; courtyard_demo=[bool]$CourtyardDemo; final_demo=[bool]$FinalDemo; capture_audio=[bool]$WithAudio; movie_frame_limit=$(if ($Demo) { $Seconds * 60 } else { 0 }); screen=$Screen }
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
    farm_demo=[bool]$FarmDemo; controlled_utc_advance_seconds=$(if ($FarmDemo -or $FinalDemo) { 1440 } else { 0 })
    courtyard_demo=[bool]$CourtyardDemo
    final_demo=[bool]$FinalDemo
    realtime_probe=[bool]$RealtimeProbe
    capture=$(if ($Demo) { 'Godot Movie Maker / fixed 60 fps / offline demonstration' } else { 'Windows.Graphics.Capture / HWND / realtime' })
    encoder='h264_nvenc'; preset='p5'; cq=18; fps=60; audio=$(if ($WithAudio) { 'Godot game mix / AAC 48 kHz stereo / 192 kbps' } else { 'none' })
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
        '-movflags', '+faststart')
    $codecArgs += $(if ($WithAudio) { @('-c:a','aac','-b:a','192k','-ar','48000','-ac','2') } else { @('-an') })
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
        if ($FarmDemo -and $stopReason -eq 'duration') {
            $farmResult = Read-Json (Join-Path $sessionDir 'farm-demo-result.json')
            if (-not $farmResult.saved -or $farmResult.snapshot.harvested.greens -ne 1 -or $farmResult.snapshot.fields.field_01.crop_id -ne '') {
                throw 'The recorded farming loop did not reach its saved harvest state.'
            }
            $record.farm_demo_result = $farmResult
        }
        if ($CourtyardDemo -and $stopReason -eq 'duration') {
            $courtyardResult = Read-Json (Join-Path $sessionDir 'courtyard-demo-result.json')
            if (-not $courtyardResult.saved -or $courtyardResult.farm.harvested.greens -ne 10 -or
                -not $courtyardResult.decorations.lantern.unlocked -or
                -not $courtyardResult.decorations.pot.slot_id -or -not $courtyardResult.decorations.flowerpot.slot_id -or -not $courtyardResult.decorations.lantern.slot_id) {
                throw 'The courtyard demonstration did not reach confirmed saved placements.'
            }
            $record.courtyard_demo_result = $courtyardResult
        }
        if ($FinalDemo -and $stopReason -eq 'duration') {
            $finalResult = Read-Json (Join-Path $sessionDir 'final-demo-result.json')
            if (-not $finalResult.saved -or $finalResult.farm.harvested.greens -ne 11 -or $finalResult.farm.fields.field_03.crop_id -ne '' -or
                -not $finalResult.decorations.pot.slot_id -or -not $finalResult.decorations.flowerpot.slot_id -or -not $finalResult.decorations.lantern.slot_id -or
                $finalResult.presentation.quality -ne 'standard' -or -not $finalResult.presentation.dof_enabled -or $finalResult.mesh_lod_threshold -le 0 -or -not $finalResult.hud_clock_matches_fixture) {
                throw 'The final demonstration did not reach saved harvest, placement and normal presentation conditions.'
            }
            $record.final_demo_result = $finalResult
        }
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
    $minimumStep = [double]::PositiveInfinity
    $maximumStep = 0.0
    for ($i=1; $i -lt $timestamps.Count; $i++) {
        $step = $timestamps[$i]-$timestamps[$i-1]
        $minimumStep = [Math]::Min($minimumStep, $step)
        $maximumStep = [Math]::Max($maximumStep, $step)
        if ([Math]::Abs($step-1.0/60.0) -gt 0.000002) { throw 'Video is not constant 60 fps.' }
    }
    $duration = [double]::Parse($stream.duration, [Globalization.CultureInfo]::InvariantCulture)
    if ($WithAudio) {
        $audioProbe = (& $ffprobe -v error -select_streams a:0 -show_streams -of json $candidate | ConvertFrom-Json).streams[0]
        if ($LASTEXITCODE -ne 0 -or $audioProbe.codec_name -ne 'aac' -or $audioProbe.sample_rate -ne '48000' -or $audioProbe.channels -ne 2 -or [Math]::Abs([double]$audioProbe.duration - $duration) -gt 0.1) { throw 'Recorded game audio format or duration is invalid.' }
        $audioAnalysis = & $FFmpegPath -hide_banner -nostats -i $candidate -vn -af volumedetect -f null - 2>&1 | Out-String
        $audioMatch = [regex]::Match($audioAnalysis,'mean_volume:\s+(-?[\d.]+) dB')
        if ($LASTEXITCODE -ne 0 -or -not $audioMatch.Success -or [double]::Parse($audioMatch.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture) -lt -80) { throw 'Recorded game audio is silent or could not be decoded.' }
        $record.audio_verification = @{ mean_db=[double]::Parse($audioMatch.Groups[1].Value,[Globalization.CultureInfo]::InvariantCulture); duration_seconds=[double]$audioProbe.duration; duration_difference_seconds=[Math]::Abs([double]$audioProbe.duration - $duration); subjective_listening='not verified' }
        $audioAnalysis | Set-Content -LiteralPath (Join-Path $outputDir '音轨校验.log') -Encoding utf8
    }
    if ($stopReason -eq 'duration' -and [Math]::Abs($duration - $Seconds) -gt 0.1) { throw 'Recording ended before its requested duration.' }
    if ($stopReason -notin @('duration', 'user_f9')) { throw "Recording interrupted ($stopReason); inspect the retained candidate before using it." }
    if ($Demo -and $stopReason -eq 'duration') {
        $motion = & (Join-Path $PSScriptRoot 'check-recording-motion.ps1') -VideoPath $candidate -FFmpegPath $FFmpegPath -Tour $(if ($FinalDemo) { 'final' } else { 'classic' })
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
    $record.timestamps = @{ checked_packets=$timestamps.Count; minimum_step_seconds=$minimumStep; maximum_step_seconds=$maximumStep; expected_step_seconds=1.0/60.0; maximum_allowed_step_error_seconds=0.000002 }
    $record.video = Split-Path -Leaf $video
    $record.sha256 = (Get-FileHash -LiteralPath $video).Hash
    Save-Json $metadata $record
    Save-Json (Join-Path $outputDir '视频规格.json') $probe
    $shots = if ($FinalDemo) { '0–4秒六阶段全景；4秒聚焦成熟青菜，6.5秒收获，9秒播种，12秒浇水；13–18秒缓转，18秒受控推进300秒为幼株，21秒再推进1140秒成熟，24秒收获，27秒返回。31–34秒陶罐，35–38秒花盆，39–42秒灯笼预览确认；44秒收起，46–52秒昼转夜，52–56秒停留。六阶段、初始累计青菜9/萝卜6、UTC推进与HUD12→21时钟均是隔离演示夹具；采用正式设置与普通LOD/DOF，不强制全高，不代表实时性能。' } elseif ($CourtyardDemo) { '0–4秒六个正式阶段全景；4秒聚焦，6.5秒收获触发灯笼解锁；9–14秒缓转；14秒返回。18–21秒陶罐预览确认，23–26秒花盆，28–31秒灯笼；34秒收起布置，36秒切夜景并停留。初始累计青菜9/萝卜6、作物阶段及本地12/21点为隔离录制夹具，农事/布置仍走普通场景动作和保存链。离线固定步长演示，不代表真实等待或实时性能。' } elseif ($FarmDemo) { '约 0–4 秒全景；4–6 秒聚焦；6.5 秒播种；9 秒浇水；9–14 秒小角度转动；14 秒受控推进 UTC 1440 秒，展示成熟；17 秒收获并保存；21 秒返回全景。使用独立演示存档与正常农事动作 / 保存链；时间推进是录制夹具，并非真实等待 30 分钟。Godot 固定步长离线演示，不代表实时性能。' } elseif ($Demo) { '约 0–4 秒全景停留；4–6 秒缓慢聚焦；6–9 秒近景停留；9–14 秒小角度转动；14–17 秒停留；17–19 秒返回；19 秒后全景收尾。Godot 固定时间步逐帧渲染的自动演示，非实时录屏 / 性能证明；按画面切点。完整自动演示另检查推进和转动区间的重复画面；提前结束的片段仍需人工预览。' } elseif ($RealtimeProbe) { '有界实时窗口采集探针：采用本次游戏窗口与现有WGC链路，4秒开始缓推，9–14秒小角度转动。画面按实时呈现采集，不是MovieMaker；需另查相邻帧，未通过前不作流畅素材。' } else { '手动操作素材；剪辑前预览选择片段并检查运动连续性。F9 可提前结束。' }
    @("# $name", '', $Description, '', '## 工具贡献', '', $Contribution, '', '## 镜头与剪辑', '', $shots, '', "规格：3840×2160，H.264 High / yuv420p，60 fps 恒定帧率，NVENC p5 / CQ18，实际 $duration 秒。音轨：$($record.audio)。不录麦克风或其他桌面程序；主观听感尚未验收。", '', "代码基线：$commit；录制时工作区有改动：$dirty。", '', "[播放视频]($name.mp4)") | Set-Content -LiteralPath (Join-Path $outputDir '剪辑说明.md') -Encoding utf8
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
