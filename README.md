# 我有一片田

当前本地候选为 **Demo 0.1.8（开发中试玩版）**：[Windows 免安装文件夹](<.local/releases/0.1.8-7fc08bf8/我有一片田 Demo 0.1.8 Windows/>)、[玩家下载 ZIP](<.local/releases/0.1.8-7fc08bf8/我有一片田 Demo 0.1.8 Windows.zip>)，源码 `7fc08bf87b69bdfd0477b3f55805a7570c065034`。干净克隆导入、导出及包审计通过，ZIP 解压到仓库外后真实启动、保存、重开和正常退出通过；失焦后的进一步点击被验证入口安全拒绝，整套发行交互仍待验收。PCK 1,055,896,704 字节，发行目录 1,165,511,500 字节，ZIP 1,046,911,103 字节。构建及校验记录在 `.local/releases/0.1.8-7fc08bf8/evidence/`；尚未配置 GitHub 远端或上传。

此前分享版本为 **Demo 0.1.7（开发中试玩版）**：[Windows 免安装文件夹](<.local/releases/0.1.7-78fd3d32/我有一片田 Demo 0.1.7 Windows/>)，源码 `78fd3d32`。双击 `Farm.exe`；Windows 原生任务栏图标和导出程序图标已指定为多尺寸 ICO。游戏内容沿用 0.1.6；该版仅导出和审计包体，未启动游戏验收，也未制作安装器。构建入口 `scripts/package-release.ps1 -Commit 78fd3d32 -Version 0.1.7 -FolderOnly -ReuseImportCache`，证据位于 `.local/releases/0.1.7-78fd3d32/evidence/`。

历史 **Demo 0.1.6** 源码 `06c7bce9`，位于 `.local/releases/0.1.6-06c7bce9/`；恢复壁纸系统鼠标旁的种子／工具图标，以及篮子等工具点不适用田格时的扇形菜单。

历史 **Demo 0.1.5** 源码 `1fb4b894`，位于 `.local/releases/0.1.5-1fb4b894/`；已修复辅助访问接口子项计数导致整张壁纸输入失效的问题。

历史 **Demo 0.1.4** 源码 `23250882`，位于 `.local/releases/0.1.4-23250882/`；此版存在上述图标枚举错误，已由0.1.5修复。

历史 **Demo 0.1.3** 源码 `73699975`，位于 `.local/releases/0.1.3-73699975/`。该版会遮挡图标，不符合壁纸外观要求，已由0.1.4替换。

历史 **Demo 0.1.2** 源码 `b1ff06cf`，文件夹保存在 `.local/releases/0.1.2-b1ff06cf/`；此版仍使用桌面采样转发，0.1.3已替换为游玩时原生输入。

历史分享版本 **Demo 0.1.1** 的源码为 `74d24e5e`，旧包保存在 `.local/releases/0.1.1-74d24e5e/`。此版本的壁纸点击行为为返回普通窗口，已在 0.1.2 修正。

历史分享版本为 **Demo 0.1.0（开发中试玩版）**，以 [随包说明](发行材料/使用说明.txt) 和 [版本说明](发行材料/版本说明.txt) 为准；下方 rc 与留存包为历史记录。使用 `scripts/package-release.ps1 -Commit <提交哈希> -Version 0.1.0` 从固定源码独立构建，输出在 `.local/releases/`。本次包为 [我有一片田 Demo 0.1.0 Windows.zip](<.local/releases/0.1.0-c2451af7/我有一片田 Demo 0.1.0 Windows.zip>)，源码 `c2451af7`，约1.95 GB。独立导入／导出、1126项资源审计、ZIP解压哈希、仓库外中文空格路径启动／菜单版本／保存重开／正常退出均通过；设置界面80项检查通过。证据在 `.local/releases/0.1.0-c2451af7/evidence/` 与 `.local/verification/demo-0.1.0/`。未验证其他硬件，首次启动需等待资源加载。分享 ZIP 即可，不包含开发者存档；当前存档目录为 `farm-v27/`，格式以 `Game/farm/farm_store.gd` 为准，不承诺后续版本兼容。

历史完整留存版（2026-09-18）：[打开版本目录](.local/snapshots/20260918-98797da/我有一片田_田园生活版_20260918/)，双击「开始游戏.cmd」。动物、小院参数化及完整低压力生活玩法已接通；按用户要求跳过乘船慢游。包内存档独立，旧版保留。[目标与验证边界](docs/task/动物与田园生活完整目标清单.md#最终交付记录--20260918)。

Windows 三维微缩农场。六块大田各分为4×4小格，可混种十二种江南秋菜，按格播种、浇水、现实时间生长与收获；江南院落含三件可解锁装饰、昼夜、声音、焦点细节及景深。农场和声音／显示设置分别保存在当前用户目录。作物数值、参考图与新模型来源见 [秋菜记录](ArtSource/Crops/Autumn2026/README.md)。当前开发版支持独立桌面壁纸：设置中点击「设为桌面壁纸」，双击系统托盘图标返回游戏；无需其他壁纸软件。账号联网和云存档不在当前范围。桌面组件与实测边界见 [桌面组件](native/desktop/README.md)，页首历史留存包未包含此功能。

制作基准见 [制作基准包](docs/design-baseline/README.md)，首个版本验收见 [首个版本计划](docs/task/首个可发布版本/00-任务总览.md)，当前逐格种植与画面重构已通过功能、实景与本机性能回归，独立候选验证另见[逐格整合交接](docs/task/格子农田与画面重构/handoffs/整体验证-handoff.md)；前一轮动态氛围的历史证据见[氛围整合交接](docs/task/氛围提升/handoffs/整体验证-handoff.md)。单体图、Tripo、Blender 与 Godot 的实际分工见 [三维资产工作流](docs/asset-workflow.md)。商务核验按用户要求暂缓，本地候选不冒称权利清理、签名或商店上架完成。

## 打开与开发

使用 **Godot 标准版 + 带类型标注的 GDScript**，暂用 Forward+ 渲染。精确引擎版本由 [.godot-version](.godot-version) 固定，导出模板必须与之匹配；无需 .NET 版或额外 AI 桥接服务。

从仓库根目录运行（Windows / PowerShell 7）：

```powershell
pwsh -NoProfile -File scripts/godot.ps1 Editor
pwsh -NoProfile -File scripts/godot.ps1 Run
pwsh -NoProfile -File scripts/godot.ps1 Import
pwsh -NoProfile -File scripts/godot.ps1 ExportWindows
```

`Run` 会自动关闭本项目正在运行的开发游戏并重启，默认静音、第二屏真正全屏；不关闭编辑器、其他项目、测试或录制。Debug 版点击右上角时钟可拖动滑块预览一天中的光影，再点“恢复实时”。当前早期开发不承诺旧存档兼容，验证按改动范围选择；入口与定向验证见[开发迭代约定](docs/development-setup.md#当前开发迭代约定2026-09-17)。

也可在 Godot 项目管理器导入 [Game/project.godot](Game/project.godot)，打开 `scenes/main.tscn`，按 F6 运行当前场景或 F5 运行工程。首次进入创建并保存六田共96格，之后恢复同一农场；作物的幼芽、幼株、成熟资源跟随权威状态变化。

操作：点击底部“播种”展开蔬菜，选好后悬停土地预览小格，左键点击播种；可连续种植，拿着种子时滚轮切换菜种。点击“工具”展开浇水、收获、除草和开垦，选择后点击目标格执行。右键、Esc 或取消按钮放下工具并收起选项，滚轮恢复缩放。空手点击大田靠近，中键微调角度，Shift + 中键平移。“全景”返回，“复位”恢复构图。自由视角左键绕点击处旋转，中键／右键平移，滚轮缩放。“布置”处理已解锁装饰；“设置”包含音量、显示、操作与来源。空手点击可见的厨房、晒架、陶罐、廊桌可打开厨房，点击三户邻岛可打开对应邻里页面；拖动镜头和拿着农具时不会触发这些入口。厨房食材和邻居回礼采用与播种一致的上图下字卡片。历史候选包的随包说明仅对应其自身版本。

Windows 导出后可直接运行 `.local/builds/windows/Farm.exe`，同目录 `Farm.pck` 和 `FarmDesktop.exe` 必须保留。开发启动／导出会编译桌面组件，开发机需 CMake 与 Visual Studio 2022 C++ Build Tools；玩家不需要编译工具。原型的真实截图、处理后模型和贡献报告副本在本地 `制作留档/`，不参与 Git 同步。

Windows 图标分两处配置：`Game/project.godot` 的 `config/windows_native_icon` 供运行时任务栏使用，`Game/export_presets.cfg` 的 `application/icon` 供导出的程序文件使用，两者都指向包含 16～256 像素尺寸的 `Game/art/ui/game-icon.ico`。ICO 由现有 PNG 用 `magick Game/art/ui/game-icon.png -define icon:auto-resize=256,128,64,48,32,16 Game/art/ui/game-icon.ico` 生成。仅设置通用 `config/icon` 不能代替 Windows 原生任务栏图标；旧图标残留时先刷新 Windows 图标缓存，再判断新包。

发行候选必须从已验收的明确提交构建。待根代理固定候选提交与版本后使用：

```powershell
pwsh -NoProfile -File scripts/package-release.ps1 -Commit <完整提交哈希> -Version <与该提交配置一致的版本>
```

此入口新建 `.local/releases/<版本>-<提交前8位>/`，从本地独立克隆恢复并校验 LFS 对象，在无原导入缓存的副本导入、构建，审计 PCK 后附中文说明、Godot / 字体通知、版本和 SHA-256。既有候选不会覆盖；本地克隆不是远端或异机同步证明。构建完成后仍须在仓库外中文／空格路径，用非管理员和隔离用户目录进行真实启动、保存、回访与退出验收。首个候选验证状态见 [5.2 任务](docs/task/首个可发布版本/任务/第五阶段-发行候选与交付/5.2-构建发行候选并验证干净环境.md)，历史 rc.2 的独立证据见 [氛围修订交接](docs/task/氛围提升/handoffs/整体验证-handoff.md)。

本地空间：`.local/builds/` 和 `Game/.godot/` 可从源码重建；发行目录中的 `source/` 是逐版重复的独立构建副本，确认包、ZIP、校验和及 `evidence/` 完整后，可在新构建命令加 `-PruneBuildSource`，只清理该次候选的 `source/` 并留下清理记录。历史 `.local/releases/` 的包与证据先保留，逐项核对后再清理；`ArtSource/`、`制作留档/` 和 `视频制作素材/` 可能含唯一源资料，不作为缓存清除。源码和必要资产通过 Git＋LFS 管理，玩家下载 ZIP 放发行附件，不把发行包提交进源码仓库。

历史本地候选 **0.1.0-rc.2** 对应源码 `a3163dcc216e049b9ca873458807e925d6908df2`，包含近景枝叶、植物风动、湖波倒影、轻舟、远云及暖窗与院落细节，仍是整田玩法／v2存档。独立干净构建和仓库外普通程序的收获／播种／浇水／保存重开已通过；96株新场景的1080p烟测164项、4K六组56项均0失败。交付副本 `制作留档/06_发行候选/0.1.0-rc.2-a3163dcc/我有一片田 0.1.0-rc.2 Windows.zip`，旁有同名 `.sha256`；ZIP SHA-256为 `cce4f8face420cff1e252e3c04ec1312a2a0e8a62568439176c60253578598d8`。详情及实测硬件／边界见[氛围整合交接](docs/task/氛围提升/handoffs/整体验证-handoff.md)。

历史本地候选 **0.1.0-rc.5** 对应源码 `8f39fd66b579dc4870e279fa0baff53554f1b357`：修复土面块状凹凸、田边与草地的材质及高度接缝，增加基脚风化过渡，调校全分辨率环境光遮蔽与接触暗部。六田96格、两作物和v3存档不变。462项相关布局／输入／场景／表面／4K焦点检查通过；RTX4090前台4K满田短测正常LOD全景／聚焦GPU中位5.40／5.82ms，不代表低配或长期稳定性认证。独立干净构建、254项PCK资源审计和仓库外普通程序启动／选格／播种／浇水／保存重开验证通过。本地包为 `制作留档/06_发行候选/0.1.0-rc.5-8f39fd66/我有一片田 0.1.0-rc.5 Windows.zip`，SHA-256 `3bf7ed78e9c6a59cd774fd3bb90137fcd066bad3a957406f512138c7c7b9c227`；旁有构建与实机证据。020号24秒4K60有声离线演示1440帧、音画等长和运动检查通过。研究及边界见[开发准备](docs/development-setup.md)：SSAO并非完整GI，也不能自动修复任意模型相交。rc.4与019号素材保留为历史；未发布到商店或远端。

历史本地候选 **0.1.0-rc.3** 对应源码 `8f93348ef8b3eb649729e78e23def540e1db36a5`：96格混种／v3存档、降低并拉近的全景、近岸植物前景、光影材质和桥岸修订。独立干净构建、外部普通程序混种／逐格护理收获／保存重开、真实v2升级已通过；本机1080p烟测164项和4K六组56项通过。交付副本 `制作留档/06_发行候选/0.1.0-rc.3-8f93348e/我有一片田 0.1.0-rc.3 Windows.zip`，SHA-256为 `8aba6b131b8ff81dcea23ca5f6b342d87bd438c9cd6cf2f9a770ddc1c9a34743`。018号56秒4K有声演示使用隔离混种示例，不是玩家进度或实时性能证据。实际验证、首次失败记录和边界见[该轮整合交接](docs/task/格子农田与画面重构/handoffs/整体验证-handoff.md)；旧rc.1／rc.2均仅作历史保留。

保留历史本地候选 **0.1.0-rc.1**，固定提交 `6b460f30aea1cf20f5ac086c7418f9b2557f9e23`。交付副本为本机 `制作留档/06_发行候选/0.1.0-rc.1-6b460f30/我有一片田 0.1.0-rc.1 Windows.zip`，旁有同名`.sha256`；ZIP SHA-256为 `56c9a10c5aca52ed21c3676217cfef43155b4065eb1bddd6379b4991c3b77b83`。独立干净构建、仓库外中文空格路径普通权限运行与真实收获／播种／浇水／保存重开已通过，完整路径、校验和边界见 [5.2交接](docs/task/首个可发布版本/handoffs/5.2-handoff.md)。包不进入Git，仍未签名／未上架，同包三装饰解锁／摆放／重开及固定参考对照已通过开发侧验收，详见[5.3交接](docs/task/首个可发布版本/handoffs/5.3-handoff.md)；不代表用户主观签收。

开发留档录屏使用 `scripts/record.ps1`：按需打开 4K 全屏窗口，自动展示逐帧输出后使用显卡编码 H.264 / 60 fps（离线演示，非性能证明），视频和中文索引保存到 `制作留档/05_开发录屏/`。自动慢镜头、手动操作和 F9 提前结束的用法见 [开发准备](docs/development-setup.md#开发录屏)。普通启动不录制。

本机桌面已有 **我有一片田 - Godot** 快捷方式，可直接打开正式工程。

引擎安装在仓库外。启动脚本按固定版本查找 `%LOCALAPPDATA%/Godot/<版本>/`；其他机器可设置 `GODOT_EXE` 指向对应 console 可执行文件。安装、模板位置和验证边界见 [开发准备](docs/development-setup.md)。

## 目录与同步边界

| 位置 | 用途 | Git 同步 |
|---|---|---|
| `Game/` | 正式 Godot 工程；`res://` 从这里开始 | 场景、资源、脚本、导入设置与 UID 同步，`.godot/` 缓存排除 |
| `Game/scenes/` | 可复用场景与紧密相关脚本；主入口 `main.tscn` | 同步 |
| `Game/art/` | 实际采用的 GLB、贴图、音频等运行资源 | 同步；二进制类型使用 LFS |
| `native/desktop/` | 独立 Windows 桌面组件源码与构建说明 | 源码同步；编译产物放 `.local/` |
| `ArtSource/` | Blender 可编辑源文件、源贴图、已采用生成资产与来源记录 | 同步；二进制类型使用 LFS |
| `scripts/`、`.agents/skills/` | 开发入口与固定版本的项目技能 | 同步；不进入游戏导出 |
| `docs/`、`rules/`、`AGENTS.md` | 开发资料与协作规则 | 同步 |
| `docs/visual-references/` | 已整理交付的设计参考图与生成记录；候选状态在制作草案中注明 | 同步；图片使用 LFS |
| `docs/design-baseline/` | 当前玩法与美术基准包、候选对照和必要来源；替代旧草案作为制作入口 | 同步；图片使用 LFS |
| `docs/ref/` | 本地参考资料和图板 | 不同步 |
| `.local/` | 试验、候选、下载、截图、日志、构建与测试存档 | 不同步 |
| `制作留档/` | 视频和报告素材副本：提示词、参考图、Tripo 原始模型、处理证据与最终去向 | 按用户要求全目录不同步；本地入口为 `制作留档/README.md` |
| `.tripo/` | Tripo CLI 自动产生的本地任务上下文 | 不同步；采用成果单独保存 |

需要独立规则代码、配置或正式测试时，再按职责增加目录，不先创建空框架。正式代码、源模型和导出模型均保存在本仓库，不依赖桌面或下载目录。被忽略的内容不会得到 Git 备份。

## 模型制作与修改

例如白菜：源文件放 `ArtSource/Crops/Cabbage/`，GLB 与贴图放 `Game/art/crops/cabbage/`，组合玩法的 `.tscn` 放相应场景目录。源资产和实际使用的导出物都保留。

- 当前交接优先显式导出 GLB；`.blend` 留在 `Game/` 外，避免克隆和构建依赖本机 Blender 自动转换。模型、材质与动画仍须在 Godot 验收。
- 导入模型外面建立可编辑的组合场景来添加碰撞、交互与脚本；不要直接改导入缓存。重导出覆盖模型时保留旁边的 `.import` 设置；移动脚本、Shader 时连同 `.uid`，检查路径和场景引用。
- Blender 外部贴图使用仓库内相对路径或按需打包；`.blend1` 等自动备份不入库。二进制资产不能可靠自动合并，修改同一文件前先协调。
- 已采用生成资产保留必要任务参数、模型版本、来源和使用依据；未采用候选放 `.local/experiments/`。密钥与账号配置不入库。
- 工具分工和验收见 [三维资产工作流](docs/asset-workflow.md)。扩展名统一小写，Godot 场景、脚本、资源文件名采用 `snake_case`。

## 试验、存档与异机恢复

- 临时试验放 `.local/experiments/<名称>/`，需要 Godot 时在其中建独立工程。正式工程不得引用 `.local/` 或 `docs/ref/` 中的必要资源。
- 采用试验成果时迁入选定源文件、导出物和必要依赖，重新导入检查；不复制整个试验工程或缓存。
- **正式回归测试代码入库**；临时脚本、报告、测试存档排除。不使用 `*test*`、`Tests/` 或全局 `*.json` 之类过宽忽略规则。
- 当前开发存档使用 `%APPDATA%/Godot/app_userdata/我有一片田/farm-v27/`，偏好使用同级 `preferences/`。主农场为 v27 `farm.json`，包含时令主题、田格除草／开垦状态、田块布局、地面高度／岸坡、围栏样式、作物、食材库存、邻里往来、厨房制作／食记、六种可布置物件及七只动物的名字／休息偏好／互动记录，以及见闻标记和相册元数据；相册原图位于同目录 `album/`，上一有效副本为 `farm.backup.json`。早期开发不维护旧版兼容：旧 `farm/`、`farm-v4/`、`farm-v5/`、`farm-v6/`、`farm-v7/`、`farm-v8/`、`farm-v9/`、`farm-v10/`、`farm-v11/`、`farm-v12/`、`farm-v13/` 和留存版保持原件，不迁移历史数据。坏件、未知版本与写入失败不会被静默重置。测试同时注入隔离 farm 与 settings；普通发行验证使用 `tests/start-isolated-game.ps1` 的进程级 APPDATA / LOCALAPPDATA，不能覆盖玩家数据。
- 换电脑前安装 Git LFS；克隆后执行 `git lfs install --local`、`git lfs pull`，安装固定引擎和 Windows x86_64 模板，再执行 `Import`。`.uid`、`.import`、`export_presets.cfg` 应随源文件提交；`.godot/`、导出凭据和构建产物排除。
- 当前远端尚未指定。连接后核验托管平台 LFS 支持、额度、对象上传和独立克隆；本地提交不等于云端备份，不擅自创建公开仓库。

协作入口：[AGENTS.md](AGENTS.md)；资料与技能选择：[Godot 资料及工具](docs/godot-resources.md)。
