#Requires -Version 7.0
param()
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$destination=Join-Path $repo '.local/builds/wallpaper-benchmark-release'
# A copied project changes only its entry scene. Standard release templates
# forbid CLI scene/script overrides; the production package stays unchanged.
@'
from pathlib import Path
import shutil,sys,json,hashlib,subprocess
base=Path(sys.argv[1]);dst=base/'.local/builds/wallpaper-benchmark-release'
if dst.exists() and not (dst/'benchmark.json').exists():
    raise SystemExit('Refusing to reuse an unowned output directory')
source=base/'Game';target=dst/'Game';target.mkdir(parents=True,exist_ok=True)
digest=hashlib.sha256()
for p in sorted(source.rglob('*')):
    if not p.is_file() or '.godot' in p.relative_to(source).parts: continue
    relative=p.relative_to(source);out=target/relative
    digest.update(str(relative).encode());digest.update(p.read_bytes())
    out.parent.mkdir(parents=True,exist_ok=True)
    if not out.exists() or out.stat().st_mtime_ns != p.stat().st_mtime_ns or out.stat().st_size != p.stat().st_size:
        shutil.copy2(p,out)
# Import cache is an ordinary copy, never hardlinked to the working project.
cache=target/'.godot';cache.mkdir(exist_ok=True)
shutil.copytree(source/'.godot/imported',cache/'imported',dirs_exist_ok=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin']:
    if (source/'.godot'/name).exists(): shutil.copy2(source/'.godot'/name,cache/name)
shutil.copy2(base/'tests/wallpaper_budget_test.gd',target/'development/wallpaper_budget.gd')
(target/'development/wallpaper_budget.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://development/wallpaper_budget.gd" id="1"]\n[node name="WallpaperBudget" type="Node"]\nscript = ExtResource("1")\n','utf-8')
p=target/'project.godot';p.write_text(p.read_text('utf-8').replace('run/main_scene="res://scenes/main.tscn"','run/main_scene="res://development/wallpaper_budget.tscn"'),'utf-8')
shutil.copy2(base/'.local/builds/windows/FarmDesktop.exe',dst/'FarmDesktop.exe')
(dst/'benchmark.json').write_text(json.dumps({'entry':'res://development/wallpaper_budget.tscn','source_sha256':digest.hexdigest(),'probe_sha256':hashlib.sha256((base/'tests/wallpaper_budget_test.gd').read_bytes()).hexdigest(),'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=base,text=True).strip(),'runtime':'release template with isolated measurement entry'},indent=2),'utf-8')
'@ | python - $repo
if ($LASTEXITCODE -ne 0) {throw 'Benchmark project preparation failed.'}
$engine=Join-Path $env:LOCALAPPDATA 'Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
$project=Join-Path $destination 'Game'
& $engine --headless --path $project --editor --import *> (Join-Path $destination 'import.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $destination 'import.log') -Pattern '^ERROR:|^SCRIPT ERROR:' -CaseSensitive -Quiet)) {throw 'Benchmark import failed; inspect import.log.'}
& $engine --headless --path $project --export-release 'Windows Desktop' ../Farm.exe *> (Join-Path $destination 'export.log')
if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath (Join-Path $destination 'export.log') -Pattern '^ERROR:|^SCRIPT ERROR:' -CaseSensitive -Quiet)) {throw 'Benchmark export failed; inspect export.log.'}
$manifestPath=Join-Path $destination 'benchmark.json'
$manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
foreach($name in @('Farm.exe','Farm.pck','FarmDesktop.exe')) {$manifest[$name]=(Get-FileHash -LiteralPath (Join-Path $destination $name) -Algorithm SHA256).Hash}
$manifest | ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Output "BENCHMARK_EXPORTED $destination"
