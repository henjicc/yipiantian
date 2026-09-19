# 厨房成品与食记 · 20260918

第17项目标接入：三张统一工笔淡彩参考经 Tripo H3.1 Ultra 生成三种成品，Blender 整理尺寸与原点，Godot 接入厨房、晒架、陶罐和餐桌。采用状态：已接入且查看实景，尚无玩家主观反馈。修改前基线 `528ab97`；完成提交可由本文件的 Git 历史定位。

## 原件与生成参数

- 图片工具：内置 image_gen。共享参考依次为 `docs/design-baseline/images/approved/greens-gongbi-v1.png`、`farm-gongbi-v1.png`。完整实际提示词、原始返回路径和输入顺序在 [image-records.json](20260918/image-records.json)。参考图已保存为本目录 `20260918/*-reference.png`，不依赖工具缓存。工具未回显模型版本、种子和图像费用，不编造。
- 三张图分别检查完整器皿、食物与统一材质后采用。三维调用为 image_to_model，几何 `v3.1-20260211`，`geometry_quality=detailed`（H3.1 Ultra），纹理 `v3.5-20260815`、`texture_quality=detailed`；`face_limit=30000`、`texture=true`、`delight=true`、`pbr=false`、`smart_low_poly=false`、`enable_image_autofix=false`，种子91840–91842。
- 每件60积分，合计 **180积分**。余额变化已核验，冻结状态未公开。服务成功回显与输入参数见 [provenance.json](20260918/provenance.json)。原始 `task.json` 可能含上传凭据，仅本地保留并定向忽略，正式记录只保留无凭据字段；模型、预览和参考原件不修改。

| 资产 | Tripo任务 | 实际三角数 | 水平跨度 | 世界落点 |
|---|---|---:|---:|---|
| stir_fry 清炒时蔬 | cc8adf3c-faa1-405f-b6c2-99f9e8ee5767 | 28193 | 0.42米 | 厢房旁上层竹匾／选中后主屋廊桌 |
| root_soup 菜根汤 | 3de1eb15-a51a-4409-8fea-e4b73fb6f5aa | 28238 | 0.40米 | 同上 |
| pickled_greens 腌菜罐 | ea32e36e-7cdc-49ff-bf1c-439aa94cf99d | 29808 | 0.38米 | 右院陶罐群／选中后廊桌 |

各一材质、一张4096²颜色纹理。原始模型与云端静态预览在 `20260918/<资产>-original/tripo-out/`，目录由 provenance 索引。菜干复用 [CourtyardLife](../CourtyardLife/README.md) 的 `slices` 参考与模型，未重新付费；它是通用晒干菜片的视觉符号，不按每种原料另生模型。清炒芹菜与清炒叶菜共用成品盘，香蔬和腌菜共用陶罐。实际用料仍独立记录在食记中。

## 整理与重建

使用 Blender 5.2.2 LTS，在仓库根运行：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python ArtSource/Environment/Kitchen/prepare.py
& ./scripts/godot.ps1 -Action Import
```

[prepare.py](prepare.py) 读取不可变原GLB，应用物体变换；以底面中心为原点，统一米制水平跨度和朝向。保留所有三角、UV及原颜色贴图；哑光材质，打包纹理到 `20260918/*.blend`，导出 `Game/art/environment/kitchen/*.glb`。本入口会覆盖这三件整理源、导出物与审计，不覆盖原模型和参考图。没有语义分割、骨骼、云端转格式或减面步骤，因为本批为静态成品。导入设置关闭这三件近景道具的自动LOD，没有修改其他资产LOD。

标准Blender审计和独立重导入检查均完成；对应 `*-audit.json`、`*-blender-audit.json` 保留三角数、UV、尺寸、贴图等结果。几何位置焊接仅用于副本诊断，未改变导出：清炒模型有1条边界，其余0条，均无零面积面；不声称全件封闭。正常使用中盘底不可见，实景查看未见影响轮廓的破口。

运行表现位于 `Game/presentation/kitchen_display.gd`：从实际布局中的 `LivingDetails` 支承物取得变换；厨房使用厢房门前竹架上层右侧作为出菜位，晒架用上层左侧，陶罐替换罐群原大罐，廊桌替换原菜干。表示制作种类及成品，不包含室内灶具、人物切菜或炒锅物理模拟。沿用 `courtyard_surface` 的色彩／雾逻辑；模型落在竹匾实际底面，既有支承物占地不扩大，布局重建后重新取得锚点。该显示器管理三处制作展示和一份桌面展示，仅状态变更时重建；无每份食物的逐帧计算。

2026-09-20 小岛建设第12项复用现有菜干模型，为可摆放小晒架增加独立工位 `garden_rack`。第一次分享成品解锁，实际摆放后才开放；原廊下工位 `rack` 继续使用。移动晒架的菜干由 `decoration_layout.gd` 管理，只显示该工位的真实加工任务，随支架移动／旋转，收取后隐藏，不复制廊下任务或库存。没有生成或修改模型，没有新增 Tripo 费用。实景完整操作31项通过，证据 `.local/verification/life-live-second.log` 和 `construction-life-1789836656/`；已查看正反接触、夜景及小窗口。加工时间通过测试注入UTC推进，未修改系统时间。存档为 `farm-v24`。

## 验证与视频节点

节点 **20260918-kitchen-food-journal**。流程证据：`.local/verification/kitchen-scene-final.log`，画面目录 `.local/verification/kitchen-1745563/`，含配方、三工位、实景近看、食记、餐桌汤食昼夜与960×600界面。已查看真实模型、落点、遮挡与UI；场景鼠标操作、保存失败不扣食材、重试、三工位收取、分享、重读和近看返回通过。最初读档检查暴露JSON数值类型未归一，已在加载边界修复；按钮检查也改为先滚入可见区域，再断言近看确实开启。

纯玩法 `tests/kitchen_state_test.gd` 347项通过，覆盖六配方、十二菜、三户分享、UTC完成、离线一年、重复回调、无库存和损坏状态；现有农场371项、存档55项通过。最终场景退出无资源占用错误；此前一次快速退出曾触发与历史类似的清理告警，最终整体第25项仍需核验通常退出，不把一次通过当成全项目清理问题已根治。

| 视频环节 | 已有材料 | 当前状态 |
|---|---|---|
| 统一参考图 | 三张 `*-reference.png` 与实际提示词 | 已有图片 |
| Tripo原模与旋转 | 三份不可变 `model.glb`、云端预览 | 有源，转角视频待补拍 |
| 分件／绑定 | 本批不需要 | 未执行，不演示为已执行 |
| Blender整理 | 三份打包纹理 `.blend`、重建脚本与审计 | 有源，可重现 |
| 游戏效果 | 上述近景与UI截图、完整隔离场景脚本 | 已有截图，无本轮录像 |

本轮没有必要持续录制；后续可按保存源重现“参考→Tripo模型旋转→尺寸整理→厨房制作与食记”的视频，并标明重现。图片工具负责参考，Tripo负责三维几何与纹理，Blender负责整理，Godot负责玩法和场景接入，不混淆贡献。
