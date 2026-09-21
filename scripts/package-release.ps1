#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{7,40}$')][string]$Commit,
    [ValidatePattern('^\d+\.\d+\.\d+(-rc\.\d+)?$')][string]$Version = '0.1.2',
    [string]$GodotPath = $env:GODOT_EXE,
    [switch]$FolderOnly
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
function Invoke-Git([string[]]$Arguments) {
    $result = & git @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git operation failed: $($Arguments[0])" }
    return $result
}
$revision = (Invoke-Git @('-C',$repo,'rev-parse',"${Commit}^{commit}")).Trim()
$engineVersion = (Invoke-Git @('-C',$repo,'show',"${revision}:.godot-version")).Trim()
$projectText = (Invoke-Git @('-C',$repo,'show',"${revision}:Game/project.godot")) -join "`n"
if ($projectText -notmatch ('(?m)^config/version="'+[regex]::Escape($Version)+'"$')) { throw 'The selected commit must already contain the exact candidate version.' }
$releaseNotes = (Invoke-Git @('-C',$repo,'show',"${revision}:发行材料/版本说明.txt")) -join "`n"
if ($releaseNotes -notmatch ('^'+[regex]::Escape($Version)+'\s')) { throw 'Committed release notes and the requested version differ.' }
$releaseRoot = Join-Path $repo ('.local/releases/'+$Version+'-'+$revision.Substring(0,8))
if (Test-Path -LiteralPath $releaseRoot) { throw 'Candidate directory already exists. Keep its evidence; use a new candidate revision/version.' }
New-Item -ItemType Directory -Path $releaseRoot | Out-Null
$evidence = Join-Path $releaseRoot 'evidence'
New-Item -ItemType Directory -Path $evidence | Out-Null
$source = Join-Path $releaseRoot 'source'
$oldSkip = $env:GIT_LFS_SKIP_SMUDGE
try {
    $env:GIT_LFS_SKIP_SMUDGE = '1'
    Invoke-Git @('clone','--no-local','--no-checkout','--',$repo,$source) | Set-Content -LiteralPath (Join-Path $evidence 'clone.log') -Encoding utf8
    Invoke-Git @('-C',$source,'checkout','--detach',$revision) | Set-Content -LiteralPath (Join-Path $evidence 'checkout.log') -Encoding utf8
} finally { $env:GIT_LFS_SKIP_SMUDGE = $oldSkip }
# A local Git clone contains LFS pointers, not the source repository's LFS store.
# Copy only referenced immutable objects into its own store; never hardlink or
# configure the clone to read the original cache while building.
$common = (Invoke-Git @('-C',$repo,'rev-parse','--path-format=absolute','--git-common-dir')).Trim()
$lfs = ((Invoke-Git @('-C',$source,'lfs','ls-files','--json')) -join "`n" | ConvertFrom-Json).files
$verified = [Collections.Generic.List[object]]::new()
foreach ($item in $lfs) {
    if ($item.oid_type -ne 'sha256' -or $item.oid -notmatch '^[0-9a-f]{64}$') { throw 'Unexpected LFS object identifier.' }
    $suffix = $item.oid.Substring(0,2)+'/'+$item.oid.Substring(2,2)+'/'+$item.oid
    $original = Join-Path $common ('lfs/objects/'+$suffix)
    if (-not (Test-Path -LiteralPath $original) -or (Get-FileHash -LiteralPath $original -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.oid) { throw "Missing or corrupt local LFS object for $($item.name)" }
    $destination = Join-Path $source ('.git/lfs/objects/'+$suffix)
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    if (-not (Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $original -Destination $destination }
    $verified.Add([ordered]@{path=$item.name; sha256=$item.oid; bytes=$item.size})
}
Invoke-Git @('-C',$source,'lfs','checkout') | Set-Content -LiteralPath (Join-Path $evidence 'lfs-checkout.log') -Encoding utf8
foreach ($item in $verified) {
    $restored = Join-Path $source $item.path
    if ((Get-FileHash -LiteralPath $restored -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.sha256) { throw "LFS checkout hash mismatch: $($item.path)" }
}
$verified | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $evidence 'lfs-objects.json') -Encoding utf8
if (Invoke-Git @('-C',$source,'status','--porcelain')) { throw 'Source checkout is not clean before import.' }
foreach ($ignored in @('Game/.godot','.local','制作留档')) {
    if (Test-Path -LiteralPath (Join-Path $source $ignored)) { throw "Fresh clone unexpectedly contains ignored data: $ignored" }
}
if (-not $GodotPath) { $GodotPath = Join-Path $env:LOCALAPPDATA "Godot/$engineVersion/Godot_v${engineVersion}_win64_console.exe" }
$GodotPath = (Resolve-Path -LiteralPath $GodotPath).Path
$template = Join-Path $env:APPDATA ('Godot/export_templates/'+$engineVersion.Replace('-','.')+'/windows_release_x86_64.exe')
if (-not (Test-Path -LiteralPath $template)) { throw 'Pinned Windows release template is missing.' }
$shell = Join-Path $PSHOME 'pwsh.exe'
$importArgs = @('-NoProfile','-File',(Join-Path $source 'scripts/godot.ps1'),'-Action','Import','-GodotPath',$GodotPath)
& $shell @importArgs *> (Join-Path $evidence 'import.log')
$importExit = $LASTEXITCODE
if ($importExit -ne 0) { throw "Fresh import failed with exit code $importExit; inspect import.log." }
# The configured project font is requested before its first cold import. Only
# this known startup miss may be retried; preserve the original evidence and
# require a second import with no errors before exporting.
$importLog = Join-Path $evidence 'import.log'
$importErrors = @(Get-Content -LiteralPath $importLog | Where-Object { $_ -match '(^|\s)(ERROR:|SCRIPT ERROR:|Parse Error:)' })
if ($importErrors.Count -gt 0) {
    $fontStartupError = "^ERROR: (Cannot open file 'res://\.godot/imported/汇文明朝体\.ttf-[0-9a-f]+\.fontdata'\.|Failed loading resource: res://(?:\.godot/imported/汇文明朝体\.ttf-[0-9a-f]+\.fontdata|art/ui/fonts/汇文明朝体\.ttf)\.|Error loading custom project font 'res://art/ui/fonts/汇文明朝体\.ttf')$"
    if (@($importErrors | Where-Object { $_ -notmatch $fontStartupError }).Count -gt 0) { throw 'Fresh import contains errors other than the initial project-font cache miss.' }
    Move-Item -LiteralPath $importLog -Destination (Join-Path $evidence 'import-cold.log')
    & $shell @importArgs *> $importLog
    if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern '(^|\s)(ERROR:|SCRIPT ERROR:|Parse Error:)' -Quiet)) { throw 'Project font did not recover after cold import; inspect import logs.' }
}
$exportArgs = @('-NoProfile','-File',(Join-Path $source 'scripts/godot.ps1'),'-Action','ExportWindows','-GodotPath',$GodotPath)
& $shell @exportArgs *> (Join-Path $evidence 'export.log')
$exportExit = $LASTEXITCODE
if ($exportExit -ne 0) { throw "Release export failed with exit code $exportExit; inspect export.log." }
foreach ($log in @('import.log','export.log')) {
    if (Select-String -LiteralPath (Join-Path $evidence $log) -Pattern '(^|\s)(ERROR:|SCRIPT ERROR:|Parse Error:)' -Quiet) { throw "Engine reported errors: $log" }
}
if (Invoke-Git @('-C',$source,'status','--porcelain')) { throw 'Import changed source files or generated untracked resources; fix and commit before cutting a candidate.' }
$build = Join-Path $source '.local/builds/windows'
& (Join-Path $source 'scripts/check-release-pack.ps1') -PackPath (Join-Path $build 'Farm.pck') -ProjectDirectory (Join-Path $source 'Game') -ReportPath (Join-Path $evidence 'pack-audit.json')
$packageName = '我有一片田 Demo '+$Version+' Windows'
$package = Join-Path $releaseRoot $packageName
New-Item -ItemType Directory -Path (Join-Path $package 'notices') | Out-Null
foreach ($filename in @('Farm.exe','Farm.pck','FarmDesktop.exe')) { Copy-Item -LiteralPath (Join-Path $build $filename) -Destination $package }
foreach ($filename in @('使用说明.txt','来源与通知.txt','版本说明.txt')) { Copy-Item -LiteralPath (Join-Path $source ('发行材料/'+$filename)) -Destination $package }
foreach ($filename in @('GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt')) { Copy-Item -LiteralPath (Join-Path $source ('Game/legal/'+$filename)) -Destination (Join-Path $package 'notices') }
Copy-Item -LiteralPath (Join-Path $source 'Game/art/ui/fonts/字体来源.txt') -Destination (Join-Path $package 'notices/字体来源.txt')
$signature = Get-AuthenticodeSignature -LiteralPath (Join-Path $package 'Farm.exe')
if ($signature.Status -ne 'NotSigned') { throw "Unexpected signing status: $($signature.Status)" }
$payload = @(Get-ChildItem -LiteralPath $package -Recurse -File | Sort-Object FullName | ForEach-Object { [ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/'); bytes=$_.Length; sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()} })
$manifest = [ordered]@{version=$Version; commit=$revision; engine=$engineVersion; built_utc=[DateTime]::UtcNow.ToString('o'); platform='Windows x86_64'; signed=$false; channel='demo'; source='independent local clone; no remote configured or claimed'; engine_sha256=(Get-FileHash -LiteralPath $GodotPath).Hash.ToLowerInvariant(); template_sha256=(Get-FileHash -LiteralPath $template).Hash.ToLowerInvariant(); files=$payload}
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $package 'version.json') -Encoding utf8
$checksums = Get-ChildItem -LiteralPath $package -Recurse -File | Sort-Object FullName | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/') }
$checksums | Set-Content -LiteralPath (Join-Path $package 'SHA256SUMS.txt') -Encoding utf8
$zip = ''
if (-not $FolderOnly) {
    $zip = Join-Path $releaseRoot ($packageName+'.zip')
    Compress-Archive -LiteralPath $package -DestinationPath $zip -CompressionLevel Optimal
    ((Get-FileHash -LiteralPath $zip).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zip)) | Set-Content -LiteralPath ($zip+'.sha256') -Encoding utf8
}
Write-Output "CANDIDATE_BUILT version=$Version commit=$revision package=$package zip=$zip evidence=$evidence"
Write-Output 'Build and inventory complete. Gameplay acceptance has not been performed.'
