# 格子呈现与交互交接

状态：源码、无窗口回归与当前冻结镜头下原生输入/实景验证完成；未提交，交根代理统一整合。

## 接口与行为

- 权威状态来自 FarmState v3：六个 `field_XX` 各含 16 个 `cell_XX`，row-major 为行沿 +Z、列沿 +X。呈现层只读 `get_field().cells` / `get_cell()`；不复制生长或迁移规则。
- `FarmLayout.fields` 仍是六个 StaticBody3D，位置/尺寸和 `Crops` 容器保持。`cell_center(cell_id)` 返回原 4×4 锚点集合，正式作物原尺寸、根深、风材质和 LOD 不变；`Crops` 直属只有非空格的实际作物，节点名为 cell ID，metadata 为 `cell_id` / `field_id` / `stage_key`。
- 16 个低土面以窄沟分开，各格 `_soil_meshes[field_id][cell_id]` 独立更新湿土。阶段与浇水变化只更新对应格，时间基线变化不重建作物，邻格实例不受影响。没有粗 UI 棋盘或每格物理体。
- 碰撞体由旧高代理盒改为田床真实尺寸，世界射线命中土表面后由 `cell_at(field_index, world_position)` 判定准确格坐标；田床外缘不冒充格子，侧面可聚焦田但不选格。不以最近植株、叶片碰撞或作物大小确定格子。
- 全景点击只聚焦大田；聚焦后点击只选格。种子选择紧邻播种，先选青菜/白萝卜，再点击播种、浇水或收获，直接作用选中格。无选格时按钮禁用。成功后保留格选择，世界点击永远不执行农事。
- 主场景 `selected_cell: String` 为空表示只聚焦田；`_select_cell(id)` 只选择，`_select_crop(id)` 只选种子，`_select_tool(tool)` 为对当前选格执行一次动作的入口。录制/受控夹具顺序为 `_focus_field` → 等镜头完成 → `_select_cell` → `_select_crop` → `_select_tool`，不能保留旧“武装工具再点整田”的流程。
- 正常按钮额外保存按下时的田/格/工具快照，释放时再次校验；失焦、镜头、设置、取消会清掉快照。按下/释放跨格、拖动、UI 遮挡、双击、过渡中输入不会误操作。Esc/右键先清格，再返回全景；换田、全景与布置清格。

## 当前验证

仅使用隔离 `.local/verification` 农场和 preferences，以及注入 UTC；未触碰真实存档或用户 PID 74488。

| 测试 | 结果 | 覆盖 |
| --- | --- | --- |
| main.gd headless check-only | 无解析错误 | 当前接口与依赖编译 |
| farm_grid_layout_test.gd | 107/0，exit 0 | 96 格坐标、沟两边界、边缘拒选、独立湿土、邻株保留与选格轮廓 |
| farm_storage_scene_test.gd，headless | 17/0，exit 0 | cell_06 收获、真实替换失败、窗口保留、重试不重复奖励、重开/离线/坏档恢复/较新版保护 |
| ui_settings_scene_test.gd，headless | 37/0，exit 0 | 选格与设置互斥、独立设置、故障重试、农场错误覆盖设置、UTC 生长 |
| farm_interaction_test.gd，原生 Vulkan | 62/0，exit 0 | 16 空格中心实际点击、混种/选菜/单格湿土/单格收获、邻格保留、跨格/拖动/失焦/镜头/UI 防误操作 |

故障测试中的只读文件/损坏文件警告是预期证据。原生测试是当前正式 main 场景真实 Input.parse_input_event 链路（含原生种子下拉键盘选择），不是直接 emit 控件信号或伪造点击结果；不冒称已完成发行包实测。

```powershell
./scripts/godot.ps1 -Action Run -ExtraArgs @('--headless', '--script', "$PWD/tests/farm_grid_layout_test.gd")
./scripts/godot.ps1 -Action Run -ExtraArgs @('--headless', '--script', "$PWD/tests/farm_storage_scene_test.gd")
./scripts/godot.ps1 -Action Run -ExtraArgs @('--headless', '--script', "$PWD/tests/ui_settings_scene_test.gd")
./scripts/godot.ps1 -Action Run -ExtraArgs @('--script', "$PWD/tests/farm_interaction_test.gd", '--', "--screenshots=$PWD/.local/verification/grid-input/native-pilot")
```

原生截图目录 `.local/verification/grid-input/native-pilot/`：01 全景，02 同田青菜/白萝卜与单格湿土，03 独立阶段，04 紧凑窗口。02/03/04 已目视，细沟与格选框可见，960×600 下工具未越界；当前相机全景 yaw25/pitch28/distance31/FOV29，聚焦 pitch40/distance10.4。所有 16 格都通过真实土面点击（含空格），不因最低行被遮挡而跳过检查。

单格作物世界尺寸与资源阶段比例保持，不为低视角放大成整田；单格成熟收获只加一篮。测试使用受控 UTC 演示不同阶段，不假称真实等待生长时间。保存故障、坏档等在隔离目录实际制造，用户原档与 PID 74488 未操作。自有 headless/原生测试均已正常退出，GPU 已释放；桥资产导入与后续调色属于根代理整合范围，本代理未擅自 Import。

## 文件归属

本代理修改 `Game/scenes/main.gd`、`farm_layout.gd`、`farm_hud.gd`；适配 `tests/farm_interaction_test.gd`、`farm_storage_scene_test.gd`、`ui_settings_scene_test.gd`，新增 `tests/farm_grid_layout_test.gd`。FarmState/Store 与其迁移为状态代理所有，相机/前景/FocusDetail 为视觉代理所有，其他全场景/性能/录制夹具由根代理及其指派代理适配。未提交，根代理统一收口。

## 发行入口与候选版本准备

按根代理追加授权，`Game/project.godot` 仅版本改为 `0.1.0-rc.3`（保留根代理的阴影设置），`Game/export_presets.cfg` 的文件/产品版本改为 `0.1.0.3`，`scripts/package-release.ps1` 默认版本改为 rc.3。实际包材入口是 `发行材料/版本说明.txt`，已增加 rc.3 逐格混种、v3 迁移、构图/景深/材质/石桥变更并保留 rc.2 历史；未创建不会被打包的同名 Markdown。文案明确最终候选构建与独立发行验收尚待完成。

`发行材料/使用说明.txt` 与 `Game/ui/game_menu.gd` 操作页已删除旧“工具打勾后点整田”说明，改成点击格子后按钮直接操作，说明单格收获和旧作物迁入第 2 行第 2 格。菜单测试不依赖该旧句，未改弱布局断言；`game_menu_test.gd` headless 41/0、exit 0。包脚本 PowerShell AST 解析通过，修改范围 `git diff --check` 通过。

审查 `start-isolated-game.ps1`、`native-game-window.ps1`、`native-game-lifecycle.ps1`、`release_startup_probe.ps1`、`package-release.ps1` 与 `check-release-pack.ps1`：没有旧农场 v2 或整田作物断言。PCK 检查的版本 2/3/4 是容器格式，不是农场存档版本，保留。隔离启动与原生截图/点击助手已有外部 `GamePath` 和进程元数据匹配；lifecycle/startup 仍限定仓库普通导出路径，不能冒称适用任意外部候选。没有为了本轮扩展通用测试接口，也未提前构建或启动候选。

后续独立候选原生操作建议：启动新的隔离 profile 后先截客户区；全景点空大田，待镜头停稳重新截屏，再点击田床第 1 行第 1 格中心。以可见窄沟内土面的中心为准，不沿用旧全景坐标或点叶片。随后在底部种子下拉选青菜并点播种，点相邻第 1 行第 2 格选白萝卜并播种，再回第 1 格浇水；每步都不需要第二次世界点击执行。原生助手 X/Y 是客户区像素，必须按该次实际窗口截图定位，不能将 1280×720 测试截图硬套到全屏或高 DPI。可参考本次 02/03 截图辨认种子与动作按钮，但新构图冻结后仍需确认实际位置。

保存核验路径为 `farm.fields.field_01.cells.cell_01` / `cell_02`，检查相邻不同 crop_id、仅目标 watered、关闭重开保持；受控离线夹具也应只改目标格的时间。普通包测试不能读取旧 `field.crop_id` 或以一次收获清空全田作为通过。真实候选的后续验收由根代理统一安排，本交接的原生 62 项仅对应引擎直接运行正式场景。

## 布置遮挡补修

后续真实布置回归发现新 28m 全景下 ground_04 投影落入 Lantern 按钮。相机代理提供 `set_decoration_framing(active)` 临时取景，本代理将 main 的 `mode_changed` 接到 `_on_decoration_mode_changed`：统一清输入/选田/选格/工具，切换临时取景并刷新 HUD；显式全景/复位先结束布置。预览取消保留布置取景，设置覆盖与关闭也保留当前布置模式，不会把临时姿态写进农场。

新增 `tests/decoration_framing_scene_test.gd` headless 12/0、exit 0，实际隔离证据 `.local/verification/decoration-framing-181179/`。覆盖聚焦返回过渡中进入布置、结束恢复用户全景目的姿态、快速重入/重复结束无累计偏移、复位、设置开关、Esc 输入及农场状态不变。该测试不冒充实际槽位可点验证；原生 32 项及紧凑窗口 ground_04 由状态代理在相机代理释放 GPU 后复验。此补修新增测试在 Game 目录外，不进入发行资源；无额外 UI 布局变更。

后续相机代理改成固定布置姿态（yaw25/pitch34/distance31、point(0,-.95,0)），状态代理已完成 38/0 原生复验，含八槽、960×600 地面03→04移动和失败保存/重试/重开。该结果由对应代理实测交接，本代理未重复占用 GPU。

## 性能采集器竞态补修

根代理首轮 `.local/verification/grid-performance/4k/` 在状态文件替换空隙遭遇 FileStream.Open 的 FileNotFound，采集器退出 1；finally 只结束它持有的测试进程句柄，PID56596 已只读核实退出，stdout/stderr 与部分原始数据保留。这轮中断不能算完整 4K 验收，也不是帧耗时超标结论。

按根代理追加授权修改 `tests/run-performance-validation.ps1` 的 `Read-EvidenceJson`，只对打开阶段 Win32 错误 2/32/33 最多 8 次尝试、间隔25ms（总睡眠最多175ms）。保持 ReadWrite|Delete 共享，其他 IO 错误、读取失败与无效 JSON 原样报错，不返回旧状态或过滤样本。采集标准、阈值、GPU脚本与结果计算未变。

隔离 `.local/verification/collector-race-fix/verify.ps1` 从实际生产脚本 AST 提取读函数，5 项通过：旧单次打开可复现75ms文件重命名缺口，新读函数恢复该缺口及真实 Windows 短共享锁，无效JSON报错，永久缺失约211ms后报错。原始结果为 `results.json`。另尝试高频.NET覆盖写入器时，写入端遇Windows删除共享失败，该额外试验未计入通过结果，失败试验脚本保留为 `verify.ps1.atomic-writer-failed.txt`；没有因此扩大读重试错误范围。文档 `docs/development-setup.md` 采样入口段已同步经验。根代理正在新目录 `4k-complete` 重测，本补修不借其尚未结束结果声称通过。
