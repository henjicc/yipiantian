# 工笔木桶与葫芦瓢 · 2026-09-19

用户确认新版短柄葫芦瓢参考后，采用 Tripo P2 生成，替换门前浇水道具。上一版花纹水壶保留在 `../20260919-icon-tools/water/`，不再用于场景。菜单图标未在本次修改。

- 参考：`reference.png`，来自内置图片工具 `exec-1c6abb33-1201-404c-81e0-54c4877ee009.png`，基于 C 木桶图修改；用户已确认。完整图片提示词见 `image-record.json`。
- 任务：`1447617e-8fe1-4c3b-b20a-a02787618e1b`，实际 120 积分。原始模型、预览与服务回显保留在 `raw/tripo-out/water-bucket-gongbi-1447617e/`。
- 几何 `P2-20260801`，quad=true，face_limit=3500；纹理 `v3.5-20260815` detailed、original_image、delight=false、pbr=false，禁用自动修图。复用已验证工笔路线，保留参考木纹与结构勾线。
- Blender 5.2.2 整理为高 .62 m、宽 .456 m、深 .452 m，底部中心原点；3569 多边形，其中3080四边面，导出6649三角。单材质、4096²色图，粗糙度 .94，金属度0。不减面、不分件、不重贴图或绑定。
- 可编辑源 `water-bucket.blend`；正式资源 `Game/art/tools/water.glb`，场景入口 `Game/scenes/environment/door_tools.gd`。门廊局部位置(.65,.28,.24)，相对门廊旋转0°，复用实际顶点接地与悬停描边／点击浇水功能。保留普通自动LOD。

重建：用 Blender 后台执行本目录 `prepare.py`，会重写上述现役 GLB、整理源和审计；原始FBX不变。旧四工具 `prepare_tools.py` 会恢复历史花纹水壶，不能作为当前水桶重建入口。

制作节点 `20260919-water-bucket`：参考→原始模型预览→整理源及审计→门廊场景截图。原模与导出重导入三角数一致；Godot导入成功；既有 field_menu_scene_test 检查输出 FIELD_MENU_PASS，真实网格悬停／点击通过，两侧近景已确认新模型、接地和周边间距。本次按用户要求只做基础检查，不录视频，最终美术由用户实看。分件／动作不适用；转角展示可由保存源补拍。实景截图入口 `.local/verification/field-menu/porch-*.png`（本地，不随Git同步）。
