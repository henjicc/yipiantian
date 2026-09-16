# 我有一片田

Windows 普通窗口版三维微缩农场。当前建立开发基础，尚未实现种植玩法；桌面壁纸宿主后置，首个可玩切片另行确定。

开始制作先看 [玩法、操作与首轮制作草案](docs/production-brief.md)：包含资料提炼、可玩切片建议、新运行画面参考与待定范围；具体工具分工见 [三维资产工作流](docs/asset-workflow.md)。

## 打开与开发

使用 **Godot 标准版 + 带类型标注的 GDScript**，暂用 Forward+ 渲染。精确引擎版本由 [.godot-version](.godot-version) 固定，导出模板必须与之匹配；无需 .NET 版或额外 AI 桥接服务。

从仓库根目录运行（Windows / PowerShell 7）：

```powershell
pwsh -NoProfile -File scripts/godot.ps1 Editor
pwsh -NoProfile -File scripts/godot.ps1 Run
pwsh -NoProfile -File scripts/godot.ps1 Import
pwsh -NoProfile -File scripts/godot.ps1 ExportWindows
```

也可在 Godot 项目管理器导入 [Game/project.godot](Game/project.godot)，打开 `scenes/main.tscn`，按 F6 运行当前场景或 F5 运行工程。当前场景只有相机、灯光和环境，运行时是空白背景，不代表农场画面。

本机桌面已有 **我有一片田 - Godot** 快捷方式，可直接打开正式工程。

引擎安装在仓库外。启动脚本按固定版本查找 `%LOCALAPPDATA%/Godot/<版本>/`；其他机器可设置 `GODOT_EXE` 指向对应 console 可执行文件。安装、模板位置和验证边界见 [开发准备](docs/development-setup.md)。

## 目录与同步边界

| 位置 | 用途 | Git 同步 |
|---|---|---|
| `Game/` | 正式 Godot 工程；`res://` 从这里开始 | 场景、资源、脚本、导入设置与 UID 同步，`.godot/` 缓存排除 |
| `Game/scenes/` | 可复用场景与紧密相关脚本；主入口 `main.tscn` | 同步 |
| `Game/art/` | 实际采用的 GLB、贴图、音频等运行资源 | 同步；二进制类型使用 LFS |
| `ArtSource/` | Blender 可编辑源文件、源贴图、已采用生成资产与来源记录 | 同步；二进制类型使用 LFS |
| `scripts/`、`.agents/skills/` | 开发入口与固定版本的项目技能 | 同步；不进入游戏导出 |
| `docs/`、`rules/`、`AGENTS.md` | 开发资料与协作规则 | 同步 |
| `docs/visual-references/` | 已整理交付的设计参考图与生成记录；候选状态在制作草案中注明 | 同步；图片使用 LFS |
| `docs/ref/` | 本地参考资料和图板 | 不同步 |
| `.local/` | 试验、候选、下载、截图、日志、构建与测试存档 | 不同步 |

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
- 游戏存档使用 `user://`，实现测试时使用隔离位置或独立项目名，不能覆盖真实玩家数据。目前没有存档实现。
- 换电脑前安装 Git LFS；克隆后执行 `git lfs install --local`、`git lfs pull`，安装固定引擎和 Windows x86_64 模板，再执行 `Import`。`.uid`、`.import`、`export_presets.cfg` 应随源文件提交；`.godot/`、导出凭据和构建产物排除。
- 当前远端尚未指定。连接后核验托管平台 LFS 支持、额度、对象上传和独立克隆；本地提交不等于云端备份，不擅自创建公开仓库。

协作入口：[AGENTS.md](AGENTS.md)；资料与技能选择：[Godot 资料及工具](docs/godot-resources.md)。
