# 开发前准备与环境验证

> 环境首次核验：2026-09-16；当前2026-09-17已完成逐格种植与接缝／接触暗部修订，最新本地候选rc.5。目标仍为Windows普通窗口版三维农场：六田各4×4格、同田混种、选格后工具直接操作；技术验证与玩家美术签收分别记录。下文rc.1／rc.2与早期数字只描述对应历史基线。

## Godot 安装与日常入口

- 当前使用由 Codex 下载配置的 **Godot 4.7.2 标准版（非 .NET）**；本机 `--version` 为 `4.7.2.stable.official.ed1daf0bf`。用户另放在 D 盘的副本不使用、不由本任务删除。
- 安装目录：`%USERPROFILE%/AppData/Local/Godot/4.7.2-stable/`。GUI 为 `Godot_v4.7.2-stable_win64.exe`，自动化入口为同目录 `Godot_v4.7.2-stable_win64_console.exe`。
- 本机桌面已创建 **我有一片田 - Godot** 快捷方式，直接打开正式 `Game/` 工程。它属于本机入口；换电脑使用 README 命令或重新创建快捷方式。
- Windows x86_64 的 debug / release 模板安装在 `%USERPROFILE%/AppData/Roaming/Godot/export_templates/4.7.2.stable/`，未安装其他平台模板。引擎与模板来自 [官方下载页](https://godotengine.org/download/windows/) 及 [对应发布](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)，两个下载包均通过该发布 `SHA512-SUMS.txt` 校验。
- 本机软件路径只记在本文，工程启动脚本通过用户目录和根 [.godot-version](../.godot-version) 定位，不把账号路径写死进游戏。换位置时传 `-GodotPath` 或设置环境变量 `GODOT_EXE`，精确版本不符时入口拒绝执行。
- 标准版包含脚本编辑器、调试器和 CLI，可直接开始；当前无需 .NET SDK、C++ 工具链、Godot MCP、联网账号或 LLM API Key。
- 日常执行根 [README](../README.md) 的 Editor / Run / Import / ExportWindows 入口。导出结果为 `.local/builds/windows/Farm.exe` 与 `Farm.pck`，两者一起保留；不要只搬 exe。程序已使用正式青菜图标，当前未签名，正式发行打包由5.2处理。

## 工程基线与验证边界

- `Game/project.godot` 使用 GDScript 标准版，Forward+ / Vulkan，1280×720 可调整普通窗口；已接入六田两作物三阶段、江南院落、中文界面与聚焦镜头；本轮改为96格独立状态并重做光影构图，尚未冻结新候选。
- 模型交接采用显式 GLB；项目关闭 `.blend` 自动导入，编辑源文件保留在 `ArtSource/`。
- 已核验版本、完成资源导入和 Windows x86_64 release 导出，过程退出码为 0。工程直接运行、导出后的独立程序均以 Forward+ / Vulkan 在 RTX 4090 上启动，并在指定迭代数后正常退出，日志无错误。本地日志为 `.local/logs/godot-run.log`、`godot-player.log`；仅证明空工程启动与导出链路可用，不代表画面、窗口交互、玩法或性能验收。
- 未配置CI或第三方测试框架。本轮纯headless `farm_state_test.gd` 237项、`farm_store_test.gd` 289项、`decoration_state_test.gd` 47项均0失败；覆盖逐格隔离、v1/v2迁移、原件留存、坏档和写入失败。实景回归、普通发行包和性能随本轮另验，不复用旧数字。
- 历史原型 Godot 4.7.2 / RTX 4090 的输入路径已验证点田、GUI 返回、拖动不误选、失焦取消、快速换田、恢复微调和紧凑窗口布局。普通 Windows release 随后另做三次真实进程的播种／浇水、关闭、离线成熟、收获和再次重启，隔离主档保留空田与一篮收获，三个进程均退出0；这是存档闭环证据，不代表完整内容或低配性能通过。
- 旧 `Game/` Unity 工程、`.local/unity-validation/`、`.local/foundation/` 与根 Unity 日志已按用户要求删除。Unity / Hub 软件保留，当前工程不再依赖它们。

## 已有工具环境

| 工具 | 状态与用途 |
|---|---|
| Windows / 硬件 | Windows 10 Pro 19045，64 GB、RTX 4090；开发机不能代替低配测试 |
| Git / PowerShell | Git 2.51.1、LFS 3.7.1、PowerShell 7；仓库级 LFS 已配置，远端尚未指定 |
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

焦点细节入口：`tests/focus_detail_audit.gd` 读取实际导入网格的 LOD 索引，`tests/focus_detail_test.gd -- --output=<隔离证据目录> --uncapped` 做真实4K的三组对照与输入回归。Godot 4.7.2 本机实测表明，所有环境网格强制 `lod_bias=0` 会让低面数程序模块的石路、篱柱和桥栏消失；当前按稳定资源路径保留这些模块原层级，复杂模型与非目标作物用自动低档，目标田在镜头到达前恢复高档。只设置导入开关不能代替实际索引、绘制图元和画面检查。

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
| Git LFS 本地可用 | 已完成本地 clean / smudge 往返；真实模型与远端对象上传仍未验证，不等同云端备份成功 |

Godot 命令依据：[CLI 文档](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)；仓库边界依据：[版本控制文档](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html)。

## 成品界面与独立设置验证

Godot 4.7.2 / Windows 10 19045：偏好保存在 `user://preferences/settings.json`，农场仍独立保存在 `user://farm/`；主场景夹具须同时注入 `store` 与 `settings_store` 到隔离目录，避免运行测试改变玩家音量或显示设置。设置 I/O、菜单和场景接线入口分别为 `tests/settings_store_test.gd`、`tests/game_menu_test.gd`、`tests/ui_settings_scene_test.gd`，按既有 `Run -ExtraArgs @('--headless','--script',绝对脚本路径)` 调用。

实际窗口下限由主窗口 `min_size = Vector2i(960,600)` 设置；本版本尝试写 `display/window/size/min_width` / `min_height` 不会改变运行窗口下限。普通发行程序以原生缩窗实测夹持至 960×600；引擎内逻辑布局通过不能替代这项系统窗口验证。中文字体采用随工程分发的 Noto Serif CJK SC，来源与原文件哈希见 `ArtSource/UI/README.md`，字体 OFL 随包保留。

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

本轮已看到 `focus_detail.gd` 全景 `lod_bias=0` 与新源导入自动LOD叠加，会让荷花花瓣消失、Ultra瓦片和窗格扭曲。仅这两件资产关闭 `meshes/generate_lods`，继续使用人工高低档；用相同机位验证，不能误判为云端模型必然缺失部件。4K性能采样曾因用户切回主屏而失焦、降到后台15fps：保留失焦计数并判为受干扰，不反复抢焦点，也不把离线成片60fps当作运行性能。

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
- 默认选择一块真实 3840×2160 屏幕；`-Screen 1` 指定第二屏（从 0 开始）。独占全屏、无标题栏；不更改系统分辨率，不放大低分辨率画面。仅 `movie` 特性下的窗口尺寸覆盖设为 4K，让影片初始化即取得正确尺寸，保留 1280×720 的 UI 逻辑尺度；本机单独传 `--resolution` 后再全屏不足以保证影片初始尺寸。
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
