#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$VideoPath,
    [Parameter(Mandatory)][string]$FFmpegPath
)

$ErrorActionPreference = 'Stop'
# These intervals are inside the current 24-second tour's movement, not its intentional holds.
# Update them together with recording_session.gd if the tour changes.
$segments = @(
    @{ name='推进'; start=4.9; frames=45 },
    @{ name='转动'; start=10.5; frames=120 }
)
$checks = foreach ($segment in $segments) {
    $start = $segment.start.ToString([Globalization.CultureInfo]::InvariantCulture)
    $filter = 'scale=320:180,format=yuv420p,tblend=all_mode=difference,signalstats,metadata=print'
    $nativeArgs = @('-hide_banner', '-nostats', '-ss', $start, '-i', $VideoPath, '-an', '-vf', $filter,
        '-frames:v', [string]$segment.frames, '-f', 'null', '-')
    $messages = & $FFmpegPath @nativeArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Cannot decode movement segment: $messages" }
    $values = @([regex]::Matches($messages, 'lavfi\.signalstats\.YAVG=([0-9.]+)') |
        Select-Object -First $segment.frames | ForEach-Object {
            [double]::Parse($_.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        })
    if ($values.Count -ne $segment.frames) { throw "Incomplete movement segment: $($segment.name)" }
    $nearRepeat = @($values | Where-Object { $_ -lt 0.01 }).Count
    [pscustomobject]@{
        segment=$segment.name; start_seconds=$segment.start; frame_pairs=$values.Count
        near_repeated_pairs=$nearRepeat; near_repeat_fraction=$nearRepeat/$values.Count
        passed=($nearRepeat/$values.Count -le 0.02); luma_mean_differences=$values
    }
}
[pscustomobject]@{
    passed=(@($checks | Where-Object { -not $_.passed }).Count -eq 0)
    method='Adjacent decoded luma mean absolute difference at 320x180, 0..255 scale; current demo moving intervals only.'
    near_repeat_threshold=0.01; max_near_repeat_fraction=0.02
    limitation='Content-based regression check, not a universal FPS measurement. Static holds are intentionally excluded; manual takes require visual review.'
    segments=@($checks)
}
