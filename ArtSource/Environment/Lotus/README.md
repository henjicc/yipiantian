# lotus 院落资产

## 当前采用：P2，2026-09-17

用户实景反馈：荷花比原版明显改善。正式高低 GLB 已改用 [P2 版本](p2-20260917/raw/task.json)，参考图仍是本目录 `concept.png`；以下旧版记录保留作对照。

- 模型 `P2-20260801`、原生四边面输出、请求 4500 面；纹理显式指定 `v3.5-20260815`、`detailed`、`delight=true`、`pbr=false`。实际成功费用 **120 积分**。
- 原始 FBX 为 4352 个面，其中 3408 个四边面（约 78.3%），三角化后 7760；不能称为全四边面或封闭可打印实体。原始 FBX 和 4K 内嵌纹理保存在 `p2-20260917/raw/model.fbx`。
- 可编辑源 [lotus.blend](p2-20260917/lotus.blend) 保留隐藏的 `lotus_editable_quad`，运行高档 **7760**、低档 **3500** 三角形；运行共享 2K 色图、单材质、宽 0.9 米。清除 2 个孤立点，薄片开边保留，正背面及花瓣在实景检查。详见 [审计](p2-20260917/asset-audit.json)。
- 两个 GLB 的 `meshes/generate_lods=false`：Godot 4.7.2 自动 LOD 曾删掉大部分花瓣、切断茎，并使叶片纹理破碎；关闭额外简化后同镜头恢复完整。仍由院落现有逻辑切换人工高低档，不关闭全局 LOD。
- 重建：用 Blender 5.2 执行 [prepare.py](p2-20260917/prepare.py)，会替换当前版本整理源和正式 GLB。旧入口 `../prepare_assets.py -- lotus` 会恢复旧 H3.1 版，不能用于更新当前 P2 版。

## 历史 H3.1 版本

3.2 必要对象；旧原始 Tripo 文件及 `lotus.blend` 保留，不在原件上编辑。

- 原图与固定风格：`concept.png`、`image-request.txt`、`generation-record.json`。花草与荷叶各作一次定向修正；其余一轮采用。图像工具未返回种子、模型版本或单次费用。
- 实际 Tripo ID：`a45b0f40-621c-4de7-9e56-db86766c3687`；模型 `v3.1-20260211`；成功费用 **40 积分**。请求 7000，高档实际 **9315 三角形**，同源低档 **4190 三角形**。
- 高档 Godot XYZ 尺寸：[0.8999999761581421, 0.5864970684051514, 0.6534246206283569] 米。根部：ground bottom centre。颜色纹理 2048² 内嵌，两档各一材质；PBR=false，粗糙度 .97。
- Blender 制作：合重合点→规范比例/根部→同源减面→退化面清理→法线→可编辑 `lotus.blend` 与独立高低 GLB，重导入真实三角一致；详见 `asset-audit.json`。原始非流形边不代表可打印实体，开口/树叶以实际正背面检查判定。
- 复现：根目录以 Blender 5.2 运行 `ArtSource/Environment/prepare_assets.py -- lotus`，会覆盖整理源与导出物，人工改动后勿盲跑。
- Godot 组合、独立LOD及摆放契约：`Game/scenes/environment/courtyard.gd`；3.3 整合玩法与装饰状态，3.4 接管水与昼夜，3.5 接管质量切换。

开发侧审查，不伪称用户已做最终审美签收；商业授权核验按用户要求暂不执行。
