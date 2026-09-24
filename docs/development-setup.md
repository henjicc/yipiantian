# 开发前准备与环境验证

> 环境首次核验：2026-09-16。本文保留按日期记录的开发经验；rc.x、早期存档格式和旧测试数字只描述对应历史基线。当前版本以 [Game/project.godot](../Game/project.godot) 和 [Releases](https://github.com/henjicc/yipiantian/releases) 为准。

## Godot 安装与日常入口

- 当前使用由 Codex 下载配置的 **Godot 4.7.2 标准版（非 .NET）**；本机 `--version` 为 `4.7.2.stable.official.ed1daf0bf`。用户另放在 D 盘的副本不使用、不由本任务删除。
- 安装目录：`%USERPROFILE%/AppData/Local/Godot/4.7.2-stable/`。GUI 为 `Godot_v4.7.2-stable_win64.exe`，自动化入口为同目录 `Godot_v4.7.2-stable_win64_console.exe`。
- 本机桌面已创建 **我有一片田 - Godot** 快捷方式，直接打开正式 `Game/` 工程。它属于本机入口；换电脑使用 README 命令或重新创建快捷方式。
- Windows x86_64 的 debug / release 模板安装在 `%USERPROFILE%/AppData/Roaming/Godot/export_templates/4.7.2.stable/`，未安装其他平台模板。引擎与模板来自 [官方下载页](https://godotengine.org/download/windows/) 及 [对应发布](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)，两个下载包均通过该发布 `SHA512-SUMS.txt` 校验。
- 本机软件路径只记在本文，工程启动脚本通过用户目录和根 [.godot-version](../.godot-version) 定位，不把账号路径写死进游戏。换位置时传 `-GodotPath` 或设置环境变量 `GODOT_EXE`，精确版本不符时入口拒绝执行。
- 标准版包含脚本编辑器、调试器和 CLI，打开编辑器及导入无需 .NET SDK 或 AI 服务。`Run` 和 `ExportWindows` 会编译 Windows 桌面组件，开发机需 CMake、Visual Studio 2022 C++ Build Tools 与 Windows SDK；玩家无需这些制作工具。
- 从仓库根目录调用 `pwsh -NoProfile -File scripts/godot.ps1 <Editor|Import|Run|ExportWindows>`。导出结果为 `.local/builds/windows/` 下的 `Farm.exe`、`Farm.pck` 与 `FarmDesktop.exe`，三个文件应一起保留。正式发行从固定提交调用 `scripts/package-release.ps1`，或手动触发 [Windows 发行工作流](../.github/workflows/release-windows.yml)；发行附件与源码仓库分开。
- Windows 图标有两处配置：`Game/project.godot` 的 `config/windows_native_icon` 用于运行时任务栏，`Game/export_presets.cfg` 的 `application/icon` 用于导出程序，均指向包含 16～256 像素尺寸的 `Game/art/ui/game-icon.ico`。从现有 PNG 重建时可运行 `magick Game/art/ui/game-icon.png -define icon:auto-resize=256,128,64,48,32,16 Game/art/ui/game-icon.ico`；只改通用 `config/icon` 不会更新 Windows 原生图标。
- `.local/builds/` 与 `Game/.godot/` 可从源码重建。本地发行候选的 `source/` 是逐版独立构建副本；确认包、ZIP、校验和及 `evidence/` 完整后，可在**新候选构建时**使用 `-PruneBuildSource` 仅移除该次副本并保留记录。历史包与证据逐项核对后再清理；`ArtSource/` 和 `制作留档/` 可能含唯一资料，不当作缓存。

## 工程基线与验证边界

### 当前开发迭代约定（2026-09-17）

- 早期开发不承诺旧存档兼容；不为历史数据新增迁移分支或兼容测试。下文旧版本迁移和测试数量仅为历史记录，不构成每次改动的必跑清单。
- `./scripts/godot.ps1 -Action Run` 自动关闭命令行项目路径精确匹配的开发游戏并重启，默认静音、右侧第二屏独占全屏。排除编辑器、隔离测试、录制和其他项目。无需手工找 PID，也不重复请求重启确认；仅文档改变可保留已确认的最新全屏实例。
- 本机副屏是 Godot 屏幕 0，3840×2160；开发入口的临时 `--dev-preview` 覆盖旧窗口偏好，避免 `--fullscreen` 被设置加载改回窗口。就绪必须收到 `DEV_PREVIEW_READY screen=0 mode=4` 且实际窗口存在；日志与本次 PID 位于 `.local/dev-preview/current.json`，仅用于本地诊断。
- Debug 游戏点击右上角时钟可展开时间滑块，范围 00:00–23:59；拖动同步更新时钟与昼夜光照，点击“恢复实时”回到系统时间，“收起”只关闭面板。预览不改系统时间、作物生长或存档，重启恢复实时。
- 本次仅运行 `tests/debug_time_preview_test.gd` 的原生场景定向检查，覆盖真实时钟点击、滑块拖动、自由镜头输入隔离、日夜变化、恢复实时和开发全屏；通过后观察正午／夜间截图，并实际验证旧实例关闭与新实例就绪。未重跑全场景、资产、性能或旧档测试。复核入口：`./scripts/godot.ps1 -Action Run -ExtraArgs @('--script', (Join-Path $PWD 'tests/debug_time_preview_test.gd'), '--', '--dev-preview')`。

- 2026-09-17 的历史基线：`Game/project.godot` 使用 GDScript 标准版，Forward+ / Vulkan，当时为1280×720可调整普通窗口；当轮改为96格独立状态并重做光影构图。当前配置与玩法请直接检查工程，不沿用这组早期数字。
- 模型交接采用显式 GLB；项目关闭 `.blend` 自动导入，编辑源文件保留在 `ArtSource/`。
- 已核验版本、完成资源导入和 Windows x86_64 release 导出，过程退出码为 0。工程直接运行、导出后的独立程序均以 Forward+ / Vulkan 在 RTX 4090 上启动，并在指定迭代数后正常退出，日志无错误。本地日志为 `.local/logs/godot-run.log`、`godot-player.log`；仅证明空工程启动与导出链路可用，不代表画面、窗口交互、玩法或性能验收。
- 当轮尚未配置 CI 或第三方测试框架。纯 headless `farm_state_test.gd` 237项、`farm_store_test.gd` 289项、`decoration_state_test.gd` 47项均0失败；覆盖当时的逐格隔离、v1/v2迁移、原件留存、坏档和写入失败。实景回归、普通发行包和性能在各自版本另验，不复用旧数字。
- 历史原型 Godot 4.7.2 / RTX 4090 的输入路径已验证点田、GUI 返回、拖动不误选、失焦取消、快速换田、恢复微调和紧凑窗口布局。普通 Windows release 随后另做三次真实进程的播种／浇水、关闭、离线成熟、收获和再次重启，隔离主档保留空田与一篮收获，三个进程均退出0；这是存档闭环证据，不代表完整内容或低配性能通过。
- 旧 `Game/` Unity 工程、`.local/unity-validation/`、`.local/foundation/` 与根 Unity 日志已按用户要求删除。Unity / Hub 软件保留，当前工程不再依赖它们。

## 已有工具环境

| 工具 | 状态与用途 |
|---|---|
| Windows / 硬件 | Windows 10 Pro 19045，64 GB、RTX 4090；开发机不能代替低配测试 |
| Git / PowerShell | Git 2.51.1、LFS 3.7.1、PowerShell 7；仓库级 LFS 已配置，远端为 `henjicc/yipiantian` |
| 编辑代码 | Godot 内置脚本编辑器即可；VS Code 已安装，外部补全与断点未验证，不是开工前置条件 |
| Blender | 5.2.2 LTS；官方 Lab MCP 1.0.3，独立 AI 工作区，见下文 |
| Tripo | 插件 0.2.2 + CLI 0.4.0；青菜经 Blender 整理后已接入 Godot 原型；最终美术与性能验收待做 |

可选 VS Code 集成使用 [Godot 官方组织的 Godot Tools](https://github.com/godotengine/godot-vscode-plugin)，需要编辑器侧语言服务时按其文档配置；不安装旧 Unity 扩展作为 Godot 依赖。

## 可复用的开发经验

农事输入验证：`& ./scripts/godot.ps1 Run -ExtraArgs @('--script', (Join-Path $PWD 'tests/farm_interaction_test.gd'))`；截图参数在 `--` 后传 `--screenshots=<预先建立的绝对隔离目录>`。当前契约为点大田聚焦→镜头到达→点小格→选作物／点工具按钮，按钮直接操作当前格，不再武装工具后点土执行。Esc／右键先处理弹窗或装饰预览，农田内先清格选择、再回全景；中键转动、Shift＋中键平移、滚轮缩放。工具按下／松开绑定同田同格，拖动、失焦、镜头移动与模态界面不能补发动作。历史43／44项整田检查属于旧版，新夹具须通过实际原生窗口再记录结论。

本机 Godot 4.7.2 弹窗测试：场景输入用 `root.push_input(event)`，原生 PopupMenu 键盘事件须设置 `window_id = popup.get_window_id()` 后经 `Input.parse_input_event(event)` 分发。鼠标打开下拉时焦点可能为 -1，第一下 Down 才到第一项；读取实际焦点后导航，不直接发选择信号冒充用户输入。Esc 关闭弹窗及第二项选择已在实际窗口验证。

纯农场规则验证：`& ./scripts/godot.ps1 Run -ExtraArgs @('--headless', '--script', (Join-Path $PWD 'tests/farm_state_test.gd'))`。规则从调用者接收 UTC 秒，测试不改系统时钟或玩家存档。状态与静态定义返回深拷贝，无效动作在候选副本结算后拒绝，整个权威状态不变；自然时间推进调用独立 `settle()`。界面不要将结算的 `changed_fields` 非空等同于模型阶段变化，空格时间基准也会更新。`get_field(id)`返回包含16个派生格状态的cells字典；`get_cell(field,cell)`返回具体格，动作必须显式传cell_id。状态与迁移边界见[逐格交接](task/格子农田与画面重构/handoffs/种植状态与迁移-handoff.md)。

Godot 4.7.2纯测试经验：`--script ../tests/...` 的 `resource_path` 可为 `res://..`，夹具根应以 `ProjectSettings.globalize_path("res://../").simplify_path()` 定位工程外 `.local/verification`，不能直接把资源URL当磁盘目录。JSON版本数字读取为float，接受已支持版本使用明确数值相等比较；数组membership对int／float的区别可能使有效版本被误判不支持。以上均由v3实际保存重载修复验证。

磁盘和场景恢复分别使用 `tests/farm_store_test.gd`、`tests/farm_storage_scene_test.gd`；所有测试先注入 `.local/verification/` 下独立存储，再把主场景入树。正式存档为 `user://farm/`，Windows默认位于 `%APPDATA%/Godot/app_userdata/我有一片田/farm/`。未知版本、损坏或写入失败不能当首次启动，具体恢复与重试语义见 [2.3交接](task/首个可发布版本/handoffs/2.3-handoff.md)。

当前外壳为v3，仍显式保存 `farm` 与 `decorations`。farm恰好六田，每田16格，各格独立作物／生长／浇水／UTC；v1／v2的真实旧田结构只迁到cell_06，其他15格为空并保持旧田时间基准，累计不翻倍。v2装饰原样保留，v1按累计推导解锁但不摆放。第一次写入v3前保留 `farm.v1.<SHA256>.json` 或 `farm.v2.<SHA256>.json` 不可变原件，原件冲突和写入失败不能静默通过。96格长数值实测45,029字节，维持64KiB读取上限。界面偏好仍单独保存。旧v2／整田源码与候选不能作为当前格式的验收。

正式装饰槽的可见性用环境实际网格的 `TriangleMesh` BVH 与 AABB 预筛判断，不穿透屋顶或树叶。启动时构造共享网格缓存，布置／镜头事件只查询，不每帧重建；本机八槽热查询合计904微秒，原约64毫秒的冷构造已移出点击路径。切换 Mesh 实例或资源时需刷新缓存；仅自动 LOD bias 改动不改变引用。

昼夜／声音验证入口为 `tests/atmosphere_test.gd` 和 `tests/atmosphere_scene_test.gd`，后者同时检查主场景窗灯的昼夜连接。前后台观察不暂停农场计时；后台音频暂停、帧率最多15，回来恢复用户设置。`day_night.gd` 接管水面的 `material_override` 并同步远景及水反射的昼夜色，不能只替换被 override 遮住的表面材质。音轨来源、响度与循环证据见 [3.4交接](task/首个可发布版本/handoffs/3.4-handoff.md)；主观听感未由模型验收。

质感修订（2026-09-17）：本机4.7.2的荷叶黑点经同镜头逐项排查，关闭灯光角直径后消失；提高模型LOD、增大bias、改双面投影均未解决。采用角直径0的PCF、滤波质量5和blur2保留真实柔边阴影，避免继续用大bias掩盖问题。[Godot光影文档](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html)与[薄表面PCSS问题记录](https://github.com/godotengine/godot/issues/113976)作为排查参考；本机截图证据在 `.local/verification/surface-review/shadow-tests/`，不外推为所有设备的引擎结论。

水面修订（2026-09-17）：用户指出岛屿像浮在平面上、水不像水。旧深度接触只覆盖陡直岸壁的极窄区域，淡灰绿底色与极弱波光又使水面像地板。当前采用青瓷绿淡彩、断续移动短波光、浅水色带、浸水暗边及向外扩散的岸边／船边涟漪。`presentation/water_contacts.gd` 在院落建立后，从真实岛岸、岸石、桥墩三角形与水位 −0.25 的交线烘一张 512² RF 距离场（世界 XZ ±24 米，存平方距离，上限2.4米，纹理1MiB），不每帧计算、不新增物理流体或玩家存档。世界坐标场让陡壁和屏幕外岸线仍有连续过渡；新增或移动静态水岸后须重建场景，水位／世界范围变化须同步生成器与材质。`day_night.configure` 替换水材质时必须带上距离场与启用标记；独立氛围样例没有岸场时禁用该层。

原24步屏幕追踪倒影经同机位开关实拍确认会在岸边生成层层细线，现移除，保留柔和天空反射；局部物体通过真正位于水下的屏幕颜色表现短距离浸没，随深度吸收，不能称为完整物理倒影或折射。深度仍按 [Godot 4.7 逆投影方式](https://docs.godotengine.org/en/4.7/tutorials/shaders/advanced_postprocessing.html)还原世界坐标；[屏幕纹理文档](https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html)说明其只含不透明阶段，因而不能用它获得其他透明水体或屏幕外物体。开放船舱的保守遮罩及船边波纹共用实际船变换，保留完整晃动包围检查，不能仅抬高船。

证据在 `.local/verification/water-review/`：before／pass1／pass2-no-ssr／final 保存对照；最终完整场景219项、表面整合24项、大气42项、岸线计算11项通过。`tests/water_contacts_test.gd` 验证旋转缩放的垂直岸壁、距离衰减和全干／全淹几何；`tests/surface_integration_test.gd -- --output=<隔离目录>` 用60秒采样检查船岸相交与遮罩变换，保存多相位图。表面测试旧篮底像素区因上轮桌篮搬动已变成空地，现按实际篮底修正，保留原暗化阈值。左右近景、昼夜与低画质已目检；渲染探针在改前也存在的12个ObjectDB／6个资源退出警告仍在，不把它当成新增水材质错误。RTX4090、1920×1080、同一左岸机位、相同高画质与水色，各60帧前台GPU中位旧4.321ms／新2.219ms；只证明本次局部短测，非全场景／低配／长期性能验收。审美仍待用户评价。

分层远景与氛围修订（2026-09-17）：用户要求远、宽、平的湖面空间，并否定了中途山体过大、背景像弯起的版本。正式替换为原生透明的远山／丘陵／柳岸三种淡彩图片，按原始比例缩小后横向排布，在舞台 Z −380／−310／−240 拉开距离；主屋后仍有连续低对比的远岸，不以放大树林填空。素材、实际提示词和来源见[远景资产记录](../ArtSource/Environment/Backdrop/README.md)。运行中舞台仅同步相机偏航，不缓动、不扭曲图片UV；相机俯仰仍改变取景。固定倾斜背景在侧视时岸线会滚斜，原水面径向淡出又让两侧先露底，二者会造成弯曲湖面的错觉；现岸线始终水平，水面按观察方向的平面纵深10–18米淡出。修改镜头边界必须检查默认视角与两侧极限，不能只确认画面不露底。

标准画质全景景深强度0.055，按六田及作物高度包围范围保留清晰带；聚焦强度随接近程度渐入到0.032，只虚化操作范围之外。低画质和景深关闭继续有效。48米之后采用深度雾，山岸另有逐层雾色和一层缓慢流动薄雾；没有启用体积雾或其时域重投影。傍晚压低天空、山岸与环境补光，保留暖窗灯和菜地细节。参数语义核验自 [Godot 4.7 Environment](https://docs.godotengine.org/en/4.7/classes/class_environment.html) 与 [CameraAttributesPractical](https://docs.godotengine.org/en/4.7/classes/class_cameraattributespractical.html)，具体效果以本机4.7.2实景为准。荷花浮动峰峰值约4.8厘米，并有约3厘米范围的平移、约1.6度侧摇及更明显的叶片风动，原尺寸、岸边位置与根部约束保留。

最终证据位于 `.local/verification/cinematic-atmosphere/wide-*`；`pass1/pass2/final` 是本轮被后续反馈否定或替换的中间版本，不能当最终验收。植物呈现156项包含六田清晰带、远景覆盖与水平岸线的极限镜头检查；完整场景219项、大气46项、生活动态26项、表面整合24项通过。表面测试从夜景切回日景时，仅等待0.15秒在后台只渲染两帧，天空辐照与SSIL尚未稳定，曾把接触暗化读成−0.0035；现开／关AO各等待12个实际绘制帧再采图，保留原暗化阈值，复测通过。渲染器已有的12个ObjectDB／6个资源退出警告仍可复现。短测发生于后台15fps限制下，不能用作前台性能或帧率结论；未做低配及长期性能验收。画面仍待用户主观评价。

草土融合采用渐低土畦、顶点颜色混合、根部贴花和短草几何四层配合；普通田格的身份与碰撞不依赖视觉网格。短草合并绘制、局部风动，根部贴花只投到岛顶层，保留路径／田格／装饰空间。思路参考[《对马岛之魂》团队的程序草与统一阵风说明](https://blog.playstation.com/2021/01/12/how-stunning-visual-effects-bring-ghost-of-tsushima-to-life/)，未复制其资源或宣称实现相同渲染系统。

接缝与接触暗部复核（2026-09-17，rc.5）：用户指出rc.4土面仍有马赛克，不能把上面的草土方案视为美术签收。同镜头关闭旧土材质NORMAL_MAP后块状高光消失；原程序网格未生成切线却使用切线空间法线，且凹凸噪声偏强。根据[SurfaceTool文档](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html)，此路径须生成切线；当前改用世界坐标高度梯度直接构造法线，地面与畦边共享 `terrain_surface.gdshaderinc` 的颜色与法线。格沟深度缩至4毫米，土面外缘与畦边齐平；布局测试直接检查接缝高度，防止露出下层草地；隔离夹具恢复旧0.064高度时该断言失败，正式0.076高度通过。

画面基线与色调（2026-09-17，rc.5）：用户指出实机与固定 v1 参考图质感差距大。对同机位实图做逐像素统计，得到可核验的偏差：暗部像素（亮度<0.15）参考0.69%、实机0.003%；亮度p99参考0.928、实机0.991（线性色调映射把亮部切平）；无细节面积参考5.0%、实机41.6%；冷暖(R−B)均值参考+0.140、实机+0.022，其p10参考−0.020、实机−0.133。据此判定主要差距在明度结构、信息密度与色彩方向，不是缺少水墨后处理。

按上述数据改为：AgX 色调映射（曝光1.30、agx_contrast 1.45、agx_white 8.0）替换线性，保留高光滚降；日间环境光由0.18~0.24降到0.10~0.15、天空贡献0.72→0.50、SSIL 0.35→0.22，把填充光让给主光；`ProceduralSkyMaterial` 四个颜色改为随时钟插值，原先固定冷天空占七成环境光，使黄昏也偏冷；阴影blur 2.0→1.1（角直径仍为0，不回退PCSS黑点修复）；`adjustment_color_correction` 用 `GradientTexture1D` 做逐通道暖偏；水面颜色改由时钟提供并整体提亮去饱和，水的漫反射系数0.40→0.78，使开阔河面回到构图中的浅色负空间；镜头前景压暗放大并移到画面下角内侧，作为画面唯一的深色锚点。改后同机位复测：暗部0.212%、p99 0.9268、冷暖均值0.101、其p10 0.000，黄昏组的p1、p99、饱和p90与参考基本一致。[Godot环境与后处理](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)说明线性会不自然地截断亮值、AgX在高亮度下保持色相，`tonemap_agx_contrast`／`tonemap_agx_white`／`adjustment_color_correction`／`ssao_ao_channel_affect` 均已在本机4.7.2用 `Environment.get_property_list()` 实测存在。剩余差距仍大：无细节面积45.5%、细节密度0.0404对参考0.0760，属于资产密度与贴图问题，不能靠光照参数解决。证据在 `.local/verification/tone-pass/`（00-baseline 到 04-framing 同机位同夹具对照）。

信息密度与田块可读性（2026-09-17，rc.5 第二轮）：光照调整后剩余差距集中在信息密度——无细节面积45.5%对参考5.0%、细节密度0.0404对0.0760。实机放大核对发现田块问题不是作物尺寸（成熟青菜0.438×0.480米，格距0.60×0.44米，本已接近相接），而是作物、土面、草地三者亮度几乎相同，互相读不出来。据此：土色由 `80684d` 改为 `6a5033`、湿土 `62533e` 改 `4c3a24`；`plant_wind.gdshader` 的叶片色偏由 `(0.85,1.14,0.94)` 改为 `(0.74,1.20,0.83)`，并对识别为叶片的像素加一段中间调压深，白萝卜肩部、花和葫芦不受影响。六块田各加一圈共享的程序化压边石（`farm_layout._coping_kerb()`，一份网格六处复用，纯装饰、不参与碰撞与格子判定）。院内石板路原为未着色的模块本色，实机是全岛最亮的物体，已统一改为暖灰。

`living_details.gd` 增加十组院落摆件（水缸、柴垛、石磨、陶罐组、晾晒簸箕含辣椒、叠篮、木桶、矮晾晒架、瓜堆、育苗框），复用原有 `_lathe`／`_basket`／`_tray`／`_beam` 工具并按材质合并绘制。首轮实机核对发现三处摆放错误并已修正：石磨落在廊台范围（廊台 x −2.8~4.1、z −2.975~−1.825）内、柴垛落在侧屋范围（x −5.6~−3.0、z −6.25~−3.75）内、高晾晒架与廊台栏杆在画面上重叠；摆件位置须同时避开六块田、八个装饰槽、石板路线和这两个建筑基底。摆件不含碰撞体，不影响田块拾取。

第二轮复测（`.local/verification/tone-pass/08-paving/`）：黄昏组暗部0.684%对参考0.687%、p1 0.163对0.169、p99 0.9268对0.928、亮部7.03%对8.20%、饱和p90 0.545对0.514、冷暖均值0.150对0.140，即明度与色彩两个维度已基本对齐。正午组暗部0.365%、细节密度0.0414。剩余无细节面积42.9%仍远高于参考，主要来自开阔水面与天空，属于下一轮水面／远景工作，不能宣称构图信息量已达标。同源码1080p性能烟测164项通过，可见图元由1789707增至1824117（+2%），GPU中位数仍在2.6~5.6毫秒区间，无回归。

田块石边与接触暗部（2026-09-17，rc.5 第三轮）：用户指出压边石"一模一样"且难看，以及杆子与地面接触生硬。压边石原为本仓生成的倒角方块，同一拓扑只改长宽高，放大后必然读成一串一样的面包；改为复用已有的 `art/environment/modules/stone_0..4.glb` 五个 Blender 岸石，按全 360 度偏航、混合形状、不等埋深、少量缺口与偶发小石拼成，全部 `SurfaceTool.append_from` 合并为一份网格供六块田复用（不重新生成法线，保留原始大切面）。远近两档实机对照后定为低平而非圆石：缩放约 0.34~0.46 × 0.30~0.43 × 0.21~0.28，基色 `6f6c5b`；早期较高较亮的版本在全景里读成一圈白色卵石。

接触暗部的关键结论：**Godot 的 SSAO 在结构上画不出细立柱与地面的接触**。用 `Viewport.DEBUG_DRAW_SSAO` 灰度缓冲配合 ssao 开/关、radius 0.18／0.09／0.05 三档实拍对照（`.local/verification/tone-pass/ao-probe/`）：最大亮度差可达 0.43~0.61，但全部落在器皿、簸箕、石头这类宽底物体和轮廓边缘上；立柱脚下的地面始终无遮蔽，因为 SSAO 在 `ssao_radius` 半球内求平均，3 厘米的杆子占的立体角太小。把半径继续缩小只会让遮蔽退化成轮廓描边。因此 SSAO 收到接触尺度（radius 0.18、intensity 3.4、power 1.6、horizon 0.035、detail 1.0、light_affect 0.75）用于宽底物体，另加 `presentation/contact_shading.gd` 投影接触暗池补细立柱。

`contact_shading.gd` 从真实顶点位置提取接触：对注册节点的每个 surface，取落在给定世界高度 ±区间内的顶点（下探 0.16 米、上探 0.10 米，因为立柱常埋进地面，且圆柱在穿过的高度上没有顶点），按 0.20 米网格聚类，按聚类展布决定半径与强度（细立柱强、宽底弱，避免与 SSAO 叠成脏斑），烘进一张 1024² RGBA 贴图并生成 Decal。本院落有两个承载面：地面 0.132 与廊台面 0.41，各烘一张、各用薄盒投影，避免地面暗池跑到廊台边缘上。Decal 的 `cull_mask=2` 是接收层，因此 `_apply_pigment` 把 `veranda` 和 `island_bank` 一起放进第 2 层。注册表在 `courtyard.CONTACT_MODULES`；新增会落地的模块要一并加入，否则它没有接触暗池。

1080p 性能烟测 164 项通过，可见图元 1824117→1928589（+5.7%，来自压边石）、峰值工作集 959→975 MB（两张 1024² 贴图），GPU 中位数仍在 2.2~5.2 毫秒区间。

用户描述的“物体靠近产生暗部”主要对应环境光遮蔽，和光源投影、接触阴影不是同一机制。[Godot Environment](https://docs.godotengine.org/en/4.7/classes/class_environment.html)提供SSAO与SSIL；[UE RVT](https://dev.epicgames.com/documentation/unreal-engine/runtime-virtual-texturing-quick-start-in-unreal-engine)是地形／材质数据混合的一种实现，也需要材质及体积配置，不是任意相交模型自动融合开关。当前采用共享世界坐标材质、窄幅基脚风化贴花与SSAO；不引入新的地形插件或完整GI系统。

当前SSAO使用高质量、全分辨率，半径0.42米，强度1.8、power1.4；阳光区0.65影响属于美术增强，不是物理接触阴影。4.7.2 [Forward+实际着色器](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl)还用AO-channel mix插值直接光影响，因此同时设channel affect为1，并用实际成片核验。灰度SSAO检查确认篮底、柱脚、台阶有遮挡；开关对比及固定近景像素断言验证最终图确有适量暗化（篮底平均亮度降低0.0756、柱脚0.0348，以0–1表示）。SSAO仍受屏幕外信息、深度和视角限制，不能代替正确落地、法线、模型连接或烘焙遮蔽；保留建筑硬质轮廓，不能用全局模糊掩盖接缝。

当前独立证据放 `.local/verification/contact-review/`：baseline保留旧NORMAL_MAP开关对照，surface保留荷叶、船、昼夜与接触AO开关图。田格输入62项、格子布局108项、表面整合22项、完整场景219项通过，存档规则未修改。4K前台焦点细节51项通过，RTX4090／3840×2160／96株及三件装饰、每组360帧非录屏短测：正常LOD全景GPU中位5.40ms、聚焦5.82ms，带景深分别5.57／6.00ms，低画质4.22ms。该短测不是30分钟稳定性或低配验收，不能沿用下列rc.4数字。首轮4K测试通过console包装启动后未取得前台，触发15fps后台限帧，foreground断言失败；该轮保留在focus目录且不作性能验收。复跑使用ProcessStartInfo直接调用同版本GUI执行文件、CreateNoWindow=true与独立目录，验证前台归属后采样；不能关闭前台断言来掩盖失败。

rc.4历史验证证据放 `.local/verification/surface-review/`：格子布局107项、田格输入62项、植物呈现132项、焦点细节51项、完整场景219项、装饰输入38项、船与表面整合18项、生活细节22项通过。新架子最初遮挡hanging_03，实际点击回归检出2项失败；移到院内挂臂后八槽可见且38项全部通过，未放松遮挡检测。影像覆盖荷叶近景、船多个运动相位、草土接触、满田和昼夜；初期PCSS、倒影、过大船舱遮罩和土畦内缘缝隙的失败画面也保留。

同场景RTX4090原生1080p性能烟测164项通过，103.8秒运行、峰值工作集946946048字节；4K六组各60秒实测56项通过，411.7秒运行、峰值工作集1043873792字节。各组约60帧；精确CPU/GPU、帧时间及前后台记录见 `performance-smoke/` 与 `performance-4k/`。使用当前Godot正式场景和隔离存档，非打包程序、非录屏计时；保留的玩家rc.3窗口在后台，未将这一轮短测描述成30分钟或其他硬件验收。测试时源码SHA-256清单在 `tested-source.json`。

焦点细节入口：`tests/mesh_lod_test.gd` 枚举47件正式GLB，检查真实近／远／回近绘制量与基础／最低档拓扑；`tests/focus_detail_test.gd -- --functional-only --output=<隔离目录>` 检查聚焦、取消、阶段更新及画质切换，不抢焦点，计时不可用作性能结论。2026-09-17已将全局普通对象零偏置修为1、聚焦作物为2，取消模块特判128，保留正常屏幕误差LOD；选型、破面诊断及复核方法统一见[资产流程](asset-workflow.md#lod-与破面验收)。只有明确安排前台性能验收时才运行原有 `--uncapped` 模式。

氛围修订后的全景使用镜头子节点承载边缘植物，并以近／远景深分离前景与山岸；六田实际深度包围范围加余量作为清晰带。聚焦和布置时前景退让，低画质在切换MSAA前立即移除该层并关闭景深。`tests/plant_presentation_test.gd -- --output=<仓库.local下绝对目录>` 使用真实窗口检查根部固定、叶片图像变化、前景退让、画质与景深开关；`tests/living_details_test.gd` 可无窗口核对船体幅度、绳/槽位和生活物件合批。程序草与GLB同时使用顶点风动；必须保留GLB贴图、原Mesh/LOD和根深，不能只让整株节点绕根旋转。棚叶用原贴图绿色顶点遮罩，花盆按高度锁定盆体；`tests/mixed_plant_wind_test.gd -- --output=<仓库.local/verification下绝对目录>` 以实际高低模和相隔帧检查叶动、木架／葫芦及盆体固定。rc.2当时每田16个视觉锚点仍共用一个整田状态，相关历史证据见[整合交接](task/氛围提升/handoffs/整体验证-handoff.md)；当前16锚点一一对应真实cell状态，full fixture必须填满96格而不能只改旧田字段。下段54株性能数字亦仅对应历史版本。

3.5 当时的51项检查通过（以下数字属于院落与水面补修前基线）：54株成熟作物和三件装饰的同场景，全景可见图元772486→432307，聚焦548605→342508；360帧短测中聚焦GPU中位全高2.155ms、仅LOD2.069ms、LOD＋景深2.436ms。标准4×MSAA，低画质2×MSAA且暂不使用景深，保留景深偏好。景深清晰带随整田深度范围变化，同深度旁田不会因身份不同而被强行模糊。数字仅属于本机短测，不能替代4.2的60秒条件采样与30分钟持续验收；详见 [3.5交接](task/首个可发布版本/handoffs/3.5-handoff.md)。

普通发行程序验证入口：`./tests/start-isolated-game.ps1 -Directory (Join-Path $PWD '.local/verification/<本次目录>') -Phase sow`。该入口只给子进程设置 APPDATA／LOCALAPPDATA，持有该进程直到实际关窗并保存日志、退出码和快照；先核对隔离目录中产生了预期主档，再执行操作。Godot 4.7.2 release 本次静默忽略外部 `--script`，不能拿这个参数宣称已跑测试驱动。实际采用普通发行窗口的原生点击与关闭；需截图时 `tests/native-game-window.ps1 -ProcessId <启动器返回PID> -Action capture -Output <绝对PNG路径>`，其 `click` 使用已观察到的客户区坐标，`close` 请求程序正常退出，均限定已知进程。离线夹具仅在隔离进程退出后调整副本UTC基准并保留原件，不能改系统时钟或玩家档。

原型交互检查可在仓库根目录的 PowerShell 会话运行：`& ./scripts/godot.ps1 Run -ExtraArgs @('--headless', '--script', (Join-Path $PWD 'tests/prototype_smoke.gd'))`。不带 `--headless` 可跑有画面的同一组检查。截图参数放在 `--` 后传入 `--screenshots=<已有输出目录>`；截图需有渲染窗口。

Godot 4.7.2 本次验证：headless 测试须显式设置根窗口 / Viewport 尺寸，才能用与实际窗口相同的投影坐标测试鼠标输入，不能依赖默认无窗口尺寸。物理拾取放在 `_physics_process`，UI 未消费的输入进入拾取队列；截图等待 `RenderingServer.frame_post_draw` 再读取 Viewport。已通过当前原型实测；参考 [官方射线指南](https://docs.godotengine.org/en/4.7/tutorials/physics/ray-casting.html) 与 [Viewport 文档](https://docs.godotengine.org/en/4.7/classes/class_viewport.html)。

以下保留本机已验证经验及本轮官方文档核验结论。软件更新后只复核相关条目；新经验及时更新本文件，约束见 [规则主动维护](../rules/rule-maintenance.md)。

| 条件或现象 | 方法与验证边界 |
|---|---|
| 终端找不到已安装工具 | 先核实实际路径与版本，使用绝对路径；不要直接要求重装。当前 Godot 入口不依赖 PATH |
| Godot 全新工程或缺少导入缓存 | 先执行 `--headless --import --path <Game>`；本工程已成功导入。`.godot/` 可再生，`.uid` 和资产旁的 `.import` 要保留 |
| 检查 Godot 命令是否生效 | 对照本机 `--help` 与对应版本文档；未知选项可能静默忽略。`--check-only` 配合 `--script` 只检查指定脚本，不是全工程测试 |
| 用独立脚本修改资源并退出 | 使用 `--headless --path <Game> --script <脚本>`；本机同时加 `--editor` 并在初始化时立即退出曾出现扫描中止与资源泄漏诊断，去掉 `--editor` 后保存正常且退出无错误。需要导入时单独使用 `--import`，不要把这个现象直接归因于游戏资源损坏 |
| 工具外层返回成功 | 继续检查内层诊断与真实产物；曾遇到 Blender `isError=false` 但正文 `status=error`，不能只看协议顶层 |
| 场景脚本中途报错 | 先读取当前状态，补齐尚未生效步骤；此前 Blender 材质步骤失败时网格已创建，不能把多步执行当成事务 |
| 中文 Blender 找不到英文节点名 | 按稳定节点类型定位，例如 `BSDF_PRINCIPLED`；本机实测有效，不强制改用户语言 |
| MCP 中文乱码 | Python 客户端与服务使用 UTF-8；本机 `PYTHONUTF8=1` 已解决路径和名称乱码 |
| 多个工具实例 | 核实工程 / 文件路径、保存状态和端口归属；不凭相似窗口标题操作，不批量关闭进程 |
| Windows 截图接口失败 | Win10 19045 的 `SetIsBorderRequired / 0x80004002` 曾影响 WGC；Blender 可用其官方截图接口。普通发行游戏已由主代理在独立验证流程使用 DPI 感知的 GDI 客户区捕获成功，入口 `tests/native-game-window.ps1`，限定当前发行 exe 路径和已知 PID，并验证前台再点击；不要操作同名旧窗口。该经验不取消当前工具／技能自身的操作边界 |
| 双屏坐标不一致 | 先用 DPI 感知的实际应用核对；2026-09-17 Godot 检测两屏均为 3840×2160，Windows DPI 为 144（150%），先前 2560×1440 属于缩放坐标，不能当作物理像素 |
| PowerShell 长时间无输出 | 先用不加载个人 profile 的调用排查；本机 `login=false` 有效，未擅自修改用户 profile |
| Git LFS 本地与远端取回 | 本地 clean / smudge 往返已通过；2026-09-23 GitHub 发行构建从远端检出 LFS 并逐一核对对象 SHA-256，证据见[构建记录](https://github.com/henjicc/yipiantian/actions/runs/35850639148) |

Godot 命令依据：[CLI 文档](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)；仓库边界依据：[版本控制文档](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html)。

## 成品界面与独立设置验证

Godot 4.7.2 / Windows 10 19045：偏好保存在 `user://preferences/settings.json`，农场仍独立保存在 `user://farm/`；主场景夹具须同时注入 `store` 与 `settings_store` 到隔离目录，避免运行测试改变玩家音量或显示设置。设置 I/O、菜单和场景接线入口分别为 `tests/settings_store_test.gd`、`tests/game_menu_test.gd`、`tests/ui_settings_scene_test.gd`，按既有 `Run -ExtraArgs @('--headless','--script',绝对脚本路径)` 调用。

实际窗口下限由主窗口 `min_size = Vector2i(960,600)` 设置；本版本尝试写 `display/window/size/min_width` / `min_height` 不会改变运行窗口下限。普通发行程序以原生缩窗实测夹持至 960×600；引擎内逻辑布局通过不能替代这项系统窗口验证。中文字体采用用户指定的内置汇文明朝体，中文路径直接导入，来源与原文件哈希见 `ArtSource/UI/README.md`；来源记录随包保留。全局默认通过 `gui/theme/custom_font` 指定，另覆盖共享主题与样片 Label3D，避免系统字体依赖。

历史原生 OptionButton 弹窗验证表明：弹窗会读取 `Input` 的鼠标按住状态；只向根 Viewport 强发 `push_input` 会出现按下打开、松开误关，不能直接判成游戏缺陷。`farm_interaction_test.gd` 改用带实际 window_id 的 `Input.parse_input_event` 后 44 项通过，普通发行程序另以真实鼠标确认选择白萝卜成功。菜单与存档失败遮罩须为当前可见按钮设置循环焦点，防止 Tab 跳到底层农事控件。

普通发行程序测试使用进程级 APPDATA / LOCALAPPDATA 隔离；`tests/native-game-lifecycle.ps1` 读取对应启动元数据并校验 PID、exe 和进程启动时间，只操作所属窗口。4.1 已验证三次正常退出、设置持久化、全屏／窗口、150% DPI、最小化恢复及短时 UTC 回访，证据入口见 [4.1 交接](task/首个可发布版本/handoffs/4.1-handoff.md)。这不等于其他电脑、系统休眠或 30 分钟性能验收。

## Blender 新版对 AI 的实际帮助

建议新资产工作流采用 **Blender 5.2.2 LTS**，保留已有旧版本。官方发布页列出该补丁于 2026-09-15 发布，5.2 LTS 支持至 2028 年 7 月；这替代此前文档中的 4.5 LTS 安装建议。[5.2 LTS 发布页](https://www.blender.org/releases/5-2/)

- **连接能力**：Blender Lab 已提供 MCP 实验方案，要求 Blender 5.1 或更新版本；需要额外的插件、MCP 服务和客户端，Blender 本体没有内置 LLM 连接。可帮助读取场景、执行 Python、检查数据和处理重复操作。[官方 MCP 说明与安装入口](https://www.blender.org/lab/mcp-server/)
- **反馈能力**：5.2 Python API 增加窗口截图像素访问、可读运行报告，以及后台模式初始化 GPU 的接口。这些变化有助于执行后查看、修正；不等于自动建模质量得到保证。[5.2 Python API](https://developer.blender.org/docs/release_notes/5.2/python_api/)
- **版本边界**：旧 Python 脚本和插件不能默认兼容；例如 5.2 修改了 Geometry Nodes 修改器属性接口。新文件另存，旧资产不原地批量迁移；5.x 文件不应假定能由本机 3.x 打开。[兼容说明](https://developer.blender.org/docs/release_notes/compatibility/)

MCP 会执行模型生成的代码，操作范围限定为明确工程及本机连接。批量建模、导出仍可使用 Blender Python / 后台命令；正式资产进入 Godot 前需检查比例、轴向、枢轴和材质。

## 已配置的 Blender AI 工作区

- 软件：`C:/Program Files/Blender Foundation/Blender 5.2/blender.exe`，实际版本 5.2.2 LTS。
- 官方源码固定在 `v1.0.3`，提交 `2cea8d566dde07fbac28a61d698909d69724e853`；插件和 MCP 服务均为 1.0.3。[源码](https://projects.blender.org/lab/blender_mcp)
- 安装根目录：`%USERPROFILE%/AppData/Local/BlenderMCP/`。`official/` 为源码，`venv/` 为隔离 Python 依赖，`profile/` 为独立 Blender 用户配置；原 Blender 场景、偏好和旧版本未覆盖。
- 日常入口：桌面 **Blender AI** 快捷方式，调用该目录下 `Open-Blender-AI.ps1`。启动时使用独立 profile、加载 MCP，并将窗口放到右侧屏幕；重复启动会提示使用已有实例，避免两个服务抢同一端口。
- 官方插件要求 online mode 才能启动本机桥接，因此仅该启动入口带 `--online-mode` 参数，不修改用户普通 Blender 的全局联网偏好。桥接实测只监听 `127.0.0.1:9876`，没有开放公网端口。
- Codex 已通过自身 CLI 注册全局 MCP 条目 `blender-lab`，以 stdio 启动 `venv/Scripts/blender-mcp.exe`；环境明确指定 Blender 路径、回环地址、端口与 `PYTHONUTF8=1`。当前任务的动态工具列表未自动刷新，本次使用标准 MCP 客户端完成真实协议测试；后续重新加载 Codex 使新增工具进入任务列表。
- 最初窗口工具报告双屏 2560×1440、副屏在右，AI 窗口坐标为 x=2640、y=100、大小 1200×1000；这些是当时的缩放坐标。2026-09-17 Godot 录制入口实际核验两屏物理像素均为 3840×2160，DPI 144。后续不要混用逻辑坐标与录制分辨率。

已通过的验证：读取场景与中文名称、创建七个测试网格并配置材质、保存中文路径 `.blend`、导出 FBX、重开保存文件、完整关闭并重启 AI 工作区后自动连接，以及调用 Blender 自身截图接口检查模型。重启后七个对象保留且文件无未保存修改，端口归属为本次 AI Blender 实例。此前导出的是 FBX；Godot 当前采用 GLB，现已另用 Tripo 青菜完成 Blender 整理 → GLB → Godot 原型导入与真实画面检查；这只验证该静态资产路径，不涵盖骨骼、复杂材质或所有模型。

测试文件位于被忽略的 `.local/blender-validation/`，包含 `AI连接验证.blend`、`AI连接验证.fbx`、`blender-window.png` 和 MCP 测试结果。它们用于环境验证，不是正式美术资产。系统窗口截图接口本次报 `SetIsBorderRequired / 0x80004002`，已使用 Blender 官方截图工具取得有效画面，不需要关闭系统安全功能。

2026-09-19 在上述 Blender 5.2.2 可见实例中实测：几何节点修改器的输入值通过 `getattr(modifier.properties.inputs, socket.identifier).value` 读取和修改；旧的 `modifier["Socket_1"] = value` 在该环境报不支持 ID properties。应从 `node_group.interface.items_tree` 按输入名称取得 socket，再使用其 identifier，避免按固定序号猜测。修改后调用对象 `update_tag()` 和视图层 `update()` 再检查求值网格。青菜独立生成器已验证随机种子改变几何、相同种子准确复现，叶数、株高、叶宽、开合、弯曲等输入实际影响结果；此结论只覆盖本机版本，不推定旧版也使用同一接口。

单图建模若要求自由旋转，应先用有厚度的基础部件构建完整空间结构，再以参考图校准风格；固定视角的轮廓拼片或整图投影不能代替立体模型。植物生成器应同时检查侧面、背面、俯视和代表性参数组合，并保留独立可编辑的叶片原型。独立演示的本机验证入口为 `制作留档/20260919_青菜_参数化立体重制_043038/青菜_V2_参数化生成器.blend`，未接入游戏。

## Premiere Pro MCP 接入与排错（2026-09-21）

适用本机 Windows、Premiere Pro 26.0.0.72、Node.js 24.18.0、`leancoderkavy/premiere-pro-mcp` 1.16.4 的 CEP 连接。已实测只读连通，不代表所有编辑接口或其他版本已验收。[项目说明](https://github.com/leancoderkavy/premiere-pro-mcp)

- **当前入口**：Codex 全局条目 `premiere-pro-leancoderkavy`；PR「窗口 → 扩展 → MCP for Adobe Premiere Pro」。PR 面板的 Bridge directory 和服务环境变量 `PREMIERE_TEMP_DIR` 均为 `D:\PremiereMCPBridgePrivate`，面板须点 **Save** 保存，再点 **Start Bridge**。CEP 路线不需要 Token；不要把 UXP 的配置说明套用到 CEP。
- **安装与连接分开验收**：`--doctor --json` 的 ready 只说明本地组件就绪。还要经标准 MCP 协议调用 `verify_premiere_connection`，确认 connector、project、active sequence 均 ready，再读取一次 `get_active_sequence`。本次两条请求均返回成功，面板三项变绿；顶部黄色 `Connector running / Ready for an AI assistant connection` 可以是空闲等待状态，历史红字不代表最新一次仍失败。没有写入或保存 PR 工程、替换媒体。
- **权限报错定位**：`Bridge directory grants write access to untrusted identities` 是桥接目录可被其他账户写入，不是缺少密钥。默认 `%TEMP%\premiere-mcp-bridge` 在本机继承了沙盒账户的写权限；插件同时校验所有上级目录。检查目录 owner、写入 ACE 和上级 replacement rights；只看当前目录或直接重装都可能漏掉原因。不要关闭或修改插件的安全检查。
- **本机最终处理**：管理员确认后，将 D 盘根目录上一条仅作用于根目录的 Authenticated Users ACE 从 `0x1301bf` 调整为 `0x1201bf`，只移除 DELETE 位；保留其他 ACE 及可继承规则。随后新建私有桥接目录，仅当前账户、SYSTEM、Administrators 可写。最终插件检查 `unsafeWriteAces=[]`、`unsafeAncestorEntries=[]`。这是针对本机既有权限的修复，不是通用安装步骤；其他机器先找权限合格的私有路径，不能照抄根目录权限修改。
- **必须保留的教训**：初次对根目录使用 `Set-Acl` 出现长时间处理，助手已中止；这类操作可能自动传播继承权限，不能因为命令没写 `-Recurse` 就声称只触及目录自身。最终使用只写目标目录的 `SetFileSecurityW`；该旧 API 不传播到子项，但实测清除了根 DACL 的 auto-inherited 标志，故原样比较 SDDL 报不一致，需要区分 ACE 内容与控制标志。没有全盘 ACL 前后审计，不能宣称初次尝试绝未触及子项；后续不要重跑本次临时修复脚本。[微软 API 说明](https://learn.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-setfilesecurityw)、[自动传播说明](https://learn.microsoft.com/en-us/windows/win32/secauthz/automatic-propagation-of-inheritable-aces)
- **桌面工具失败不等于 PR 不能操作**：本机 Computer Use 截图报 `SetIsBorderRequired / 0x80004002`；UIA 能读出按钮却报缓存元素不可用，且文字树可能滞后。实测 FFmpeg GDI 桌面截图可见浮动扩展面板，而按 PR 主窗口标题截取可能漏掉它。替代操作仍须遵守当前工具边界、核验最新画面和目标进程；CEP 面板可能属于 `CEPHtmlEngine.exe`，应核验它是目标 PR 的子进程，不能只比较 PID 是否与 PR 主进程相同。点击后以新截图、面板日志及真实请求结果交叉确认。
- **后续编辑边界**：连接成功不等于变速、透明、位置和替换保真已验证。安装时审查的 `replace_clip` 是删除旧片段再插入，不能假定保留原入出点、效果或周边剪辑；使用前核对已安装版本实现，并在副本序列验证。当前任务工具列表未热加载时，可用标准 MCP 客户端做明确范围内的只读检查；重载 Codex 后再确认原生工具发现情况，不用安装参数代替实测。

本机复核入口：`codex mcp get premiere-pro-leancoderkavy --json`；服务为 `D:/Software/nvm/v24.18.0/node_modules/premiere-pro-mcp/dist/index.js`，由 `D:/Software/nodejs/node.exe` 启动。Node 版本切换后检查这个绝对入口是否仍存在。协议客户端的标准输出与错误输出分开读取，设超时并在结束后关闭自己启动的进程；中文输出需明确 UTF-8，不能按乱码名称匹配媒体。

证据与回退资料保存在本机 `%USERPROFILE%/.codex/`：`premiere-mcp-connection-verified.json` 为最终连接记录，`premiere-mcp-D-root-acl-before.txt` 为原根目录权限备份；不是可盲目执行的恢复指令。绿色面板截图在 `%TEMP%/premiere-mcp-panel-connected.png`，临时截图可能被清理。`D:/PremiereMCPBridge` 是保留的空测试目录，实际连接不用它。

## Tripo 接入选择与当前状态

2026-09-17 核验了 [Codex 插件说明](https://developers.tripo3d.ai/en/docs/codex-plugin)、[CLI 说明](https://developers.tripo3d.ai/en/docs/cli)、已安装 npm 包及本机插件清单。用户安装后，当前任务已加载 Tripo 3D 0.2.2 的 `tripo-3d` 与 `tripo-game-asset` 两个技能；安装目录的插件清单确认发布者为 VAST，并声明技能入口。此前目录搜索未找到的结果已经过时，不能据此继续判断插件不可用。

当前采用 **插件技能指导工作流 + CLI 执行**：插件技能直接通过 shell 调用 Tripo CLI，复用已有设备登录，不需要单独配置插件 API Key、MCP 服务或 LLM 账号。用户仍以自然语言描述需求；CLI 负责参数控制、任务记录和处理链。CLI 自带的 `tripo mcp` 在 0.4.0 仅暴露 make、task get/wait、balance、history 五个工具，它是另一种可选接法，不是已安装 Codex 插件的必需组件，当前不额外注册。

- 本机命令：`D:/Software/nodejs/tripo.cmd`，包位置为 `D:/Software/nodejs/node_modules/tripo-cli/`。使用 `.cmd` 入口，无需为 npm 的 PowerShell shim 修改执行策略。
- 插件入口：`%USERPROFILE%/.codex/plugins/cache/openai-curated-remote/tripo-3d/0.2.2/skills/`；生成前按当前加载版本读取对应技能。插件和 CLI 版本独立，升级任一方后检查兼容性，不把技能示例中的 `@latest` 变成每次任务自动升级依赖的要求。
- `--version`、`--help` 与包内参数说明已检查；用户完成国际区（ov）浏览器设备授权，登录进程正常退出。随后 `doctor` 的 Node、认证、API 连通性和余额检查通过，退出码为 0。余额属于实时账号状态，用前查询，不在此复制；本文件不保留一次性代码或令牌。
- 登录使用浏览器设备授权，凭据由 CLI 存在用户目录 `~/.tripo`；不要求用户把 API Key 发到聊天或写入工程。若账号属于国内区，重新发起 cn 区授权，不能只按用户语言推断账号区域。
- 后续连接异常或准备使用时，通过 `tripo.cmd doctor --json --no-open` 分别检查认证、API 连通性和余额。CLI 自带的 `tripo ai` 可另接 LLM，但由 Codex 调用普通生成命令不需要再配置一套 LLM 账号。
- 首次真实生成已完成：获选青菜 PNG → Tripo v3.1 智能低面数模型，一次 40 积分；CLI 等待并下载 GLB、预览和 task.json，Blender 5.2.2 可导入。请求 6000 面，实际 8790 三角形，检查未通过；无缺失纹理。原始顶点拆分造成的非流形统计经内存副本合并诊断后为零，不能直接当作破洞数。该原始结果保留；随后经 Blender 合并重合点、减至 2988 三角形、统一约 0.48 米宽与接地原点，已导入 Godot 原型并查看全景 / 聚焦。整理版静态资产检查通过，最终美术和性能仍未验收。详细报告在本地 `制作留档/`，可复用取舍见资产工作流。

各类资产使用 Godot、Blender、Tripo 的分工、Tripo 内部模型选择及交接验收，统一见 [三维资产工具分工](asset-workflow.md)。用户补充商业推广目标后，作物、可见道具和静态建筑在合理范围内优先采用 Tripo 整体或部件生成；精确拼接与运行效果继续由 Blender / Godot 负责。生成服务仅用于开发，不接进游戏运行逻辑。

调用前的能力选择、P2 / H3.1 与纹理版本区别、分件兼容限制、费用快照和官方接口入口，集中见 [Tripo 能力与生成工作流](tripo-workflow.md)。该页区分官方说明、本机核验和待实测路线；后续生成先复用并定向更新，不重复全面调研，也不把本机默认参数当作质量上限。

2026-09-17 小样已验证 P2 四边面 + v3.5 HD 荷花、H3.1 Ultra + v3.5 HD 民居；来源和重建入口在 [荷花](../ArtSource/Environment/Lotus/README.md)、[民居](../ArtSource/Environment/House/README.md)。CLI 0.4.0 生成可透传新版纹理参数，但独立纹理命令仍有旧白名单；兼容处理及服务回显依据集中维护在上述 Tripo 工作流。纹理成功也可能归一化模型尺寸，必须复核变换。

副屏静音运行（用户要求）：本机 Godot 实测 screen 0 位于物理坐标 `(3840,0)`，是右侧3840×2160副屏；screen 1 位于 `(0,0)`，才是主屏。`scripts/godot.ps1 Run` 和隔离/性能启动脚本默认 screen 0、Dummy 音频驱动，不向扬声器播放；普通运行和隔离启动只有显式 `-EnableAudio` 才恢复设备音频。`scripts/record.ps1` 默认 `-Screen 0`，启动同样静音；用户未要求有声音轨时不传 `-WithAudio`。这只影响代理启动，不改变游戏音乐资源或玩家默认设置。显示器重连后重新枚举，不将Godot索引等同Windows编号；本机逻辑2560×1440与物理4K也不能混用。

前期房屋／荷花曾被 `lod_bias=0` 与自动LOD叠加破坏，彼时只做了单件禁用。2026-09-17后续已修全局选择策略，详见上面的资产流程；不能继续把零偏置当作全景默认或把旧最低档性能当作当前收益。4K性能采样曾因用户切回主屏而失焦、降到后台15fps：保留失焦计数并判为受干扰，不反复抢焦点，也不把离线成片60fps当作运行性能。

已从 0.4.0 源码核验：`game-pc` 是高预算详细材质预设，`game-mobile` 默认 15,000 面与 2K 贴图；它们都不是本农场已批准的资产标准，不能因目标是 Windows 就自动选择高预算预设。实际预算按单个资产的显示尺寸、数量及画面要求确定。

自动化注意：`make` 默认阻塞等待并下载结果，`task watch --json` 返回进度流；持续等待已有进程与任务，不因请求暂时无响应就再发一次生成。保存任务 ID、参数、用量及本地产物，预览未达标时在已授权迭代范围内处理，不进行无上限重生成。批处理与多候选会扩展消耗，执行前先核对用户已授权数量、处理步骤和预算，已有明确授权不重复询问。

2026-09-17 Windows / CLI 0.4.0 实测：任务已成功但下载报 `fetch failed`、TLS 中断时，先区分生成 API 与模型 CDN 的连接，不重新生成模型。本次 CDN 域名曾解析到代理的 `198.18.*` 地址；用户切换全局代理后，以原任务 ID 执行普通 `task get --download` 成功取得 GLB 与预览，无需指定 IP、关闭证书验证或改系统 DNS。CDN 根目录返回 HTTP 403 只说明根路径不开放，不能据此认定实际资源不可下载；最终以原任务文件完整下载和导入为准。本次不能推广为所有网络失败都由同一代理配置造成。

详细接口按需读取本机包内文档：`tripo.cmd docs --topic commands/make`、`tripo.cmd docs --topic examples/game-asset`。本机帮助显示无交互模式会自动跳过 CLI 确认，因此不能把工具自身的提示当作费用边界。

插件配置核验所得经验：技能以 CLI 为执行入口时，先复用已验证的运行时和账号，再做健康检查；不因安装插件重复登录或另起服务。技能标明部分预设会附带收费转换步骤，生成时核对最终需要的格式及完整处理链；输出位置以实际结果中的 `model_file` / `output_dir` 为准。插件说明中的参数和服务限制不能仅凭本次健康检查视为已实测，首次使用对应能力时再核对并验证。

## 开发录屏

录制属于开发工具，普通运行不加载录制节点或编码进程。关键节点与镜头节奏见 [测试规则](../rules/testing.md#关键节点录屏)。在仓库根目录的 PowerShell 7 运行：

```powershell
./scripts/record.ps1 -Title '农场原型_全景与青菜聚焦' -Description '展示全景、青菜田近景与三维转动。' -Contribution 'Tripo 生成青菜模型与颜色纹理；GPT / Astra（Codex）编写场景和镜头；Blender 整理模型。' -Demo
```

存档闭环里程碑可加 `-FarmDemo -Seconds 28`：播种、浇水、受控推进1440秒、收获与保存使用独立演示存档，片中需注明不是实际等待。普通运行不加载录制逻辑，发行排除 `development/*` 且拒绝录制参数；录制目录只允许项目 `.local/recordings/` 内，防止演示改到玩家档。

完整院落里程碑用 `-CourtyardDemo -WithAudio -Seconds 40`：六阶段全景、收获解锁、三件装饰确认及夜景。初始累计青9／萝6、作物阶段和12／21点是隔离演示夹具，动作与保存走普通场景接口；不是实际等待或玩家进度。`-WithAudio` 仅支持离线演示，使用 Godot 内部混音转 AAC／48kHz／双声道／192kbps；校验非静音和音视频时长差，不采集麦克风或其他程序。未提供主观听感结论。

历史017素材使用 `-FinalDemo -WithAudio -Seconds 56`：六阶段全景、成熟田收获、播种浇水、幼株与成熟、再次收获、三装饰确认和昼转夜。录制偏好与农场档都隔离；沿用standard／4×MSAA及正常焦点LOD/DOF，不强制全高。初始累计青9／萝6，片中UTC在18／21秒推进300／1140秒；本地12→21小时及HUD时钟／日夜图标是同一录制视觉夹具，不改系统时间。当时脚本校验青11篮、收获田空、三装饰保存、普通LOD与21:00 HUD。本轮录制脚本由根代理迁移到逐格选择和同田混种，未取得新素材前不能将017称为逐格演示。字幕建议作为独立SRT留档，未烧录产品画面。

实时采集只做有界复核可用 `-RealtimeProbe -Seconds 16`（14–20秒、无声、不与离线开关混用），在本次窗口4秒缓推、9–14秒缓转，仍采用WGC真实采集；不是修复或性能测试。2026-09-17最终界面下的014复核仍失败：推进11/45、转动29/120近重复，约24%，仅诊断，不继续改驱动或安装采集依赖。格式通过不能覆盖内容失败。
- **自动展示 `-Demo`**：采用 Godot Movie Maker，以固定 1/60 秒时间步逐帧输出，再用 NVIDIA NVENC 编码 H.264。镜头停留 4 秒、聚焦 1.8 秒、近景停留、小角度转动约 15°、返回全景与收尾；默认 24 秒。这是当前游戏场景的离线演示渲染，不能作为人工操作或实时性能证明，不提高游戏画质设置。生成可能比视频时长更久。
- **手动操作（不加 `-Demo`）**：保留 Windows.Graphics.Capture 按 HWND 实时捕获本次游戏窗口。当前机器这条链路仍存在重复帧风险，输出会提示，元数据标为 `manual_review_required`；预览通过前不作为流畅成片。不能把自动演示的修复说成实时采集问题已解决。普通交互过渡仍为 0.75 秒。
- `-Seconds 40` 设置视频时长（2–120 秒，自动演示至少 24 秒）；游戏中 F9 提前结束，Esc 仍返回全景。完成后只关闭此次实例，保留用户原有游戏与编辑器。提前结束的演示也需人工预览。
- 默认选择一块真实 3840×2160 屏幕；本机 `-Screen 0` 对应右侧第二屏，不能按物理编号猜测。独占全屏、无标题栏；不更改系统分辨率，不放大低分辨率画面。仅 `movie` 特性下的窗口尺寸覆盖设为 4K，让影片初始化即取得正确尺寸，统一使用项目 1600×900 的 UI 逻辑尺度；本机单独传 `--resolution` 后再全屏不足以保证影片初始尺寸。
- 成片规格为 MP4 / H.264 High / yuv420p / 3840×2160 / 60 CFR，NVENC `p5` / `hq` / VBR `CQ18`，每 120 帧关键帧，BT.709 标记与 faststart。默认无声，显式 `-WithAudio` 加入游戏混音。自动展示的 AVI / MJPEG 中间文件由引擎生成，最终 H.264 压缩使用显卡；不能称整个流程都在 GPU 上。中间文件临近 AVI 的 4 GB 上限时中止并提示缩短片段；成功后删除该临时 AVI，失败时留在 `.local/recordings/` 会话目录供排错。
- 视频、中文编号 / 时间 / 节点名称、剪辑说明、元数据、规格和诊断放 `制作留档/05_开发录屏/`，整个目录不入 Git。完整演示必须通过格式、全部展示时间戳及运动区间的近重复画面检查，再以正式文件名加入索引；失败保留 `待校验.mp4`。手动片段明确需要复核。缺少 NVENC / 4K 屏幕时失败，不自动改为软件 H.264、低分辨率放大或整个桌面捕获。

**本机依赖。** Godot 版本以 `.godot-version` 为准，沿用控制台入口检查版本，实际启动匹配 GUI 程序以核验 PID / HWND。系统 FFmpeg 8.0.1 保留；项目隔离使用 `.local/tools/ffmpeg/ffmpeg-9.0.1-essentials_build/bin/ffmpeg.exe` 及同目录 `ffprobe.exe`，不修改 PATH、不打包进游戏。来自 [Gyan Windows builds](https://www.gyan.dev/ffmpeg/builds/) release essentials 7z，归档 SHA-256 为 `49a73bdf0850092a252ac4641d922f3048d63ed113e196cc65ce1e4f7fb33e85`，GPLv3 许可与 README 同目录保留。其他路径用 `-FFmpegPath` 指定；实时路径还要求 `gfxcapture`。

**重复帧排查经验（2026-09-17，Godot 4.7.2 / FFmpeg 9.0.1 / RTX 4090 / 双 4K 60 Hz）。** 原 005 片段虽然有 1440 帧、每个展示时间戳间隔 1/60 秒，推进时仍存在大量近重复画面。恒定帧率转换会补重复帧，检查 FPS、时间戳和静态截图不足以验收运动。隔离场景的主循环实测约 60.00 fps、帧间隔 p95 约 16.74 ms；带可解码帧编号的实时捕获测试则发现漏采后补重复。问题已定位到呈现 / 实时采集链路，尚未证明是某个驱动或编码选项单独导致。关闭 B 帧与编码等待曾有一次连续 300 帧通过，但重复测试与完整演示失败，因此不作为已验证修复，也不据此修改游戏渲染器、画质或模型。

自动展示采用官方固定步长输出，避免依赖实时窗口采样。入口调用 [运动检查](../scripts/check-recording-motion.ps1)，按Tour选择镜头时段：classic沿用4.9秒推进／10.5秒转动，final采用4.4秒推进／13.6秒缓转／27.3秒返回；解码相邻帧，检查缩至 320×180 后的亮度平均绝对差：小于 0.01 / 255 视为近重复，比例超过 2% 判失败。静止停留不参与；该启发式针对当前场景，不是通用 FPS 仪表，镜头时间或内容改变时应一并维护采样区间，并实际预览。本次旧 005 负例检出推进 16/45、转动 43/120 对近重复帧；新 010 同区间均为 0，24 秒 / 1440 帧 / 4K H.264 格式与全部时间戳通过，并解码查看全景和近景。临时测试素材和逐帧证据在 `.local/recording-cadence/`，剪辑使用与修复结论在制作留档的录屏索引。

原生 F9 检查入口为 `tests/recording_controls_smoke.gd`：`--script` 指定该文件，`--` 后传 `--record-session=<隔离目录>`，先创建 `config.json`（`{"demo":false,"screen":0}`）。它检查停止请求及普通镜头速度；本次实时节点路径和带 `--write-movie` 的提前退出路径均通过，后者正常封装 7 帧 AVI。普通镜头原型回归也通过。格式校验、失败 / 提前停止和新完整演示按变化分别复核，不以导出成功代替运动验收。

尺寸排错：本机普通全屏曾捕获到 3840×2162，独占全屏后为 3840×2160；`canvas_items` 下 `ViewportTexture.get_size()` 曾返回 11520×6480，实际图像为 3840×2160。因此准备时只回读一次图像核验，成片再用 ffprobe 核验，不把纹理报告尺寸当作实际超采样证据。

依据：[Godot Movie Maker](https://docs.godotengine.org/en/stable/tutorials/animation/creating_movies.html) 说明固定步长与离线边界、AVI 上限；[FFmpeg gfxcapture](https://ffmpeg.org/ffmpeg-filters.html#gfxcapture) 不保证固定采集率；[FFmpeg 帧率选项](https://ffmpeg.org/ffmpeg.html#Advanced-options) 说明 CFR 补帧 / 丢帧行为。这里的稳定性结论只覆盖当前版本、场景和实测素材。

## 后续协作边界

1. 软件方面当前没有必须补装项。Godot、Blender 与 Tripo 已有入口；遇到特定需求再添加工具。
2. 首版范围与画面目标已定稿并获自主实施授权；六田两作物、保存回访、三件装饰及成品界面按任务总览推进，不再重复等待开工确认。
3. 需要云端同步时提供仓库地址或指定托管平台与可见性；现阶段只做本地 Git 提交。
4. 开发侧按固定参考图完成视觉校对，保留实际差距；尚未取得的用户试玩意见不能写成用户签收。已有素材生成授权与商务核验暂缓边界见任务总览。

官方文档、社区检索入口、已安装技能及未采用框架见 [Godot 资料及工具](godot-resources.md)。

视觉补修经验：圆柱远景的垂直映射需按视线投影到远处竖直平面，单纯拉伸UV会把中景藏到水面下或造成碗状地平线；水面淡出半径须与绘画岸线共同实看。水材质由昼夜模块覆盖，修改需同步该入口。新增岸石／植被后应重新运行八槽真实三角形遮挡与点击检查，本次移开遮挡ground_04的石组，未绕过命中规则。对应证据见[院落补修](task/首个可发布版本/handoffs/3.2-visual-refinement-handoff.md)与[水面远景补修](task/首个可发布版本/handoffs/3.4-visual-refinement-handoff.md)；画面冻结后重新执行持续性能验收。

Godot 4.7.2 的小窗输入验证：`Camera3D.unproject_position` 与 `Control.get_global_rect` 提供逻辑视口坐标，传入 `Viewport.push_input` 时使用 `in_local_coords=true`，否则窗口缩放会再次换算而误点。原生 Windows 点击助手仍使用客户区物理像素，不能直接复用逻辑点。本轮实际窗口960×600、逻辑1280×720，16:9渲染截图为960×540；记录三者而非把请求尺寸当渲染尺寸。八槽与小窗真实输入38项通过，见[逐格整合交接](task/格子农田与画面重构/handoffs/整体验证-handoff.md)。布置临时取景结束必须恢复进入前的全景目的姿态，自动演示也须等待镜头过渡后再选择物件。原生种子PopupMenu打开后，测试助手若再次SetForeground主窗口会关闭弹窗；应保持当前弹窗焦点，在确认同一PID／路径／启动时间后发送实际条目点击，本轮发行包实测通过。手工生成现有原生助手的进程元数据时，沿用启动入口的带本地偏移ISO时间；PowerShell将UTC Z字符串反序列化为DateTime再转字符串解析会丢失时区，导致严格启动时间核验拒绝。玩家启动核验中已观察此问题，改为实际进程StartTime的本地偏移表示后通过，没有放松PID／路径／时间检查。

普通退出需在保存门槛通过或用户明确放弃后统一收尾：停止并清空FarmAudio播放流，禁用退出等待期输入／新保存，再让混音与主循环完成异步释放后退出。当前100ms等待加一次主循环在本机三条普通程序退出路径和45项回归通过；不能把exit0单独视为干净退出。入口为tests/exit_cleanup_test.gd，证据及音频设备边界见[4.2退出清理交接](task/首个可发布版本/handoffs/4.2-exit-cleanup-handoff.md)。

状态采集的文件替换边界：Godot 更新 status.json 时，Test-Path 成功后文件名仍可能在 FileStream.Open 前短暂消失。Read-EvidenceJson 保留 ReadWrite|Delete 共享，只在打开阶段对 Win32 文件不存在（2）、共享冲突（32）或锁冲突（33）做最多 8 次、间隔 25ms 的重试；持续缺失仍报错，读取失败和无效 JSON 不被吞掉。隔离反证见 `.local/verification/collector-race-fix/results.json`：原单次打开复现缺口失败，新读取恢复 75ms 重命名缺口及真实短共享锁，坏 JSON 继续报错、永久缺失约 211ms 后失败。此修复只解决采集器竞态，不能将中断的性能样本算成完成验收。

2026-09-17逐格与画面修订源码8f93348：本机96格成熟混种和三装饰，1080p烟测164项／4K六组56项均0失败；4K正式场景402.902秒，约60fps，p95最高17.264ms，峰值驻留工作集1042214912字节。此轮没有重复30分钟持续验收；硬件、采样定义、首轮失焦和文件替换竞态证据见[逐格整合交接](task/格子农田与画面重构/handoffs/整体验证-handoff.md)。018号56秒4K有声制作演示为3360帧、运动区间0近重复，使用隔离混种示例与固定步长，不替代实时性能。

历史4.2及后续性能入口：tests/run-performance-validation.ps1 的 acceptance／4k／smoke，输出限新建.local/verification子目录；标准Godot运行正式场景采逐帧数据，普通发行程序另用release_startup_probe.ps1验证真实菜单响应。以下d193129数字只属于旧整田候选，本轮逐格状态与画面改变后重新采样：本机1080p真实1849.495秒、201项0失败，4K401.759秒、56项0失败，均正常退出无残留；1080p峰值驻留工作集856MB，不与2.178GB私有提交混淆。旧原型用户窗口保留，整卡遥测包含该背景负载；具体CPU/GPU/图元、帧间隔、内存与未测边界见[4.2交接](task/首个可发布版本/handoffs/4.2-handoff.md)。发行日志可能缓冲，不能用未刷新的日志作为即时就绪依据；就绪仍以实际窗口响应确认。

rc.5交付：源码8f39fd66干净独立克隆、导入和发行导出通过，PCK审计254项无缺失／禁用资源。仓库外中文空格路径普通程序真实点击第3田第4行第2格，播种、浇水、湿土反馈、保存重开继续生长通过；两次正常退出0，隔离profile证据在 `contact-review/release-native/`。020号24秒4K60有声离线演示1440帧、音画时长一致、运动检查通过，已预览近景；录屏与前台性能采样分别进行。包和证据路径见README，未改变玩家存档。


## 桂花动态与自由视角（2026-09-17）

左前岸边、入口藤架靠玩家一端为新桂花，坐标 `(-6.05,0.13,4.3)`。树源、模型参数、分件和连续权重重建见[树木资产](../ArtSource/Environment/Trees/README.md)。右上“自由视角”或F8进入：左键绕按下时点击的表面旋转，中键／右键拖动平移，滚轮平滑前后缩放；WASD、Q/E与Shift快移／Ctrl慢移仍可用。Esc、退出自由视角或全景按钮返回，复位恢复默认镜头。仅Debug构建提供，进入清除农事选择，屏蔽田地操作，设置弹窗和窗口失焦时暂停控制；前景框景及景深退出以便检查模型，不修改玩家设置。

### 镜头操作修订（2026-09-17）

自由及普通全景／田块聚焦／布置模式都接收场景区域的滚轮，统一使用按真实帧间隔解析更新的临界阻尼（响应16/秒）；连滚累计目标并保留速度，停手自然减速。旧0.26秒三次缓入缓出每格重建Tween，会反复把速度降到零，已按用户反馈移除。普通模式分别最多退回初始28／10.4／31米，最近8.5米；聚焦过渡的目标点和角度继续移动，滚轮只接管距离，不重启整个镜头过渡。缩放期间阻止农事点击延迟生效；返回保留进入聚焦／自由视角前的全景目标。普通模式右键取消、中键旋转和Shift中键平移不变。

自由视角左键使用按下时的网格表面交点，旋转位置与朝向一起绕交点变化，保持偏离屏幕中心的点击点不跳位；俯仰范围限制防止翻极。中／右键在点击深度平面平移。空白处用当前观察深度平面；释放到UI上、离窗、失焦、弹窗和模式切换均结束拖动。`camera_surface_pick.gd` 按点击检测可见 Mesh／MultiMesh 的三角形，先筛包围盒，仅缓存实际触及的网格，退出自由视角释放；不新增物理碰撞体或每帧全场景扫描。使用基础网格，GPU风动叶尖／透明纹理留空不作逐像素交点承诺。依据：[TriangleMesh](https://docs.godotengine.org/en/4.7/classes/class_trianglemesh.html)、[Camera3D投影](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html)。

验证入口 `tests/camera_navigation_test.gd -- --output=<仓库.local下绝对目录>` 覆盖实际输入路由、非中心表面／实例化网格、空白回退、旋转中心稳定、双键平移、GUI释放／取消、三种普通模式缩放边界与平滑累计；证据 `.local/verification/camera-navigation/`。2026-09-17阻尼修订只运行该定向入口：连滚保速、停手收敛、反向、取消、30／60／144Hz一致性及原有输入与距离边界通过，证据 `.local/verification/camera-damping/`；没有扩大到存档、全资产或性能套件。手感仍由用户在交付预览中确认。术语参考 [Three.js OrbitControls](https://threejs.org/docs/pages/OrbitControls.html) 的 damping/inertia，本项目实现不是照搬其参数或声称默认开启。关键节点需要补拍时使用 `scripts/record.ps1 -CameraDemo -Seconds 30` 并补齐标题／描述／贡献，展示普通缩放→点击点旋转→平移→退回初始距离；运动检查区间与该镜头时间轴匹配。

镜头修订验证：新导航29项、农田输入58项、布置镜头12项、焦点功能50项、桂花与自由视角879项及原型镜头返回检查通过；新导航／焦点／树木画面分别在 `.local/verification/camera-navigation/`、`camera-focus/`、`camera-tree/`。只验证当前功能与画面，不作为长期性能或发行包验证。

此前桂花／LOD首次接入节点的完整场景219项、焦点功能50项、自由视角与桂花879项、菜单41项、摆放34项、布置镜头12项、共享植物风动22项通过；47正式模型LOD／拓扑204项通过；树木60秒13相位对25处邻居检查无穿面，挪石后荷花60秒13相位检查亦通过。历史证据在 `.local/verification/lod-scene/`、`focus-lod-fixed/`、`osmanthus-final/`；不是本次重复测量、长期性能或玩家审美签收。

关键节点录制：`scripts/record.ps1 -TreeDemo -Seconds 24 -Title <中文节点名> -Description <内容> -Contribution <工具分工>`，全景→自由近看→15°缓转→返回，隔离16:30光照／HUD时钟；3840×2160静音副屏、离线固定60fps，视频保存在中文制作留档。


## 工具菜单与界面缩放

2026-09-18，Godot 4.7.2：此前项目1280×720逻辑画布与部分场景截图强设1920×1080并存，导致同分辨率下UI比例不一致；自定义硬件指针又固定48物理像素，在4K显得过小。现项目统一1600×900、canvas_items缩放；录制保持4K渲染，不单独改变UI逻辑画布，视觉检查移除独立content_scale_size覆盖。硬件指针按64逻辑像素乘实际stretch比例，4K约154像素，箭头上限170像素，为携带图标合成留出硬件256×256的完整范围。小窗点击测试使用 `root.push_input(event, true)`，防止逻辑坐标重复换算。

底部“播种／工具”入口与上方选择面板分离，菜单状态由main持有；按钮打开面板不会直接播种。UI仅负责互斥展开、0.18秒淡入淡出／0.22秒位移，取消时先禁用选项再收起，快速切换杀掉旧动画；退出时释放Tween引用，避免已结束动画留存资源。常规状态浮条全部移除，保存失败遮罩保留。

定向场景交互79项通过，包括默认收起、分类切换、取消、播种、水收益、输入隔离、小窗和4K逻辑尺寸／指针尺寸。随后修复退出动画引用留存，以独立HUD快速切换与释放复核，无资源泄漏回显；未重跑无关生长、存档和全场景性能集。截图 `.local/verification/tool-palettes/00-seed-palette.png`、`00-tool-palette.png`、`04-compact.png`、`05-4k-palette.png`；硬件指针不进入Viewport截图，尺寸由实际Input纹理检查，不能声称截图已捕获原生箭头。开荒／除草未纳入本轮实现。


同日指针跟随修订：旧箭头由系统刷新，携带物是物理帧更新的TextureRect，即使不用插值也会相对拖后。[Godot官方说明](https://docs.godotengine.org/en/stable/tutorials/inputs/custom_mouse_cursor.html)指出软件光标相对硬件光标至少多一帧延迟。现进入游戏即设置自定义箭头；选择菜／工具时合成为同一硬件光标，空手和UI上恢复自定义基础箭头，不恢复系统默认箭头。只在选择或缩放变化时生成、缓存纹理，不按鼠标运动重绘；保持同一热点。Windows主机定向检查覆盖启动基础纹理、选择／取消复用、4K尺寸上限及工具／菜品共享上图下字布局，退出无错误；证据 `.local/verification/cursor-cards/`。纹理截图是硬件光标输入，不能冒充延迟量测；实际手感待用户试玩。硬件光标及携带物均不进入Viewport离线截图，后续需要录下操作指针时使用支持光标的窗口捕获，或仅在离线录制中显式展示指针，不在正式玩法重新引入软件跟随。


## 全景相机调节

2026-09-18，Godot 4.7.2：Debug 右上「相机调节」打开左侧面板。俯角数值越小越接近平视；左右角度、距离、视野、中心左右／高度／前后实时生效。原角度预设为28°，本轮低角度试样为22°，均使用偏航25°、距离28、视野29°、中心(0,0.85,0)。点击「复制参数」将七项参数写入剪贴板，可直接粘贴到对话；用户随后确认的默认参数为俯角16.5°、偏航27.5°、距离28.6、视野29°、中心(0.25,0.75,0)，已固定到代码；两个历史对照预设保留。面板收起或Esc关闭后继续玩，聚焦后返回、右上复位保留本次参数；重启恢复代码默认值，不写入存档。此面板调整全景构图，田块近景仍为40°，自由视角保持原独立操作。

入口：`Game/ui/camera_tuning.gd`，参数权威在 `FarmCamera.overview_parameters/preview_overview`。非自由全景最远缩放边界使用本次距离。`layered_landscape.gd` 的绘景舞台原先固定28°，改低角度会令远山落出画面；现在跟随所选全景基准俯角，临时聚焦或自由观察不改变基准。镜头选定后如需进一步配景，继续基于该固定参数调整。

景深调节（2026-09-18）：面板提供「景深模糊」开关与0–300%滑块，默认170%（100%保持原上限的含义），以及「远景雾气」0–100%滑块，默认28%，即时平滑预览，复制JSON同时包含`dof_enabled`、`dof_strength`（0–3）与`fog_strength`（0–1）。强度由`focus_detail`持有，仅本次运行有效，收起／复位／其他设置应用不重置；开关与原设置中的景深偏好共用。低画质明确停用控件并保留数值，自由检查和摆放仍不虚化。当前采用[CameraAttributesPractical](https://docs.godotengine.org/en/4.7/classes/class_cameraattributespractical.html)的真实相机深度加人为清晰区，并非真实镜头的单一焦平面：全景和聚焦都保护六块田及实际作物包围盒（额外0.12米风动余量），作物更换后更新缓存、镜头变化时重新投影深度；全景／聚焦／缩放及过渡共用同一强度和清晰带，不再在set_focus中清零，也不切换较弱的近景配置，强度不改变田块清晰边界。远景雾气现采用共享世界坐标函数：以主岛为清晰椭圆，向左右和后方外围连续渐入；所有远岛、植被、真实湖面和绘景水面统一响应。环境旧相机距离雾密度置零，避免两套雾叠加；框景植物豁免。0关闭新增雾，素材画出的薄雾仍保留，颜色随昼夜并正确转为线性颜色上传。没有新增整屏模糊或额外渲染通道。沿用下述定向入口，当前证据输出`.local/verification/dof-tuning/`，含0／35／100%及聚焦对照、面板小窗和4K截图。

定向原生场景验证入口：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/camera_tuning_test.gd')`。原相机面板验证了滑块改变镜头、剪贴板JSON可还原数值、取消持工具与阻断场景点击、聚焦返回／复位／缩放上限、Esc及960×600与4K布局；历史截图保留在`.local/verification/camera-tuning/`。当前景深修订的同一入口已通过，另检查0／35／100%实际模糊量、所有田块和可见作物角点在聚焦过渡／缩放中保持清晰、开关共享、低画质停用及恢复、其他设置不重置强度，以及复制新增景深参数；证据在`dof-tuning/`，没有跑存档或全资产回归。剪贴板复制后立即读取曾遇系统短时占用，检查延迟0.4秒模拟粘贴时机后通过，未修改产品复制行为。场景光照固定16:30，HUD时钟为系统时间，不能当作时间同步演示。此节点保留参数、截图和补拍入口，本轮未录制视频。

### 水雾与景深连续性修复（2026-09-18）

以下记录为此前连续性修复；当前雾算法已升级为上文世界坐标环绕雾。此前定位到三个实际原因：邻居岛与水草材质写入固定的`FOG`，覆盖了环境雾；水面反射在15–23米突然衰减，且远水绘景另用屏幕纵向渐变，形成白／蓝／白分带；聚焦逻辑主动将景深清零并切换弱档。现移除材质雾覆盖，让岛、植物和水面响应共同环境雾，反射连续变化并衰减远处波纹高光；绘景湖面用视线与虚拟水面的交点距离计算相同雾渐变。全景、聚焦和返回共用景深配置，清晰带每帧保护全部田块与作物。

前景虚线黑边另由透明水面未写入深度触发：当前Godot 4.7.2 Forward+、4×MSAA下，对照渲染只给水面增加`depth_draw_always`即可消除叶片／水面交界的黑点。保留圆形高质量景深、关闭采样抖动以及原4×MSAA；未采用试验中的方形模糊或TAA，也不靠关闭抗锯齿掩盖问题。水面透明度、船舱遮罩和读取不透明场景的水岸接触效果保留。此结论来自本机渲染对照，不推断所有引擎版本都有同样问题。契约依据：[空间着色器FOG与深度写入](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)；径向雾与自定义FOG分支另核对了[Forward+着色器实现](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl)。

定向入口：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/camera_tuning_test.gd','--','--fog-regression')`。本轮通过实际远岛像素雾开关对照、300%景深下聚焦及返回过渡连续采样、全部土面与作物角点清晰检查，并目检4K叶片边缘和缩放湖面。证据`.local/verification/dof-tuning/`：`fog-fixed-00/55/100.png`、`dof-edge-fixed-4k.png`、`dof-continuous-focus.png`、`fog-fixed-zoom.png`；日志`.local/fog-fix.log`包含`FOG_REGRESSION_PASS`且无引擎错误。未重跑存档、全资产或完整相机面板套件；没有新增模型、生成费用或成片。截图光照固定11点，HUD为系统时刻，不作时间同步演示。

### 低机位前景（2026-09-18）

当前按用户选定的16.5°俯角重新安排左右边角，复用已有有纹理的桂花、竹、野花与河石，替换原单色程序叶片。构图、来源、成本和对比截图见[环境前景节点](../ArtSource/Environment/README.md#前景节点20260918-低机位边角框景)。后续已补充下沿水草与浮动荷花。运行 `scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/foreground_composition_test.gd','--','--output=<REPO_ROOT>/.local/verification/foreground-shore-20260918')` 可复现定向原生检查，截图与报告在指定目录；其他机器改为仓库内`.local/`下绝对路径。默认输出属于首版前景证据，后续务必指定独立目录避免覆盖。本轮验证构图和受影响的景深／退让，不跑存档或全资产回归，也未将源三角形数当作GPU性能结论。选景深时先定位前景与船／六田的真实深度，再调清晰带；单独增加统一模糊强度会误伤船和水中荷花。

## 水乡邻居岛与圆润岸线（2026-09-18）

当前参考、任务ID、180积分费用、Blender源、高低档和五处布局见[邻居岛制作记录](../ArtSource/Environment/Islets/README.md)；主岛原先是Blender程序生成的直边轮廓，现改为连续曲线与多圈缓坡，完整参数及桥头支承见[岸坡记录](../ArtSource/Environment/Banks/README.md)。三张独立透明背景各使用一次，边缘小幅弯曲，属于2.5D舞台；邻居院落则是真实三维对象。

定向入口：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/island_world_test.gd')`。当前输出`.local/verification/archipelago-20260918/after/`，覆盖农田平地、桥口全宽支承、距离分档与画质切回恢复、昼夜及4K构图，并检查十座岛统一实例尺度、岸线植被和远景失焦。该入口默认覆盖同名截图，后续对比前先保留旧证据。前次证据仍在`.local/verification/island-world-20260918/`，基线`c595c6f`；本次修改前基线`850d4f7`的全景另存新目录`before/`。

已验证经验：地表细节法线必须叠加到几何法线上，否则圆坡仍显得平直；强制低画质状态与物理距离档位需分别保存，避免切回标准画质后卡在低档。扩展真实水面必须同时检查倾斜背景卡片及水／天底色过渡，避免山体被水遮挡或远岛落在天空底色上。当前水面48–72米渐隐，自由视角前进时同步推进水域；绘景底色过渡移至90–125。视频节点已登记，原图→完整岛模型转角→Blender整理→入景可复现补拍，本轮未录制成片。

同日远景续改见[远岛群制作记录](../ArtSource/Environment/Archipelago/README.md)：五座新岛、芦苇／香蒲／菱叶三种新资产，共480积分。所有新旧邻居岛统一10米真实跨度、实例scale=1，只调整世界位置和朝向，以透视产生大小差异；植物可按固定随机种子变化株高和角度。远景景深过渡原500米，令几十米处几乎不失焦，现改40米并保留田块清晰带。最终定向检查通过；4K RTX4090同实例短样本新增几何关闭／开启GPU中位数7.414／7.793毫秒，仅作本次成本比较，不作为整机性能认证；没有重跑存档或全资产套件。

景深／雾气快速复核：相同入口追加用户参数 --quick-atmosphere，仅检查300%实际模糊量、雾强度和零值关闭、农田清晰边界与新增面板尺寸。本轮通过，截图为 .local/verification/dof-tuning/06-stronger-blur-fog-panel.png；未重跑完整相机交互集。

## 主岛生活细节与环绕雾（2026-09-18）

14种资产、955积分、禽类动画、夜间灯笼和农田暖光、原始数据与补拍索引见[制作记录](../ArtSource/Environment/CourtyardLife/README.md)。定向原生入口 `scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/courtyard_life_test.gd')` 覆盖昼夜、左右岛雾响应、聚焦连续性、摆件反向接触和水禽运动。另有窗口焦点策略定向检查 `tests/window_preview_activity_test.gd`；可见开发预览失焦上限60fps，最小化15fps，不代表实际稳定帧率。落花改为有界MultiMesh由渲染时间驱动，避免逐帧上传和低物理帧率步进。

## 见闻、相册与缩放窗口输入（2026-09-18）

入口、状态、原图位置和定向证据见[相册节点](design-baseline/动物行为与轻松玩法候选.md#十田园见闻与相册实现节点--20260918)。程序化GUI检查若使用Control的逻辑坐标，应采用Viewport.push_input(event, true)；Input.parse_input_event使用窗口输入语义，在窗口缩放后直接传逻辑坐标会点错位置，不能因此认定实际按钮失效。鼠标按下／释放仍需成对。涉及生长的界面检查注入固定clock，只比较需要保持的状态；不把正常时间结算误报为滚轮修改农场。截图等frame_post_draw，并检查实际图片，不以save_png调用本身作为捕获成功证据。

### 田园生活版独立验证 · 20260918

Godot4.7.2当前存档v14。`tests/start-isolated-game.ps1` 已改为从 farm_store.gd 的VERSION解析目标存档目录，避免验证入口继续查旧farm-v4而误报不存在；先解析再启动进程。用该入口启动独立候选后，等待真实存档写入及窗口响应，再通过 `tests/native-game-window.ps1 -Action close` 正常关闭，由保留的进程句柄读取退出码。只凭Get-Process新取得对象的ExitCode可能为null，不能将null伪报0。当前原包两次启动／关闭均由启动入口取得真实退出码0；重开stdout明确FARM_LOAD stage=loaded version=14，证据 life-final-native/。

Windows图形独立包stdout在重定向时可能缓冲到退出，期间指定log-file可为空；不要仅凭实时日志空白判断未启动。窗口Responding与真实v14存档更新时间联合判断就绪，退出后审计stdout／stderr。截屏前核验本次窗口真实屏幕范围及遮挡；被其他窗口遮挡时不抓整屏、不为截图夺取主屏焦点，同源码场景截图与普通独立包启动证据分别报告。此轮普通窗口实测位于(3840,0)，Godot全屏客户区为3840×2162；视觉渲染测试为3840×2160。

## 全模型开发检查页

入口：`./scripts/godot.ps1 -Action Run -ExtraArgs @('res://development/model_gallery.tscn')`；青菜材质对照左上角“全部模型”也可进入。运行时扫描工程内独立GLB／glTF／OBJ／FBX模型，下方逐个生成真实模型缩略图，可按名称、来源、文件名搜索和分类；不枚举完整玩法场景或临时源文件。

左键旋转、中键平移、滚轮缩放；开启“双模型”，选择要替换的左／右侧后点击模型图标。模型等比例适配展示，信息区显示原尺寸、三角数、表面数、资源路径和生成来源；悬停查看制作记录入口。来源映射在 `Game/development/model_catalog.gd`，新增／替换资产时依据 ArtSource 更新，未知型号不猜填。朝向、粗糙度、适用植物风动和灯光仅改变本次预览；“恢复原材质”重新加载当前模型，不写入资源或农场存档。单体预览不加载完整农场行为、组合场景或动物AI。

本次按用户要求不新增或运行测试，仅启动开发面板；开发资源沿用发行排除规则，不随旧独立包自动更新。

## 低耗壁纸测量入口（Godot 4.7.2，2026-09-24）

自动验收跟进及8小时队列已按用户要求取消，下面保留按需手动入口；中断的样本不算完成验收。后续优化先做分项定位和对应短检，不自动重新启动长时队列。

先运行 `scripts/build-desktop.ps1`，再运行 `scripts/build-wallpaper-benchmark.ps1`。后者在 `.local/builds/wallpaper-benchmark-release/` 复制当前游戏及导入缓存、替换副本启动场景并导出发行模板；不会修改普通游戏入口。官方发行模板会忽略 `--script`，外部场景覆盖也被禁用，不能把普通Farm.exe成功启动当作测试成功。清单记录源码摘要与提交；修改后必须重建，测试完成必须有退出码0及 `results.json`。导入缓存是独立复制，禁止与工作工程硬链接后重新导入。

`tests/measure-wallpaper.ps1 -Directory <仓库.local/verification下新目录> -Executable .local/builds/wallpaper-benchmark-release/Farm.exe -Native` 默认每段预热30秒、180秒采样3次，并检查实际遮挡、无周期写档、两次真实5分钟长期后台与恢复。`-Capacity -VisibleOnly` 用384格成熟混种和28只动物；`-Resolution native` 保留本机原生4K输出作同分辨率对照；1080选项只限制3D，UI仍为本机原生4K，因此不冒充1080屏核显条件。`-SoakHours 8` 在操作／待机往返前增加8小时同场景采样。快速检查可用 `-Seconds 5 -Repeats 1 -IdleSeconds 5`，其中长期后台时间会加速，不能作正式达标证据。

测试存档和APPDATA均隔离；覆盖窗口是测试自己创建的不激活窗口，放在第二屏，不操纵其他应用、系统锁定或时钟。其他负载、用户遮挡和锁屏会污染样本，记录实际覆盖秒数；不能用受影响样本宣称稳定30帧。CPU用进程累计CPU时间之差／真实秒数，分别记录游戏与宿主并合计；分别记录驻留、私有提交、引擎纹理＋缓冲和系统GPU分配。NVIDIA整卡功耗同时记录频率，前后各180秒无游戏空闲基线；测量进程在游戏与两侧空闲期间都临时保持系统与屏幕唤醒，结束／异常时恢复线程原状态，避免屏幕自动关闭造成不同条件的空闲基线；其他GPU缺少整卡遥测时明确不可用，不填零。

本轮短检已确认资源压缩与默认1080策略生效，真实宿主覆盖时零绘制、恢复正常、操作结果正确；功能检查包括农场状态385项、存档109项、设置49项、松土边界111项、焦点50项及前景／动物导航。真实核显、3×180秒的匹配前后功耗、8小时稳定性及全部预算需要独立完成，不以短检、开发实例或RTX4090推算替代。证据保存在 `.local/verification/optimization-20260924/`。

存档优化复用DirAccess实例而不缓存权限结论：每次读写仍重新核对绝对路径祖先与侧文件、当前主档内容、侧文件版本，以及原子替换与回读。动物边界检查只缩小候选边集合，精确线段碰撞仍执行。骨骼GDScript姿态缓存曾在实测中比引擎方法慢约3倍，未采用。

测量完成后运行 `python tests/summarize-wallpaper.py <证据目录>`，汇总宿主在内的CPU时间、内存、帧间隔、匹配前后空闲功耗与频率；缺失遥测保持null。Godot 4.7.2在释放渲染资源时可能调用不呈现的draw以清理待回收资源（[固定版本主循环](https://github.com/godotengine/godot/blob/4.7.2-stable/main/main.cpp)）；预热阶段先运行与采样相同的渲染统计查询，以排出延迟命令；记录预热绘制计数，长期后台再留6秒清理窗口，然后断言稳态绘制计数不增长。不要将资源释放过程的计数与持续后台绘制混同。

正式游戏已关闭引擎默认的屏幕常亮请求。隔离测量场景临时调用 `screen_set_keep_on(true)` 保证连续渲染样本，退出自动解除，不修改Windows电源计划；`measurement-policy.json`保留原值与测试覆盖。实际自动熄屏、锁屏、休眠恢复仍须单独验收，不能从这组保活测试推断。启动时记录管线编译计数，样本保留后续计数；冷启动与已缓存启动分开解释。

固定画面对照沿用 `wallpaper_budget_test.gd --visual-only`，在两个隔离工程副本中把shader和shader include的TIME固定为17，并使用同一96格成熟混种、昼夜小时、动物种子与机位；副本用 `--fixed-fps 60` 只生成全景、农田近景、三处邻居近景和环绕端点截图。该模式会暂停动物，不能作动画或真实性能证据；实际镜头移动与风动仍需独立检查。完整运行场景的截图保存在本次证据目录visual-before／visual-corrected（撤回串色候选后的最终对照）。

共享材质须先确认实例是否单独改色。岸石的`_tint_stone`会改材质参数，不能直接按源材质复用；本轮发现串色后撤回了这一缓存，保留既有逐石色彩。后续若合批，需要实例颜色参数及对应画面对照。

当前候选的导出短测（`release-final-check`、`release-events-check`）为96格成熟混种、RTX4090、原生4K界面／1080三维；纹理＋缓冲约683MiB，较同配置旧版短测约4150MiB明显降低。宿主事件版重复遮挡／恢复后稳态绘制均为0，恢复首帧约54–59ms。驻留仍约1.4GiB、长期后台图形资源约497MiB，尚未达到600／350／256MiB目标；操作和启动也未达标。短测处于定位阶段，部分时段有构建活动，CPU与功耗只使用后续隔离的正式重复采样判定；无核显认证。

满容量测量使用既有12田块布局，但必须先`apply_construction`更新扩地后的实际岸线，再计算田块高度；直接修改布局字典会产生非法布局，发行模板中初始化断言被移除后可能崩溃。测量入口在构造农场前调用正常布局接纳检查，禁止将这类夹具失败计作游戏性能数据。

### 阴影稳定性与开销定位（2026-09-24）

RTX4090、Godot 4.7.2 Forward+、4K UI／1080三维、96格成熟混种、7只动物的开发实例分项诊断：在解除帧率限制且显卡维持P0约2745MHz的短样本中，基线GPU每帧2.191ms；只隐藏院落环境降到0.966ms，关闭太阳阴影1.778ms，隐藏院内树竹花1.825ms，隐藏农田1.868ms，关闭SSAO1.956ms，关闭水面2.061ms。各项有重叠，不能相加或当作删掉相应内容的建议。主要负担在环境几何、投影与提交；降水面／景深不是第一优先。30帧时显卡自动降频，约8–9ms的GPU读数不能直接与P0结果相比，亦不能用不限帧整卡功耗判断壁纸省电收益。[渲染计时的频率边界](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu)。

采用三个对应修正：

- 标准方向光改为4096图、中档PCF、两级分区，分界0.45，覆盖仍48米并混合分区；低档2048／两级，高档4096／四级保留近处细节。原四级默认分界把前两张图用在镜头前10米，主院落挤在较粗的后级；2048图和低滤波叠加使细影不稳定。保留角直径0，避免恢复既有薄叶PCSS斑点。[方向光分区与距离契约](https://docs.godotengine.org/en/4.7/classes/class_directionallight3d.html)。
- 石块材质按来源共享，独有颜色改为实例参数；材质不能缓存后继续写每块石头的base_color，否则会互相染色。路径的颜色缩放也会缩放Alpha，着色器只将Alpha用作是否覆盖的标记，不能将它当混合强度。雨后状态仍由季节模块统一更新。`tests/courtyard_materials_test.gd`覆盖独立颜色、共享绘制和建设副本，已有地块／岸线的外观比较同步实例色。
- 30帧的真实帧间隔通常略大于1/30秒，动物原来在一个画面内至少两次完成骨骼求解。现在每个碰撞子步仍推进动作相位、位置和支撑高度，只在最终画面求解骨骼；检查转向、细障碍、较长帧与母鸡步态。三种禽类的两子步对照600帧，骨骼最终变换一致，该部分耗时约减半；不能把它说成整个程序CPU减半。

对应前后短检（相同场景，开发实例）：绘制调用1231→约900（约27%），阴影绘制图元738万→632万（约14%）；30帧动物更新两段中位2.49／3.01ms→1.62／1.93ms（约35–36%）。同一P0频率区间，CPU渲染提交0.970→0.804ms，GPU 2.184→2.262ms（约增加4%）；纹理＋缓冲约680→728MiB。**本轮以约48MiB图形资源和小幅GPU成本补回阴影稳定性，主要性能收益是CPU与绘制提交，未取得GPU／内存总量下降。** 这些短样本不替代发行宿主、核显、功耗或8小时验收。

画面对照冻结时钟、风动相位、动物与场景更新，在24个相同微运镜机位分别绘制旧阴影、新阴影、8192四级参照和无阴影图；以阴影遮暗区域对齐参照，平均阴影误差0.03099→0.01583，帧间误差0.006052→0.004142（约32%下降）。这是该场景的图像误差指标，不等于所有镜头闪烁减少32%或完全消除。实例色与旧独立材质对照99.998%以上像素的最大通道差不超过2/255，整体色彩无可见变化；少量GPU粒子不同步，未宣称逐像素完全相同。近景、微运镜、标准／低／高画质往返与动物步态检查通过。定位脚本、原始计数、固定相位序列和结果在 `.local/verification/shadow-hotspot-20260924/`；分区变化复核沿用 `tests/focus_detail_test.gd -- --functional-only --output=<隔离目录>`，它不抢焦点，计时不作性能结论。

### 有限三轮优化的阶段结果（2026-09-24）

沿用上面的预算与画质，三轮结束后收尾，不追加长时队列。RTX4090、Godot 4.7.2 Forward+、96格成熟混种／7只动物、原生4K界面／1080三维的资源清单显示：最大单份网格约3.4MiB，多数环境网格约1–2MiB；隐藏的邻居高档网格仍驻留，但全部减面不能等同于释放纹理或渲染目标。第一轮因此处理实际发现的超尺寸常驻图标，之后两轮对环境植物着色器做隔离试验。

| 轮次 | 实测与取舍 |
|---|---|
| 1：图标驻留 | 工具栏6张及丝瓜图标由1254×1254的无限制导入改为256像素上限；源PNG、透明边缘、无损压缩与mipmaps设置保留。工具栏槽28逻辑像素、选菜32–48像素、动作菜单60像素，丝瓜鼠标合成最大约128像素，256仍覆盖当前实际用途。匹配场景两段各5秒采样的纹理占用均为632,016,896→574,962,688字节，减少54.4MiB；纹理＋缓冲约728.2→673.8MiB（约7.5%），缓冲与900次绘制调用不变。采用。 |
| 2：风动方向矩阵 | 在同一场景内交替原始／候选／候选／原始，各预热3秒采样8秒，解除限帧且核对P0、2745–2760MHz。用3×3方向逆矩阵替换原4×4逆矩阵，GPU中位原始2.260／2.263ms，候选2.592／2.262ms，没有可重复实质收益。仅在隔离进程试验，正式代码未改。 |
| 3：普通植物裁剪变体 | 只对非前景植物试验移除前景覆盖淡出的discard，前景原材质保留。同样交替四段、P0约2745MHz，GPU中位原始2.266／2.267ms，候选2.235／2.237ms；仅约0.03ms（1.3%），不足以支持本阶段新增和维护材质变体，未采用。官方说明discard可能妨碍深度预处理，但不能据此假定本场景会显著获益。 |

图标在浅／深背景及40／60／120逻辑像素下进行了匹配渲染观察，实际4K场景HUD和近景也已查看，未见明显轮廓、透明边缘或可读性退化。`tests/game_menu_test.gd -- --visual`80项通过；检查中修正了仍假定开发工具只有5项的旧断言，改为核对现有6个功能入口（含已上线的“全部作物成熟”）。`tests/focus_detail_test.gd -- --functional-only --output=<新隔离目录>`53项通过，覆盖近远景、聚焦／返回中断、缩放、画质往返、LOD网格与农场状态保持；此模式的耗时不用于性能结论。模型、LOD、阴影和风动正式实现均未改动，未另行重跑全资产动画／拓扑巡检。

测量复用`tests/wallpaper_budget_test.gd`的成熟混种夹具与渲染计数；原始JSON、图标前后图、当前实际缓存纹理／唯一网格清单、隔离试验脚本和检查日志位于`.local/verification/performance-stage-20260924/`。这些是开发实例短测，图标收益只证明引擎纹理驻留下降，未证明CPU常驻内存、功耗、操作长帧或启动时间改善；不限帧整卡功耗也不用于省电结论。原有常驻内存／后台图形资源预算缺口、普通核显及8小时稳定性仍未验收，禁止放宽预算或据此宣布全部性能目标达标。后续若继续，应单独决定更大范围的环境投影／资源生命周期方案。

相关契约：[纹理导入与显存](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_images.html)、[discard的性能边界](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shading_language.html#discarding)。

### 发行版内存专项：有限三轮结果（2026-09-24）

本阶段已按三轮上限结束，后两轮未取得至少5%的操作后稳定驻留下降。**600MiB可见常驻目标未达到，不表示全部低耗预算验收完成。** 正式改动只将`threading/worker_pool/max_threads`设为8；模型、LOD、贴图、画质和渲染器保持原样。该设置是固定线程数，不是根据机器核数动态取最小值；低核数机器仍需实机验证。

使用Godot 4.7.2发行模板、真实桌面宿主、Ryzen 9 5900X（24逻辑处理器）／RTX4090、96格成熟混种／7只动物、标准画质、4K界面／1080三维。每组可见阶段连续3×15秒采样；冷缓存完整组随后执行收获／播种／浇水、两次遮挡／恢复和夜景，暖缓存补充对照仅测可见阶段。内存是游戏与宿主的工作集合计，私有提交和显存分别记录，不相加冒充物理内存。下表为可见阶段中位数，单位MiB；三段采样不是三次独立冷启动，也不是长时稳定性证明。

| 对照条件 | 工作集：原配置→8线程 | 私有提交：原配置→8线程 | 纹理＋缓冲 |
|---|---|---|---|
| 新隔离着色器缓存 | 1407.4→1246.0，约下降11.5% | 2943.2→2701.0 | 均676.3 |
| 复用对应运行的着色器／管线缓存，农场重新隔离 | 约1155.9→1123.1，约下降2.8% | 2705.2→2590.2 | 均676.3 |

第一轮收益主要发生在首次编译后的驻留，不能把11.5%外推到每次启动或所有硬件。冷缓存对照的启动场景耗时约9.55→9.94秒；农事调用中位13.64→12.70ms、最长39.59→38.32ms；30帧观赏的帧间隔p95均约33.37ms，恢复首帧约53–55ms。操作阶段工作集**采样峰值**约1428→1268MiB；外部采样间隔约1.5秒，不能当作捕获了所有瞬时尖峰。两轮恢复后的常驻仍约1265–1267MiB，不是进入场景后只看最低值。没有从这些短测推导功耗或帧率提升。

分项定位与后两轮取舍：

- Windows页面分类显示大头是私有驻留，不是资源包映射；独立定位中，尚未加载主场景的4K窗口／测量依赖／Forward+初始化阶段约660MiB。这不是纯引擎最低开销，也不能外推到暖缓存或其他显卡。清空`CourtyardAssets`缓存使资源计数617→598，但三段工作集仍约1414MiB；释放部分几何也未立即降低工作集，不能把已释放资源字节直接当作操作系统回收量。剩余引擎、驱动及分配器持有内存尚未逐笔归因。
- 第二轮在8线程副本中把38张已知驻留的大三维贴图导入上限试降至1024：纹理减少100.7MiB，初始工作集约1179–1181MiB；操作与第二次恢复后回到约1266MiB，与8线程原贴图接近。为进程常驻目标不足以支持整批降低清晰度，未采用；不宣称该候选已通过画质验收。
- 第三轮恢复原贴图，只把渲染传输暂存上限128→32MiB：初始工作集约1249MiB，恢复后约1265–1267MiB，无额外稳定收益，未采用。该设置是上限，不能按配置数值相减计算省下多少内存。

复核入口仍为`build-desktop.ps1`、`build-wallpaper-benchmark.ps1`与`tests/measure-wallpaper.ps1`，内存专项使用`-Native -Seconds 15 -Repeats 3 -IdleSeconds 5 -NoCaptures`及全新的隔离输出目录。新增`-NoCaptures`只跳过测量中的日／夜截图，避免`get_image()`读回与PNG编码改变后续内存；视觉检查另跑。截图和农事操作现在分别标记阶段，避免它们被记入上一段可见采样。暖缓存对照只复制相应隔离用户目录中的`shader_cache`和`vulkan`，保留全新农场／偏好；不能混用冷暖样本。被否定的参数只在普通复制的工程副本中试验，未修改工作工程的导入缓存。

证据位于`.local/verification/memory-stage-20260924/`：`baseline-clean`、`round1-workers`、`baseline-warm`、`round1-workers-warm`、`round2-textures`、`round3-staging`均有发行清单、进程采样、引擎计数及正常退出证据；功能检查零失败。`baseline`为带截图的初查，`diagnostic`仅用于破坏性分项定位，不能与正式无截图数据混算。短测的五分钟后台门槛采用加速触发；未恢复已取消的8小时队列，未完成核显／低核数／满容量／长期稳定性认证，也未发布新的下载包。

最终运行`focus_detail_test.gd --functional-only`，53项检查全部通过，并检查总览与近景截图。首次检查发现自动结伴游泳会新增`company`游园记录，干扰整个农场快照的不变断言；诊断前后唯一差异即该记录。测试存档通过现有规则预先登记它，保留完整快照断言，不修改游戏逻辑。成功证据为`focus-final-fixed/`及同名日志，失败与定位证据保留在`focus-final`、`focus-diagnostic`。

参数语义见[Godot 4.7 ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html)，线程创建行为以[4.7.2 WorkerThreadPool源码](https://github.com/godotengine/godot/blob/4.7.2-stable/core/object/worker_thread_pool.cpp)为准。不能把线程设置描述成消除了内存泄漏；本轮没有这样的证据。

### 绘图后端内存对比（2026-09-24）

在上一阶段8工作线程基础上，只比较三种配置：Forward+／Vulkan、Forward+／Direct3D 12、Compatibility／OpenGL。保留**操作后稳定常驻下降至少20%，并通过相关画面与功能检查**的候选，不扩展到第四种配置。Windows现采用`rendering/rendering_device/driver.windows="d3d12"`；Forward+、模型、LOD、贴图、画质和宿主行为不变。引擎已有的Vulkan回退配置保持默认；本次显式Vulkan对照不等于模拟了不支持D3D12的硬件自动回退。

同一发行包、Godot 4.7.2、5900X／RTX4090、标准画质、4K界面／1080三维、96格成熟混种／7只动物，真实宿主及新隔离存档。每组可见阶段3×15秒，再执行48次农事调用、两次遮挡／深度空闲／恢复及夜景。下表为游戏＋宿主工作集中位数，单位MiB；恢复栏取第二次恢复，另一次恢复和夜景也保持相近结果。

| 应用着色器缓存 | Vulkan初始 | D3D12初始 | Vulkan恢复后 | D3D12恢复后 | 恢复后降幅 |
|---|---:|---:|---:|---:|---:|
| 新隔离缓存 | 1253.9 | 956.9 | 1239.0 | 968.3 | 21.8% |
| 复用对应缓存 | 1129.5 | 794.9 | 1129.6 | 801.6 | 29.0% |

第二次恢复后的私有提交分别为2161.9→1841.4MiB、2064.1→1704.5MiB。系统记录的专用显存约1088→978MiB、共享显存约218→134–135MiB，分别报告，不与工作集相加。场景对象及资源数量一致，初始引擎缓冲计数同为133688482字节；D3D12的纹理计数反而约多8.2MiB，收益不能归因为降低了贴图清晰度。CPU驻留下降与绘图后端选择相关，但尚未逐笔确定是哪些驱动或分配器内部结构释放。

收益有代价：新应用缓存的主场景加载约9.77→15.97秒，暖缓存约9.43→9.84秒（均不包含全部进程初始化）；新缓存农事调用最长38.73→66.23ms，暖缓存最长24.27→22.20ms。30帧观赏的帧间隔p95均约33.37ms，深度空闲恢复首帧Vulkan约54–55ms，D3D12约71–77ms。未据此宣称帧率或功耗提升。

OpenGL加载时出现669条实例着色器参数容量错误，报告硬件上限4096；测量入口按运行错误中止，无有效完成样本。该候选不采用，不通过删场景、忽略错误或大改着色器来获得低内存数字。D3D12的`focus_detail_test.gd --functional-only`通过53项检查，但当时画面对照漏检了下述土面缺口；不能以功能检查通过代表材质完全正确，动态动物与风动不作逐像素比较。

同日用户反馈每个种植位中心出现绿色多边形。Godot 4.7.2／RTX4090同视角对照确认：D3D12下缓存土面、实时土面和优化前高密度土面均有缺口，Vulkan下正常；触发点为`caaa9106`切换后端，并非松土减面或FSR。`soil.gdshader`根部培土公式对可能为负的数使用`pow(x,2.0)`，D3D12产生NaN，影响顶点及法线；即使空田的`planted=0`也不能消除无效数值。改为`x*x`，保留培土形状、土面缓存及D3D12。[微软pow契约](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-pow)明确负底数结果为NaN。以后这类有符号平方直接相乘，并实际检查根部中心，不能只检查编译及玩法状态。

复核入口：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/soil_presentation_test.gd','--','--output=<独立绝对输出目录>')`；增加`--rendering-driver vulkan`可指定对照。测试在固定日照、空田近景检查16个根部中心的土色像素，修复前16处全部失败，修复后零失败，原种植／浇水／收获及命中检查通过；已观察空田及作物根部正反两侧。证据在`.local/verification/soil-regression-red/`、`soil-regression-fixed/`与`soil-vulkan/`；本轮没有重测内存或发布下载包。

内存来源诊断边界：WPR堆快照能力探测返回`0xd0000061`，本会话未提权，也没有启动WPR记录。Godot的`--extra-gpu-memory-tracking`在场景启动前以`0xc0000374`退出；关闭此开关的独立诊断正常推进，不能把诊断开关崩溃当作正常发行程序崩溃。安全诊断中，引擎跟踪的分配量从加载场景前约70.9MiB到可见阶段约441.9MiB；操作后页面分类约1214.7MiB私有驻留、136.0MiB映像、9.6MiB映射。前者不是物理工作集，不能直接相减把差额全算作驱动。驱动分项接口在未启用额外追踪时返回0，表示没有可用数据，不能解释为零占用。完整分配调用栈仍未取得。

复核：先运行`build-desktop.ps1`及`build-wallpaper-benchmark.ps1`，再用`tests/measure-wallpaper.ps1 -Native -Seconds 15 -Repeats 3 -IdleSeconds 5 -NoCaptures`和独立输出目录。新增`-RenderingMethod forward_plus -RenderingDriver vulkan|d3d12`用于对照；OpenGL使用`-RenderingMethod gl_compatibility -RenderingDriver opengl3`。`ready.json`记录实际方法与驱动；指定配置后若发生回退，入口拒绝将其当作成功对照。暖缓存只复制对应隔离用户目录的`shader_cache`／`vulkan`等实际存在的管线缓存，保持农场与偏好全新；不清理系统或驱动全局缓存，因此“新缓存”不是整机彻底冷启动。

原始证据在`.local/verification/renderer-memory-20260924/`：四组发行对照为`vulkan-cold`、`d3d12-cold`、`vulkan-warm`、`d3d12-warm`，均正常退出、功能检查零失败；`opengl-cold`是失败证据，`focus-d3d12`为场景回归，`diagnostic`／`diagnostic-safe`为单独的调试运行，不混入发行收益表。采样间隔约1.5秒，无法保证捕获瞬时峰值；每组连续三段不是三次独立启动，后台五分钟门槛仍为加速验证。未完成其他显卡／低核数／长期稳定性认证，尚未发布新包，600MiB目标仍未达到。

最终重新导出后，`default-d3d12`不传任何渲染器／驱动覆盖参数，复用D3D12缓存再次跑完整流程，实际启用Direct3D 12，初始约795.9MiB、两次恢复约800.4MiB、夜景约801.7MiB，正常退出且无功能失败。测量入口的实际回退校验用隔离元数据检查：匹配配置通过，驱动不符及渲染器不符均拒绝；这只验证校验逻辑，不冒充硬件自动回退实测。证据为`renderer-guard-check.json`。

参数及限制见[Windows驱动设置](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-rendering-rendering-device-driver-windows)、[驱动内存报告](https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html#class-renderingdevice-method-get-driver-and-device-memory-report)、[WPR堆快照](https://learn.microsoft.com/en-us/windows-hardware/test/wpt/record-heap-snapshot)。

### FSR设置（2026-09-24）

Godot 4.7.2／Forward+：显示页提供FSR关闭、画质优先、平衡、性能优先；后三者内部三维比例依次为输出的1/1.5、1/1.7、1/2，不与既有1080p上限相乘。开启后原分辨率控件置灰并说明由FSR接管，关闭后恢复保存的选择；UI分辨率不变。默认关闭，设置自动保存。非Forward+禁用FSR控件并沿用原分辨率，不修改保存的偏好。使用FSR2自身抗锯齿，关闭时恢复独立保存的抗锯齿选项（关闭／2×／4×）；高画质延迟应用与窗口改变尺寸也遵守此规则。不开放锐化等专业参数，不含帧生成。

官方契约：[Viewport缩放模式](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#enum-viewport-scaling3dmode)、[FSR与抗锯齿](https://docs.godotengine.org/en/4.7/tutorials/3d/resolution_scaling.html)。FSR有重建计算与历史缓冲成本，不保证比原来的低分辨率双线性缩放更省资源；本次不作帧率／内存收益结论。

复核入口：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/fsr_settings_test.gd')`，使用隔离农场及偏好目录。RTX4090／D3D12实景14项通过，覆盖各档、MSAA配合、高画质延迟切换、窗口缩放、关闭恢复与重开；画面留在`.local/verification/fsr-1714026/`。菜单专项97项与偏好读写50项通过，已观察新增控件和场景画面，修复新增行挤压状态／底栏的问题。

尝试扩展旧`ui_settings_scene_test.gd`时出现8项田格选择、菜单关闭时机及农场快照等失败；未将该综合集报告为通过，原用例保持不变。FSR新增检查改为上述独立实景入口。短测不等于低端显卡、长时运行或运动拖影已全面验收。

#### FSR进程GPU短测（2026-09-24）

源码`bb98c214`，5900X／RTX4090（Windows驱动32.0.16.1047），Godot 4.7.2开发运行时、D3D12／Forward+。隔离的96格成熟混种、7只动物、固定正午与全景；4K物理输出、标准画质、景深开启。使用现有WindowActivity的可见壁纸30fps策略，不争抢前台焦点，不连接原生桌面宿主，不代表发行模板性能或60fps交互。测试期间关闭已确认归属的开发游戏，其他程序保持原状，完成后恢复开发预览。

五种设置先各预热5秒；按顺序、逆序、交错顺序各测一轮，每次切换等待3秒、采样12秒。采样期间无截图、无新增specialization编译，结束后才取画面；每组约1080个帧计时样本，Windows进程计数器9–10个有效读数。只取实际游戏PID的`GPU Engine/Utilization Percentage`，每次以最忙引擎为该进程GPU比例，不把不同引擎相加；本次最忙引擎为3D。剔除跨档位计数器窗口，未用整卡利用率冒充游戏占用。整卡频率数据仅作干扰背景。

| 设置 | 三维渲染尺寸 | 游戏GPU比例中位数 | GPU每帧耗时中位数 | 三轮各自耗时中位数范围 |
|---|---|---:|---:|---:|
| 关闭＋1080p | 1920×1080 | 32.25% | 9.952ms | 8.942–10.545ms |
| 关闭＋原生 | 3840×2160 | 44.45% | 14.866ms | 10.698–17.431ms |
| 画质优先 | 2560×1440 | 42.29% | 15.866ms | 11.162–17.179ms |
| 平衡 | 约2259×1271 | 33.29% | 10.927ms | 9.154–14.212ms |
| 性能优先 | 1920×1080 | 33.29% | 10.905ms | 9.314–16.762ms |

表中GPU比例与耗时分别取各自全部有效采样的中位数，采样节奏不同，不能相互换算。五组平均约29.84–30.01fps，限帧下不以FPS判断GPU成本。**这些是当时有其他程序运行的观测，不是隔离硬件后的纯FSR加速率。** 进程归属能分开记账，不能隔离同一显卡的频率、调度和共享带宽。已观察到采样区间频率210–2760MHz大幅变化，同一档不同轮的耗时差异明显；不根据这些数字给出精确节省百分比或稳定优劣排名。没有足够证据把FSR当作低占用优化，也没有测整卡功耗归因或最大帧率。

证据在`.local/verification/fsr-gpu-20260924/measured/`：`summary.json`、`results.json`、`process.jsonl`、`whole-gpu-context.csv`、`actual-output.json`与画面；父目录保留`probe.gd`、`run.ps1`、`summarize.ps1`及已作废的首次采样，只有`measured/`用于上表。复测需新建隔离输出目录，沿用五组配置和相同顺序；`viewport_set_measure_render_time`打开后每个绘制帧取`viewport_get_measured_render_time_gpu`，外部Windows计数器必须按游戏实际PID过滤。

本机两个测量陷阱：console启动器会另起GUI绘图进程，必须采用`OS.get_process_id()`／ready文件中的PID或直接启动GUI可执行文件；首次因误取启动器PID缺失进程数据，已丢弃。4K／canvas_items拉伸时`ViewportTexture.get_size()`本次返回9216×5184，但实际读回图像及Windows窗口均为3840×2160；不能单凭该纹理尺寸接口宣称实际输出9K，需用`get_image().get_size()`在计时外核验。

方法参考：[Microsoft进程GPU统计](https://devblogs.microsoft.com/directx/gpus-in-the-task-manager/)、[Godot GPU计时与低频限制](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-measured-render-time-gpu)。

### 程序化岛屿研究室（2026-09-24）

独立场景位于 `Game/scenes/procedural_lab/procedural_lab.tscn`；直接指定场景启动，主入口和农场存档不变，Windows导出预设排除此研究目录。使用已有开发预览入口确认静音、第二屏独占全屏与窗口就绪：

```powershell
# 在 PowerShell 7 的仓库根目录执行；只运行研究场景。
& ./scripts/godot.ps1 -Action Run -ExtraArgs @('res://scenes/procedural_lab/procedural_lab.tscn')
# 纯布局定向检查。
& ./scripts/godot.ps1 -Action Run -ExtraArgs @('--headless','--script','../tests/procedural_island_test.gd')
# 真实场景和鼠标输入检查，结束后自动退出，不启动主游戏。
& ./scripts/godot.ps1 -Action Run -ExtraArgs @('--script','../tests/procedural_lab_scene_test.gd')
```

数字或文字种子配合同一组参数，在当前生成器和 Godot 4.7.2 下复现布局；更改引擎或算法不承诺旧种子结果不变。左侧输入后点击生成，也可换种子、选单岛／三岛／五岛预设；上方切换全景、岛屿、桥梁与竹架近景。默认先展示第一座岛的质感。左键旋转、右键／中键平移、滚轮缩放，Esc退出。复制按钮导出当前已生成画面的种子和参数；不保存游戏状态。

生成采用不对称大湾与细小侵蚀凹口叠加的径向轮廓；以完整岸坡包围范围保留水道，再用最短连接树选桥线。桥头整宽落在平地，岛内先留通路，再以完整占地布置房屋、菜畦、树冠、竹架和植物；放不下的设施省略，面板显示实际数量。桥长改变时增加木板／栏杆／水下支柱，竹架增加开间，主要构件保持截面尺寸。

质感修订直接复用主岛 `bank_geometry`、草土材质、`ground_cover._tuft`／`meadow`、五种 Tripo 岸石、芦苇／香蒲／菱叶、青石踏步和松土几何及贴图；岸边按种子聚簇、变换朝向与埋深，桥口逐个检查净空。菜畦补石质收边，草地避开房屋、菜畦和通路。照明复用主岛 `day_night` 固定10:30预览，保留低环境填光与AgX层次；不接入时钟玩法。上一版只复用岸坡材质、缺少草与岸石，加上过强环境填光和过小建筑／植被，不能代表主岛风格。默认岛尺度8.5米，房屋与树冠按完整占地放大，减少模型底座感。

木桥新增 Tripo P2 木柱（绳结、榫孔、柱帽、木纹，1847三角），Blender 5.2.2 制作倒角木板、扶手与梁，程序拼出带承重梁、桥桩和斜撑的桥。实际120积分；原始参考、精确模型版本、参数、重建与重导入审计见 [木桥构件](../ArtSource/Environment/ProceduralBridge/README.md)。竹架仍使用原有程序竹杆，不宣称本次生成了一整套新资产。随机轮廓与布局无需复制主岛，但地表、岸边、植物、尺度及光照需一起在实景核对，不能仅凭相同基色判断风格一致。

Godot 4.7.2 实测：种子 `边界-0`、小岛／五岛／最大岸线变化组合的一个腹地点距岸约1.82米，内置 `Geometry2D.is_point_in_polygon` 却返回false；官方该版本源码使用有限射线逐段计交点，顶点交会可能重复计数。本研究室用半开区间射线计数并检查到所有岸段的距离，避免把腹地误判成水面；只影响本研究室。测试另外使用多边形偏移与裁切核对完整道路走廊，不以同一个点判定证明自身正确。[4.7几何契约](https://docs.godotengine.org/en/4.7/classes/class_geometry2d.html)、[对应源码](https://github.com/godotengine/godot/blob/4.7-stable/core/math/geometry_2d.h)、[ArrayMesh生成](https://docs.godotengine.org/en/4.7/tutorials/3d/procedural_geometry/arraymesh.html)、[随机序列的版本边界](https://docs.godotengine.org/en/4.7/classes/class_randomnumbergenerator.html)。

24组种子／参数覆盖单岛、五岛、小尺寸、最大岸线变化、最窄水道、最宽桥与密集植被，验证确定性、连通、岸坡不相交、桥头承托、完整道路走廊和物件间距。场景测试通过真实鼠标按钮命中、输入种子／改参数后的重建、空种子拒绝、规划显示、旋转、跨UI释放、失焦取消、小窗口与4K界面／1080三维上限；已观察岛屿和桥梁／接头／竹架相反侧近景，截图在 `.local/verification/procedural-lab/`。细节版三岛样本生成约6秒；仅为本机短测，不代表低配性能或长期稳定性。本原型验证平坦庭院岛与构件组装，不包含内湖、悬崖、多层地形、可行走角色、农场生长或正式岛际交互。


### 首次启动、画质预设与壁纸提示（2026-09-24）

正常入口改为 `Game/scenes/startup.tscn`。加载页沿用淡彩主题与汇文明朝体：资源读取显示活动条，院落、道路、湖面、动物、作物、光照和设置按真实执行阶段推进，农场可绘制后才移交输入；测试与建设场景重建仍可直接使用 `main.tscn`。显示开发中试玩提示。设置默认打开显示页，底部“设为壁纸”与“退出游戏”“返回农场”同级并排，点击后进行二次确认，提示点击门前椅子在桌面操作、托盘右键“返回农场”；取消不挂接桌面，结束桌面操作直接执行。

首次缺少偏好文件时，先加载实际农场并短测中档：预热1秒、采样约1.5秒，使用帧间隔p90；中档p90高于22.2ms推荐低档，低于等于16.7ms再短测高档，高档p90不超过20ms才推荐高档，其余推荐中档。硬件信息仅作为未取得有效采样时的保守依据，不维护显卡型号评分表；核显、未知类型、少于8GiB内存／4逻辑处理器等退到低档，其余独显优先中档。采样期间仅前台解除游戏限帧并临时关闭VSync，结束恢复；失焦、窗口变化、少于20帧、p90超过中位数2.5倍或超时拒绝该段结果。推荐是当前农场和窗口的短测结果，不是满田、长时、全部硬件的性能保证。

首次选择采用低—中—高的三档滑块，推荐档预选，主按钮为独立深色“进入农场”；支持方向键。用户选择覆盖推荐，保存失败可重试或仅本次使用。已有偏好启动不再跑分或弹出选择。设置菜单的“画质预设”位于显示页首行，下拉顺序高／中／低，独立单项包括场景细节、阴影、光照、抗锯齿、分辨率、FSR和景深，组合不匹配时显示自定义。低档景深可以手动开启。显示页滚动，操作底栏不随内容滚出。

高／中／低预设默认三维上限1440／1080／720，高档4×MSAA，中档2×，低档关闭；高光照包含SSIL/SDFGI，中档SSAO，低档关闭SSAO。FSR按输出尺寸选用：中档仅在1080<输出高度≤1620时用画质优先，低档仅在1080<高度≤1440时用性能优先，其他情况关闭并采用手动上限；避免4K输出下FSR反而突破低档预算。开启FSR时禁用重复MSAA并保留用户参数，关闭后恢复。预设定义集中在 `graphics_presets.gd`，不保存第二份可能失真的预设名称。

复核入口：`tests/startup_experience_test.gd`（可见窗口，隔离农场／偏好，包含首次选择、真实保存失败和重试、重开、单项独立、分辨率预算、壁纸确认意图与小窗口截图）；`tests/game_menu_test.gd`（菜单布局和键盘焦点）；`tests/settings_store_test.gd`（字段验证及原子读写）；`tests/fsr_settings_test.gd`（真实Forward+的FSR／MSAA及恢复）。实测RTX4090／D3D12、1280×720启动窗口，首次短测获得有效样本并推荐高档；启动44项、菜单83项、偏好53项、FSR14项通过。最终日志为 `.local/verification/startup-slider-final.log`、`fsr-presets-final.log`，启动截图在 `.local/verification/startup-1623131/`。这些帧耗时仅服务该窗口的初始推荐，不推算4K／满田帧率。不自动重复操作真实桌面宿主。

Godot 4.7.2加载注意：本项目图谱调用 `ResourceLoader.load_threaded_request` 后即使不实例化场景，退出仍可复现约39个零引用RefCounted对象告警；相同资源同步读取不出现。单独拥有的 `Thread` 内调用同步 `ResourceLoader.load` 也不出现，因此启动页采用该路径，资源读取完成后主线程创建场景，退出时回收工作线程。不能为了“真实百分比”恢复有问题的路径。与官方 [LoadToken问题](https://github.com/godotengine/godot/issues/120661)／[待合入修复](https://github.com/godotengine/godot/pull/121025)表现相近，本机默认不开子线程也复现，未取得引擎分配栈，不声称根因完全相同。采用后完整启动／重开无残留告警；隔离对照方法为只加载 `main.tscn` 后释放并退出，勿用跑满农场掩盖加载器问题。

壁纸椅子引导：宿主报告 `ATTACHED` 成功后才显示 `ui/wallpaper_hint.gd` 气泡，随椅子屏幕投影定位并避开任务栏工作区；椅子使用独立提示描边，普通农具悬停保持原样。气泡右下角“关闭”只结束本次提示，“不再提示”写入独立偏好 `wallpaper_hint_dismissed`；失败不冒充成功，保留提示供重试。开始桌面交互或回到窗口自动收起，结束交互不会在本次壁纸会话再弹。观赏模式禁止全局 GUI 输入，气泡直接使用现有宿主经桌面图标／窗口遮挡过滤的鼠标消息；按下、释放、拖动和离开状态独立消费，不能穿透到椅子或农具。没有新增系统钩子或改变图标层级。

复核 `tests/wallpaper_hint_test.gd`：真实场景与渲染、隔离偏好，通过宿主消息入口检查进入／退出、临时关闭、永久关闭、真实写入失败与重试、读盘恢复、拖动／离开取消、小窗口工作区，18项通过；菜单布局与键盘检查87项通过。日志 `.local/verification/wallpaper-hint-final.log`、`menu-wallpaper.log`，画面在该日志记录的 `wallpaper-hint-*` 目录。本次未自动挂接真实桌面，不以模拟宿主消息宣称原生桌面端到端验收。