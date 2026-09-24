#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PackPath,
    [Parameter(Mandatory)][string]$ProjectDirectory,
    [Parameter(Mandatory)][string]$ReportPath,
    [switch]$InventoryOnly
)
$ErrorActionPreference = 'Stop'
# Read the pinned engine's standalone, unencrypted PCK directory. This does not
# launch Godot or extract arbitrary archive paths. Format reference:
# https://github.com/godotengine/godot/blob/4.7/core/io/file_access_pack.cpp
$stream = [IO.File]::OpenRead((Resolve-Path -LiteralPath $PackPath).Path)
$reader = [IO.BinaryReader]::new($stream)
$entries = [Collections.Generic.List[object]]::new()
try {
    if ($reader.ReadUInt32() -ne 0x43504447) { throw 'Not a standalone Godot PCK.' }
    $format = $reader.ReadUInt32()
    $engine = @($reader.ReadUInt32(), $reader.ReadUInt32(), $reader.ReadUInt32()) -join '.'
    $flags = $reader.ReadUInt32()
    if ($format -notin @(2,3,4) -or $flags -band 1) { throw 'Unsupported or encrypted PCK directory.' }
    $fileBase = $reader.ReadUInt64()
    if ($format -ge 3) { $stream.Position = $reader.ReadUInt64() }
    else { $stream.Position += 64 }
    $count = $reader.ReadUInt32()
    if ($count -gt 100000) { throw 'Unreasonable directory size.' }
    for ($index = 0; $index -lt $count; $index++) {
        $length = $reader.ReadUInt32()
        if ($length -gt 16384) { throw 'Invalid resource path length.' }
        $path = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)).TrimEnd([char]0)
        $path = 'res://' + ($path -replace '^res://','')
        $offset = $reader.ReadUInt64() + $fileBase
        $size = $reader.ReadUInt64()
        $md5 = [Convert]::ToHexString($reader.ReadBytes(16)).ToLowerInvariant()
        $entryFlags = $reader.ReadUInt32()
        if ($offset + $size -gt $stream.Length -or $entryFlags -ne 0) { throw "Invalid/encrypted resource: $path" }
        $entries.Add([ordered]@{path=$path; offset=$offset; bytes=$size; md5=$md5})
    }
} finally { $reader.Dispose(); $stream.Dispose() }
$paths = @($entries | ForEach-Object { $_.path })
# The directory's MD5 is only a candidate filter. Read the actual packed bytes
# before calling two entries duplicates; this also catches stale directory data.
function Get-PackedSha256([IO.FileStream]$Pack, [long]$Offset, [long]$Length) {
    $Pack.Position = $Offset
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $buffer = [byte[]]::new(1048576)
        $remaining = $Length
        while ($remaining -gt 0) {
            $wanted = [int][Math]::Min($buffer.Length, $remaining)
            $read = $Pack.Read($buffer, 0, $wanted)
            if ($read -le 0) { throw 'Packed resource ended during SHA-256 verification.' }
            $hash.AppendData($buffer, 0, $read)
            $remaining -= $read
        }
        return [Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
    } finally { $hash.Dispose() }
}
$duplicates = [Collections.Generic.List[object]]::new()
$duplicateBytes = 0L
$candidateGroups = @($entries | Where-Object { $_.bytes -gt 0 } | Group-Object { "$($_.bytes):$($_.md5)" } | Where-Object Count -gt 1)
$pack = [IO.File]::OpenRead((Resolve-Path -LiteralPath $PackPath).Path)
try {
    foreach ($candidate in $candidateGroups) {
        $verified = @($candidate.Group | ForEach-Object {
            [pscustomobject]@{ path=$_.path; bytes=$_.bytes; sha256=(Get-PackedSha256 $pack $_.offset $_.bytes) }
        })
        foreach ($group in @($verified | Group-Object sha256 | Where-Object Count -gt 1)) {
            $avoidable = [long]($group.Count - 1) * [long]$group.Group[0].bytes
            $duplicateBytes += $avoidable
            $duplicates.Add([ordered]@{sha256=$group.Name; bytes_each=$group.Group[0].bytes; avoidable_bytes=$avoidable; paths=@($group.Group.path)})
        }
    }
} finally { $pack.Dispose() }
$textureEntries = @($entries | Where-Object { $_.path -match '\.(?:ctex|stex)$' })
$textureBytes = 0L
foreach ($texture in $textureEntries) { $textureBytes += [long]$texture.bytes }
$largeTextures = @($textureEntries | Where-Object { $_.bytes -ge 16777216 } | Sort-Object bytes -Descending | ForEach-Object { [ordered]@{path=$_.path; bytes=$_.bytes} })
# The hidden release developer mode deliberately includes only this model viewer.
$reviewResource = '^res://development/(?:(?:model_gallery|model_catalog|greens_material_comparison)\.(?:gd|gdc|tscn)(?:\.remap)?|greens_pbr/[^/]+\.(?:glb|jpg|png)(?:\.import)?)$'
$forbidden = @($paths | Where-Object { $_ -match '(?i)(^|/)(development|tests?|\.local|ArtSource)/|(?:environment|style|crop|atmosphere|greens)_sample|manual_low|\.(blend[0-9]*|py|ps1|exe|bat|cmd|pem|key)$|ffmpeg|export_credentials' -and $_ -notmatch $reviewResource })
$missing = [Collections.Generic.List[string]]::new()
# all_resources is deliberate: the game loads crop, decoration and environment
# paths dynamically. Verify every adopted runtime asset has its exported mapping.
$project = (Resolve-Path -LiteralPath $ProjectDirectory).Path
$resources = Get-ChildItem -LiteralPath (Join-Path $project 'art') -Recurse -File | Where-Object { $_.Extension -in @('.glb','.png','.jpg','.svg','.otf','.ttf','.wav','.ogg','.gd') }
foreach ($resource in $resources) {
    $relative = [IO.Path]::GetRelativePath($project,$resource.FullName).Replace('\','/')
    $path = 'res://' + $relative
    if ($path -notin $paths -and ($path+'.import') -notin $paths -and ($path+'.remap') -notin $paths) { $missing.Add($path) }
}
foreach ($required in @('res://scenes/startup.tscn','res://scenes/main.tscn','res://scenes/environment/courtyard.tscn','res://art/ui/fonts/字体来源.txt','res://legal/GODOT_LICENSE.txt','res://legal/GODOT_COPYRIGHT.txt','res://project.binary')) {
    if ($required -notin $paths -and ($required+'.remap') -notin $paths) { $missing.Add($required) }
}
$report = [ordered]@{format=$format; engine=$engine; entries=$entries; texture_bytes=$textureBytes; duplicate_bytes=$duplicateBytes; duplicate_groups=$duplicates; large_textures=$largeTextures; forbidden=$forbidden; missing=$missing; passed=($forbidden.Count -eq 0 -and $missing.Count -eq 0 -and $duplicateBytes -eq 0)}
$parent = Split-Path -Parent ([IO.Path]::GetFullPath($ReportPath))
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding utf8
Write-Output "PACK_AUDIT entries=$count texture_bytes=$textureBytes duplicate_bytes=$duplicateBytes duplicate_groups=$($duplicates.Count) large_textures=$($largeTextures.Count) forbidden=$($forbidden.Count) missing=$($missing.Count) report=$ReportPath"
if (-not $InventoryOnly -and -not $report.passed) { throw 'Release pack has duplicate bytes, excluded development data, or missing runtime resources; inspect the report.' }
