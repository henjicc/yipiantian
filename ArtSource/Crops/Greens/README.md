# 青菜原型资产

- 三维来源：Tripo 任务 `d056fa4b-d573-4e9f-9f48-a9522c315446`，`v3.1-20260211`，图生整株和颜色纹理。原始输出 `tripo_original.glb` 保持不变，实际消耗 40 积分；本次原型复用它，没有新增生成费用。
- 输入图：`docs/design-baseline/images/approved/greens-gongbi-v1.png`；图片提示词见该包 `generation-record.json` 的 `crop_light_colour`，三维请求没有另加文字提示词。
- 原始参数：`smart_low_poly=true`、`face_limit=6000`、`texture=true`、`pbr=false`、`texture_quality=standard`。实际原始模型为 8790 三角形，不能按参数宣称是 6000 面。
- Blender 5.2.2 处理：合并重合顶点，减面至 2988 三角形，调整为宽约 0.48 米、根部原点接地，降低高光，保存 `greens_mature.blend`，显式导出 `Game/art/crops/greens/greens_mature.glb`。保留原有颜色纹理；无重新绘图、绑定或付费后处理。
- 可重复处理入口：用 Blender 后台运行本目录的 `prepare_greens.py`；它从原始 GLB 重建整理版，会覆盖本目录整理版及正式导出物，修改整理版后不要未经检查直接重跑。
- 检查：2988 三角形，1 材质，1 张 2048² 内嵌颜色纹理，UV 存在，无非流形边、松散点或缺失文件，缩放为 1。Godot 4.7.2 导入并在原型全景 / 聚焦中检查；36 株为同一个成熟模型的重复实例，没有生长阶段或农事功能。
- 当前边界：用于确认布局与镜头的原型；工笔笔触、最终材质和代表性硬件性能仍待完整开发阶段验证。两侧 Blender 预览、原始任务与 Godot 截图副本在本地 `制作留档/`。

职责：Tripo 生成模型与颜色纹理；Codex 编写参数、整理脚本和游戏代码；Blender 执行整理与 GLB 导出；Godot 负责场景组装与运行。
