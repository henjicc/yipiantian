# 我有一片田

一款以江南水乡为背景的三维田园游戏。种菜、布置小院、做饭、拜访邻居，也可以让农场在桌面上陪你度过白天与夜晚。目前开放 **Windows 开发中试玩版**。

[下载 Demo 0.1.8](https://github.com/henjicc/yipiantian/releases/download/v0.1.8/Demo.0.1.8.Windows.zip) · [查看版本说明](https://github.com/henjicc/yipiantian/releases/tag/v0.1.8) · [反馈问题](https://github.com/henjicc/yipiantian/issues)

| 白天 | 夜晚 |
|:---:|:---:|
| ![白天的农场画面](docs/images/gameplay-main.jpg) | ![夜晚的农场画面](docs/images/gameplay-main-night.jpg) |

## 开始试玩

1. 下载上方的 Windows ZIP，解压整个文件夹。
2. 双击 `Farm.exe`。请让 `Farm.pck` 和 `FarmDesktop.exe` 留在同一文件夹。
3. 在游戏中点击田地开始种植；底部菜单可打开工具、建设和设置。

请下载 **Release 附件**；GitHub 自动提供的 “Source code” 压缩包不能直接运行游戏。本版仅提供 Windows x86-64 程序，尚未签名。[SHA-256 校验文件](https://github.com/henjicc/yipiantian/releases/download/v0.1.8/Demo.0.1.8.Windows.zip.sha256)与下载包放在同一页面。

## 在农场里

- 在六块田的独立田格里种植十二种秋菜，在菜架种丝瓜；浇水、除草、收获，生长随现实时间推进。
- 布置庭院、制作食物、照看动物，与邻居往来。
- 看植物随风摆动、湖面与昼夜光影变化；也可切换桌面观赏与交互。

**基本操作：** 点击田格打开动作菜单，选择种子或工具后点击目标；滚轮缩放，按住中键或右键拖动调整视角，右键或 `Esc` 取消当前工具。完整说明、存档位置和已知限制见[随包使用说明](发行材料/使用说明.txt)。试玩版仍在开发中，旧开发存档不保证兼容。

## 从源码运行

工程使用 Godot 4.7.2 标准版（固定版本见 [.godot-version](.godot-version)）、GDScript 和 Forward+。源码及必要美术资产由 Git LFS 管理；克隆前请安装 Git LFS。Windows 开发入口需要 PowerShell 7，运行与导出还需要 CMake、Visual Studio 2022 C++ Build Tools 和 Windows SDK。

```powershell
git clone https://github.com/henjicc/yipiantian.git
cd yipiantian
git lfs pull
pwsh -NoProfile -File scripts/godot.ps1 Import
pwsh -NoProfile -File scripts/godot.ps1 Editor
```

编辑器打开后按 `F5` 运行游戏。Windows 导出需安装与 Godot 版本匹配的导出模板，再运行 `pwsh -NoProfile -File scripts/godot.ps1 ExportWindows`。

`Game/` 是 Godot 工程，`ArtSource/` 保存可编辑美术源文件，`native/desktop/` 是 Windows 桌面组件。开发与发行入口见[开发环境](docs/development-setup.md)和[Windows 发行工作流](.github/workflows/release-windows.yml)；模型制作见[三维资产工作流](docs/asset-workflow.md)。玩家下载包放在 Releases，不提交到源码仓库。

## 反馈与维护

遇到问题可在 [Issues](https://github.com/henjicc/yipiantian/issues) 留下复现步骤、游戏版本和系统信息。项目由 [@henjicc](https://github.com/henjicc) 维护。
