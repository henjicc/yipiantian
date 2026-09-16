# 开发前准备与环境验证

> 环境首次核验：2026-09-16；Godot 基础配置：2026-09-17。目标为 Windows 窗口版三维农场；尚无种植玩法。用户已决定切换引擎，不做选型对比样片。

## Godot 安装与日常入口

- 当前使用由 Codex 下载配置的 **Godot 4.7.2 标准版（非 .NET）**；本机 `--version` 为 `4.7.2.stable.official.ed1daf0bf`。用户另放在 D 盘的副本不使用、不由本任务删除。
- 安装目录：`%USERPROFILE%/AppData/Local/Godot/4.7.2-stable/`。GUI 为 `Godot_v4.7.2-stable_win64.exe`，自动化入口为同目录 `Godot_v4.7.2-stable_win64_console.exe`。
- 本机桌面已创建 **我有一片田 - Godot** 快捷方式，直接打开正式 `Game/` 工程。它属于本机入口；换电脑使用 README 命令或重新创建快捷方式。
- Windows x86_64 的 debug / release 模板安装在 `%USERPROFILE%/AppData/Roaming/Godot/export_templates/4.7.2.stable/`，未安装其他平台模板。引擎与模板来自 [官方下载页](https://godotengine.org/download/windows/) 及 [对应发布](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)，两个下载包均通过该发布 `SHA512-SUMS.txt` 校验。
- 本机软件路径只记在本文，工程启动脚本通过用户目录和根 [.godot-version](../.godot-version) 定位，不把账号路径写死进游戏。换位置时传 `-GodotPath` 或设置环境变量 `GODOT_EXE`，精确版本不符时入口拒绝执行。
- 标准版包含脚本编辑器、调试器和 CLI，可直接开始；当前无需 .NET SDK、C++ 工具链、Godot MCP、联网账号或 LLM API Key。
- 日常执行根 [README](../README.md) 的 Editor / Run / Import / ExportWindows 入口。导出结果为 `.local/builds/windows/Farm.exe` 与 `Farm.pck`，两者一起保留；不要只搬 exe。当前未配置签名与自定义程序图标，发行打包时再处理。

## 工程基线与验证边界

- `Game/project.godot` 使用 GDScript 标准版，Forward+ / Vulkan，1280×720 可调整普通窗口；已有六田简易场景、Tripo 青菜与聚焦镜头。当前是布局和手感确认原型，不锁定最终美术。
- 模型交接采用显式 GLB；项目关闭 `.blend` 自动导入，编辑源文件保留在 `ArtSource/`。
- 已核验版本、完成资源导入和 Windows x86_64 release 导出，过程退出码为 0。工程直接运行、导出后的独立程序均以 Forward+ / Vulkan 在 RTX 4090 上启动，并在指定迭代数后正常退出，日志无错误。本地日志为 `.local/logs/godot-run.log`、`godot-player.log`；仅证明空工程启动与导出链路可用，不代表画面、窗口交互、玩法或性能验收。
- 未配置 CI 或第三方测试框架；已有原型交互冒烟脚本 `tests/prototype_smoke.gd`，尚无农场模拟或存档测试套件，不声称全部玩法通过。Blender / Tripo 进入 Godot 的真实资产、窗口交互、存档与后台性能随对应任务验证。
- 原型已在 Godot 4.7.2 / RTX 4090 实际渲染，全景、聚焦和 960×600 窗口截图保存在 `.local/prototype-validation/`。真实输入路径测试覆盖点田、GUI 返回、拖动不误选、失焦取消、快速换田、返回途中再选田、恢复微调后的全景以及按钮布局；退出码为 0。Windows release 已重新导出；这不代表种植、存档或低配性能通过。
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
| Windows 截图接口失败 | 本机 `SetIsBorderRequired / 0x80004002` 后使用 Blender 官方截图接口成功；不外推所有 Windows 均不支持，不关闭安全功能 |
| 双屏坐标不一致 | 先查当前排列、分辨率与实际窗口；本机两屏均 2560×1440，副屏在右。坐标不写成跨机器保证 |
| PowerShell 长时间无输出 | 先用不加载个人 profile 的调用排查；本机 `login=false` 有效，未擅自修改用户 profile |
| Git LFS 本地可用 | 已完成本地 clean / smudge 往返；真实模型与远端对象上传仍未验证，不等同云端备份成功 |

Godot 命令依据：[CLI 文档](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)；仓库边界依据：[版本控制文档](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html)。

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
- 两块屏幕均检测为 2560×1440，副屏在主屏右侧。实测 AI 窗口位置为 x=2640、y=100，大小 1200×1000；Windows 缩放可能导致应用坐标与物理像素有差异，后续按实际窗口核对。

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

已从 0.4.0 源码核验：`game-pc` 是高预算详细材质预设，`game-mobile` 默认 15,000 面与 2K 贴图；它们都不是本农场已批准的资产标准，不能因目标是 Windows 就自动选择高预算预设。实际预算按单个资产的显示尺寸、数量及画面要求确定。

自动化注意：`make` 默认阻塞等待并下载结果，`task watch --json` 返回进度流；持续等待已有进程与任务，不因请求暂时无响应就再发一次生成。保存任务 ID、参数、用量及本地产物，预览未达标时在已授权迭代范围内处理，不进行无上限重生成。批处理与多候选会扩展消耗，执行前先核对用户已授权数量、处理步骤和预算，已有明确授权不重复询问。

详细接口按需读取本机包内文档：`tripo.cmd docs --topic commands/make`、`tripo.cmd docs --topic examples/game-asset`。本机帮助显示无交互模式会自动跳过 CLI 确认，因此不能把工具自身的提示当作费用边界。

插件配置核验所得经验：技能以 CLI 为执行入口时，先复用已验证的运行时和账号，再做健康检查；不因安装插件重复登录或另起服务。技能标明部分预设会附带收费转换步骤，生成时核对最终需要的格式及完整处理链；输出位置以实际结果中的 `model_file` / `output_dir` 为准。插件说明中的参数和服务限制不能仅凭本次健康检查视为已实测，首次使用对应能力时再核对并验证。

## 后续需要用户准备的内容

1. 软件方面当前没有必须补装项。Godot、Blender 与 Tripo 已有入口；遇到特定需求再添加工具。
2. 确定首个可玩闭环与画面目标，例如一种作物的播种、生长、收获和保存重开；这仍是候选，不自动开工。
3. 需要云端同步时提供仓库地址或指定托管平台与可见性；现阶段只做本地 Git 提交。
4. 风格样本出现后由用户判断审美，技术检查由开发侧完成；当前不需要购买新资产或付费生成样本。

官方文档、社区检索入口、已安装技能及未采用框架见 [Godot 资料及工具](godot-resources.md)。
