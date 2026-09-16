# lantern 院落资产

3.2 必要对象；原始 Tripo 文件保留，不在原件上编辑。

- 原图与固定风格：`concept.png`、`image-request.txt`、`generation-record.json`。花草与荷叶各作一次定向修正；其余一轮采用。图像工具未返回种子、模型版本或单次费用。
- 实际 Tripo ID：`11312e36-481f-4c9a-bf66-883c1ae14095`；模型 `v3.1-20260211`；成功费用 **40 积分**。请求 5000，高档实际 **6165 三角形**，同源低档 **2774 三角形**。
- 高档 Godot XYZ 尺寸：[0.29129156470298767, 0.6499999761581421, 0.2938355803489685] 米。根部：top hanging loop。颜色纹理 2048² 内嵌，两档各一材质；PBR=false，粗糙度 .97。
- Blender 制作：合重合点→规范比例/根部→同源减面→退化面清理→法线→可编辑 `lantern.blend` 与独立高低 GLB，重导入真实三角一致；详见 `asset-audit.json`。原始非流形边不代表可打印实体，开口/树叶以实际正背面检查判定。
- 复现：根目录以 Blender 5.2 运行 `ArtSource/Environment/prepare_assets.py -- lantern`，会覆盖整理源与导出物，人工改动后勿盲跑。
- Godot 组合、独立LOD及摆放契约：`Game/scenes/environment/courtyard.gd`；3.3 整合玩法与装饰状态，3.4 接管水与昼夜，3.5 接管质量切换。

开发侧审查，不伪称用户已做最终审美签收；商业授权核验按用户要求暂不执行。
