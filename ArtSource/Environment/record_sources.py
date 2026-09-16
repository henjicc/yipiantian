"""Record actual completed task results without retaining signed CDN credentials."""
from pathlib import Path
import json,subprocess,shutil
repo=Path(__file__).resolve().parents[2]
plan=json.loads((repo/'ArtSource/Environment/production-plan.json').read_text(encoding='utf-8-sig'))
for item in plan:
    folder=repo/item['folder']
    submission=json.loads((folder/'submission.json').read_text(encoding='utf-8-sig'))
    result=subprocess.run(['D:/Software/nodejs/tripo.cmd','task','get',submission['task_id'],'--json'],capture_output=True,text=True,encoding='utf-8',check=True)
    task=json.loads(result.stdout)
    assert task['status']=='success',(item['id'],task.get('status'))
    task['output']={'model':'tripo-original/model.glb','preview':'tripo-original/preview.png'}
    task['input']['file']={'local':'concept.png'}
    (folder/'tripo-original/task.json').write_text(json.dumps(task,ensure_ascii=False,indent=2),encoding='utf-8')
    prompt=item['prompt']
    if 'Decorations' in item['folder']:
        prompt=prompt.replace('Input 1 is the approved rounded bok choy style:','Input 1 conveys only surface rendering and colour technique; never transfer its vegetable morphology:')
    (folder/'image-request.txt').write_text(prompt,encoding='utf-8')
    record={'image_tool':'built-in image_gen','image_version_seed_cost':'Not returned; not invented',
        'references':['docs/design-baseline/images/approved/greens-gongbi-v1.png','docs/design-baseline/images/approved/farm-gongbi-v1.png'],
        'image_calls':2 if item['id'] in ['flowers','lotus'] else 1,
        'image_refinement':{'flowers':'Replace fleshy white vegetable stalks with narrow ordinary green flower stems/leaves; preserve flowers and paint; plain cool grey background.',
            'lotus':'Remove every glow/halo/background shadow; slender green connected lotus stems; preserve leaves/flower/paint; plain cool grey background.'}.get(item['id'],'none'),
        'tripo_task_id':task['task_id'],'tripo_model':task['input']['model_version'],'credits_consumed':task.get('credits_consumed'),
        'blender':'5.2.2 LTS; prepare_assets.py normalization, bottom/top pivot, merge doubles, same-source decimation, normals, validation, editable source and GLB export',
        'godot':'4.7.2 Forward+; independent instance composition, shared lighting test, high/low image comparison',
        'adoption':'Development-side visual acceptance recorded in task 3.2; not user aesthetic approval',
        'licensing_review':'Deferred by explicit user instruction; not represented as completed'}
    (folder/'generation-record.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    audit=json.loads((folder/'asset-audit.json').read_text(encoding='utf-8'))
    values=list(audit['meshes'].values())
    (folder/'README.md').write_text(f'''# {item['id']} 院落资产

3.2 必要对象；原始 Tripo 文件保留，不在原件上编辑。

- 原图与固定风格：`concept.png`、`image-request.txt`、`generation-record.json`。花草与荷叶各作一次定向修正；其余一轮采用。图像工具未返回种子、模型版本或单次费用。
- 实际 Tripo ID：`{task['task_id']}`；模型 `{task['input']['model_version']}`；成功费用 **{task.get('credits_consumed')} 积分**。请求 {item['faces']}，高档实际 **{values[0]['triangles']} 三角形**，同源低档 **{values[1]['triangles']} 三角形**。
- 高档 Godot XYZ 尺寸：{values[0]['dimensions_godot_xyz']} 米。根部：{audit['root']}。颜色纹理 2048² 内嵌，两档各一材质；PBR=false，粗糙度 .97。
- Blender 制作：合重合点→规范比例/根部→同源减面→退化面清理→法线→可编辑 `{item['id']}.blend` 与独立高低 GLB，重导入真实三角一致；详见 `asset-audit.json`。原始非流形边不代表可打印实体，开口/树叶以实际正背面检查判定。
- 复现：根目录以 Blender 5.2 运行 `ArtSource/Environment/prepare_assets.py -- {item['id']}`，会覆盖整理源与导出物，人工改动后勿盲跑。
- Godot 组合、独立LOD及摆放契约：`Game/scenes/environment/courtyard.gd`；3.3 整合玩法与装饰状态，3.4 接管水与昼夜，3.5 接管质量切换。

开发侧审查，不伪称用户已做最终审美签收；商业授权核验按用户要求暂不执行。
''',encoding='utf-8')
    print(item['id'],task['status'],task.get('credits_consumed'))
