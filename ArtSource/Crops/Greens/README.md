# 成熟青菜源资产

- 三维来源：Tripo 任务 `d056fa4b-d573-4e9f-9f48-a9522c315446`，`v3.1-20260211`，图生整株和颜色纹理。原始输出 `tripo_original.glb` 保持不变，实际消耗 40 积分；本次原型复用它，没有新增生成费用。
- 输入图：`docs/design-baseline/images/approved/greens-gongbi-v1.png`；图片提示词见该包 `generation-record.json` 的 `crop_light_colour`，三维请求没有另加文字提示词。
- 原始参数：`smart_low_poly=true`、`face_limit=6000`、`texture=true`、`pbr=false`、`texture_quality=standard`。实际原始模型为 8790 三角形，不能按参数宣称是 6000 面。
- Blender 5.2.2 处理：合并重合顶点，减面至 2988 三角形，调整为宽约 0.48 米、根部原点接地，降低高光，保存 `greens_mature.blend`，显式导出 `Game/art/crops/greens/greens_mature.glb`。保留原有颜色纹理；无重新绘图、绑定或付费后处理。
- 可重复处理入口：用 Blender 后台运行本目录的 `prepare_greens.py`；它从原始 GLB 重建整理版，会覆盖本目录整理版及正式导出物，修改整理版后不要未经检查直接重跑。
- 检查：2988 三角形，1 材质，1 张 2048² 内嵌颜色纹理，UV 存在，无非流形边、松散点或缺失文件，缩放为 1。最初原型以36株成熟模型重复实例核对布局；该描述只属于历史样片，当前游戏已有两作物三阶段及农事功能。
- 当前采用：本成熟株已通过代表样片和正式六阶段实景校对，高档2988／手工低档1494三角形；幼芽、幼株及白萝卜的来源和验证见 [3.1交接](../../../docs/task/首个可发布版本/handoffs/3.1-handoff.md)，正式运行焦点细节策略见 [3.5交接](../../../docs/task/首个可发布版本/handoffs/3.5-handoff.md)。资产通过不等于完整游戏持续性能验收，后者由4.2记录。Blender预览、原始任务与Godot截图副本保存在本地 `制作留档/`。

职责：Tripo 生成模型与颜色纹理；Codex 编写参数、整理脚本和游戏代码；Blender 执行整理与 GLB 导出；Godot 负责场景组装与运行。
