# 青菜阶段源资产

本目录由任务 3.1 维护；现有成熟株仍以 `../greens_mature.blend` 和正式 `Game/art/crops/greens/greens_mature.glb` 为准，不在本目录重生成或覆盖。

## 输入图与阶段关系

| 阶段 | 模型输入 | 造型 | 目标运行宽度 |
|---|---|---|---|
| 幼芽 `sprout` | `references/greens_sprout.png` | 两片宽圆杯状叶、短粗浅色叶柄，共同根部 | 0.14 米 |
| 幼株 `young` | `references/greens_young_input.png` | 三片外叶与小中央叶，较直立、未完全展开 | 0.30 米 |
| 成熟 `mature` | 复用既有原件 | 五六片外展宽叶与厚浅色叶柄 | 0.48 米 |

2026-09-17 使用内置 imagegen 出图，每个 `*-generation.json` 保存完整提示词、实际输入顺序和原始输出位置。固定参考始终是仓库内青菜 v1 与全景 v1；未采用历史结构图替代风格输入。幼株原图有半透明大投影，已单次定向去影并另存 `_input.png`，原图保留。没有程序化重画或修改参考图。

## 整理入口

`prepare_stages.py` 是本任务五个缺失阶段的共同 Blender 处理入口，显式指定资产名和已经下载的原始 GLB。它会重建对应 `blend/` 源和正式导出，手改源后不要盲目重跑；原始 `raw/` 不改写。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python 'ArtSource/Crops/Greens/Stages/prepare_stages.py' -- --asset greens_sprout --source '<仓库内原始模型路径>'
```

目标是带厚度的完整作物，不增加骨架、碰撞或逐叶行为。高低网格来自同一源，材质纹理同源；米制、根部原点、Blender Z 向上经 glTF 转 Godot Y 向上。材质沿成熟青菜的哑光值（roughness 0.93、metallic 0、specular IOR level 0.12），不将笔触均匀抹平。

成熟低档已从 1.2 验收输出 `Game/scenes/style_sample/greens_sample_low.glb` 原样复制到正式 `Game/art/crops/greens/greens_mature_low.glb`，1494 三角形。1.2 的关键处理是先合并导入 GLB 的重合点再从 2988 三角形按 0.50 减面并平滑法线；未采用有叶缘破裂的旧 1015 三角形候选。原始高档不变，不重新付费生成。源处理入口暂位于 `ArtSource/Environment/House/prepare_house.py`，在 1.2 交接保留真实生产关系。

两阶段 Tripo 原任务均成功，每项 40 积分，共 80 积分；完整 ID／参数／原始输出见 `tripo-jobs.json` 和 `raw/`。没有重抽或付费生成低档。实际生成面数超过请求值，因此按实际几何处理，不能拿请求上限当作最终预算。

| 阶段 | 原始三角形 | 正式高／低三角形 | Godot 宽 X／高 Y／深 Z（米） |
|---|---:|---:|---|
| 幼芽 | 2022 | 700 / 280 | 0.083866 / 0.103797 / 0.140000 |
| 幼株 | 5385 | 2006 / 650 | 0.140726 / 0.289257 / 0.300000 |
| 成熟（复用） | 2988 | 2988 / 1494 | 0.437754 / 0.417427 / 0.480000 |

新阶段每档 1 网格、1 材质、1 张 2048² 颜色纹理，未添加骨架／碰撞。`blend/*-report.json` 保存高低网格、尺寸、UV、法线与重导入报告；`*-audit.json` 为 Blender 技能正式审计。幼株中央折叶连接处删除一片最小重叠面并补齐小孔，保留原有叶形与 UV；五阶段处理入口只修补尺度受限的小缝，较大缺陷直接报错。高低档焊合源网格均封闭且无非流形边；GLB 重导入因 UV 接缝拆点产生的边界计数不等于真实破洞。

Godot 4.7.2 / Forward+ 实机测试 `tests/crop_assets_test.gd` 共 159 项通过，16 张原生 1920×1080 截图包含正背面、暗处、同根部阶段切换、54 株全景和全成熟高低对照。映射、复现命令、截图路径及后续边界见 [3.1 交接](../../../../docs/task/首个可发布版本/handoffs/3.1-handoff.md)。正式样片为 `res://scenes/crop_sample/crop_sample.tscn`；正式主场景由 3.3 接入。
