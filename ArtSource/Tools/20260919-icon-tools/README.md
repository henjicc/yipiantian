# 四件图标农具 · 2026-09-19

更新：用户否定新锄头与花纹水壶。锄头已恢复 `Game/art/characters/farmer/hoe.glb` 的旧P2工笔版（3228三角），图标按旧参考另出透明版本；下面的新锄头记录保留为未采用历史。水壶随后已按用户确认的木桶＋短柄葫芦瓢参考替换，现役源与重建入口见 `../20260919-water-bucket/README.md`；本目录水壶为历史版本。旧锄头接地与实际点击经同一场景检查通过。

用户要求直接按现有工具图标重新生成，优先 P2，替换门前旧模型；锄头用于开垦、镰刀用于除草。既有图标已由图片工具生成并获选，本次检查后原样复用，未另行出图或文字生模型。完整输入与服务回显见 [generation-record.json](generation-record.json) 和各件 `raw/tripo-out/*/task.json`。

| 工具 | 任务 ID | 积分 | 运行三角数 | 高度 |
|---|---|---:|---:|---:|
| 浇水壶 | 479b6059-a181-44bd-9541-2670e91c41d8 | 120 | 5134 | .53 m |
| 收获篮 | b6be3b14-4233-4d7c-afde-2fc05aa992b0 | 120 | 5106 | .48 m |
| 镰刀 | 11e88fa1-0d68-4aea-a70a-368e465d30ba | 120 | 1791 | .67 m |
| 锄头 | 6af57e47-cd5e-4a50-bba4-6988464bdd31 | 120 | 5079 | 1.30 m |

四件实际合计480积分。几何统一 `P2-20260801`、quad=true、face_limit=2500；纹理 `v3.5-20260815` detailed、original_image、delight=false、pbr=false、enable_image_autofix=false。P2保留可编辑四边面，v3.5用于保留获选图标的木纹、竹编与青瓷花纹。请求预算不是实际面数，各件审计单独记录。未执行重贴图、云端分件、骨骼或动画；这些静态工具不需要该环节。

`reference.png` 为原图标副本；`raw/` 保留未经修改的原始FBX及服务预览。`prepare_tools.py` 由 Blender 5.2.2 后台运行，统一尺度、底部中心与低反光材质，长柄工具按主轴扶正，锄头刃部朝下。镰刀参考中的草被生成成独立部件，整理时在副本中删除1813个草部件顶点，保留刀身、刀柄与铆钉；连接分析仅焊合分析副本，实际保留原UV和四边面。原模不变。`.blend` 保存整理后可编辑源及打包的4K色图，正式三角化输出为 `Game/art/tools/*.glb`，导出后重新导入核对三角数。

场景入口 `Game/scenes/environment/door_tools.gd`：四件分别映射 water／harvest／weed／till，位于开放门廊前沿，实际顶点最低点接地。水壶转90°使长壶嘴和花纹朝向可见侧。门廊由 `ArtSource/Environment/build_modules.py --only veranda` 重建，移除两段低栏杆，保留支撑柱、梁、台阶和平台；导出1008三角。椅子沿用历史P2模型。

验证入口 `tests/field_menu_scene_test.gd -- --visual` 使用隔离存档和游戏视口输入，不移动桌面鼠标。覆盖全景／聚焦分级、跨田携带工具、菜单翻页、取消和实际可见农具的悬停命中；截图为 `.local/verification/field-menu/` 的 `menu.png`、`seeds.png`、`tools-fan.png` 和门廊两侧 `porch-*.png`。最终美术仍待用户体验反馈。

制作节点 `20260919-icon-tools`：参考、原件、整理源、审计与实景截图已有；转角展示可由保存源重现，本次未录视频、未做云端分件。旧圆陶壶与种子篮见 `ArtSource/Characters/Farmer/props/`，标为被替换历史，不当成当前成果。
