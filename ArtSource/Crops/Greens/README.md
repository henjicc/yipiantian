# 成熟青菜源资产

## 当前采用：P2，2026-09-18

- 模型 `P2-20260801`、原生四边面输出、请求 4500 面；纹理 `v3.5-20260815`、`detailed`、`delight=true`、`pbr=false`；几何与纹理种子 202609191。任务 `6fe88ddf-d938-461a-a262-c724c28bb2bf`，实际成功费用 **120 积分**。原始 FBX 与服务回显保存在 [p2-20260918/raw/](p2-20260918/raw/task.json)。
- 参考图为秋季批已出未用的单体图 `ArtSource/Crops/Autumn2026/greens/reference.png`，不再用整幅工笔画当输入。
- 原始 FBX 为 5617 个面，其中 3669 个四边面（约 65%），三角化后 9286；非流形边 1326，属叶片薄片开边，不能称为全四边面或封闭实体。
- 可编辑源 [greens_p2.blend](p2-20260918/greens_p2.blend) 保留隐藏的 `greens_editable_quad`；运行高档 **3399**、低档 **1399** 三角形，Godot 宽 0.477 / 高 0.486 / 深 0.480 米，根部原点接地，共享 2048² 色图，roughness .93 / metallic 0 / specular IOR .12。详见 [审计](p2-20260918/asset-audit.json)。
- 顶点色 COLOR_0 携带风动权重：r 弯曲掩码（根部锁定）、g 叶片抖动（按纹理绿色度采样）、b 逐叶相位；`plant_wind.gd` 检出颜色层后走 authored 路径，青菜弯曲幅度 6 毫米。幼芽、幼株没有颜色层，保持原包围盒风动不变。
- 两个 GLB 的 `meshes/generate_lods=false`，与秋菜、荷花同口径：Godot 自动 LOD 会削薄叶片轮廓，高低档由作物目录人工切换。
- 重建：用 Blender 5.2 后台运行 [prepare.py](p2-20260918/prepare.py)，会替换整理源与正式 GLB。旧入口 `prepare_greens.py` 恢复旧 H3.1 版，不能用于更新当前 P2 版。
- 验证：青菜各项在 `crop_assets_test.gd` 通过（秋菜批失败是该测试断言早于秋菜资产契约的既有问题，与本次无关）；近景正背面、高低档与风动两帧对照证据在 `.local/verification/greens-p2/`。画面是否采用仍待用户审美签收。

## 历史 H3.1 版本

- 三维来源：Tripo 任务 `d056fa4b-d573-4e9f-9f48-a9522c315446`，`v3.1-20260211`，图生整株和颜色纹理。原始输出 `tripo_original.glb` 保持不变，实际消耗 40 积分；本次原型复用它，没有新增生成费用。
- 输入图：`docs/design-baseline/images/approved/greens-gongbi-v1.png`；图片提示词见该包 `generation-record.json` 的 `crop_light_colour`，三维请求没有另加文字提示词。
- 原始参数：`smart_low_poly=true`、`face_limit=6000`、`texture=true`、`pbr=false`、`texture_quality=standard`。实际原始模型为 8790 三角形，不能按参数宣称是 6000 面。
- Blender 5.2.2 处理：合并重合顶点，减面至 2988 三角形，调整为宽约 0.48 米、根部原点接地，降低高光，保存 `greens_mature.blend`。成熟低档 1494 三角形，从 2988 合点后 0.50 减面并平滑法线。
- 历史版通过代表样片和正式六阶段实景校对；幼芽、幼株来源和验证见 [3.1交接](../../../docs/task/首个可发布版本/handoffs/3.1-handoff.md)。

职责：Tripo 生成模型与颜色纹理；Codex 编写参数、整理脚本和游戏代码；Blender 执行整理与 GLB 导出；Godot 负责场景组装与运行。
