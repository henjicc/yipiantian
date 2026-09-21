# 独立桌面壁纸组件

设置 →「设为桌面壁纸」把正在运行的农场放到当前显示器的桌面图标下方。双击系统托盘图标返回游戏；托盘右键可返回或保存退出。进入前保存农场与设置；壁纸保持静音；未遮挡农具悬停高亮，点击后在壁纸原位显示控件并拿起工具，结束桌面操作后收起控件。桌面图标保持正常操作，拖动不唤醒。没有开机启动或退出后常驻。

发行文件为同目录的 `Farm.exe`、`Farm.pck`、`FarmDesktop.exe`。玩家无需安装 Godot、Lively、Wallpaper Engine 或编译环境。桌面宿主只在壁纸模式存在，不读取农场存档。

多屏范围：同一时间只展示在一块屏幕上，以进入时游戏所在屏幕为目标；其他屏幕保持原桌面，不跨屏拉伸或复制。当前换屏方式是返回窗口模式，把游戏移到目标屏幕，再点击「设为桌面壁纸」。覆盖检测只计算目标屏幕，另一块屏幕上的窗口不会单独触发限帧。

## 构建与职责

开发机需要 CMake、Visual Studio 2022 C++ Build Tools 和 Windows SDK。仓库根目录执行 `pwsh -NoProfile -File scripts/build-desktop.ps1`，输出 `.local/builds/windows/FarmDesktop.exe`；普通开发启动和 Windows 导出已自动调用。MSVC 使用静态运行库，宿主只链接 Windows 系统组件。

- `main.cpp`：校验传入 HWND 属于直接父进程；负责桌面层、原生样式、托盘、显示器和会话通知。通过持有的父进程句柄监测生命周期。宿主正常结束前解除挂接；父游戏结束后退出。
- `Game/platform/desktop_wallpaper.gd`：启动同包宿主，通过继承的匿名管道收发逐行状态，保存并恢复 Godot 窗口状态。没有网络端口或任意窗口指令。仅挂接期间安装低级鼠标钩子，不采集键盘；操作模式截取已确认空白桌面的按钮与滚轮，其他程序和图标输入不转发。钩子不进行 Accessibility 查询、管道写入或同步消息；宿主在钩子外采样、复核桌面角色，缓存过期或点位变化时不截取。离开有效区域取消手势。
- `Game/atmosphere/window_activity.gd`：唯一的呈现帧率管理者。壁纸可见时最高 30 fps，目标屏幕被普通不透明窗口覆盖超过 95% 或锁屏时最高 2 fps；不暂停场景树和现实时间结算。此限帧策略不是 CPU/GPU 耗电达标证明。

输入状态为 `POINTER x y`、`BUTTON button pressed x y factor`、`LEAVE`；坐标为游戏客户区归一化坐标。`INTERACT` / `OBSERVE` 切换操作与观赏，不解除桌面挂接；不传递键盘或其他程序输入。

管道命令只有 `RESTORE` 和 `STOP`；状态为 `ATTACHING`、`ATTACHED`、`VISIBLE`、`COVERED`、`RESTORING`、`RESTORED`、`QUIT`、`ERROR <阶段> <Windows错误码>`。退出意图先发送，窗口恢复完成、宿主退出后才由游戏执行正常保存退出。

## 版本约束与复核

2026-09-18 在 Windows 10 19045、Godot 4.7.2、Vulkan Forward+、RTX 4090、双 4K 屏幕上编译并验证。`tests/desktop_wallpaper_test.gd` 使用隔离存档运行真实农场，两次进入／返回均通过，验证窗口尺寸与位置、界面与输入恢复、宿主退出、30/2 fps 上限；截图位于 `.local/verification/desktop-1789735403/`。Windows 导出与独立程序启动、正常关闭通过。用户要求减少桌面自动操作，托盘实际点击、全屏往返、锁屏、屏幕拔插和 Explorer 重启没有实机验收；Windows 11 与混合 DPI 也尚未验证，不作全版本兼容承诺。

定向复核入口（会短暂改变游戏窗口，使用电脑时勿自动反复运行）：

```powershell
& ./scripts/godot.ps1 -Action Run -ExtraArgs @('--script', (Join-Path (Get-Location) 'tests/desktop_wallpaper_test.gd'))
```

也可直接调用固定版本引擎，以 `--path Game --screen 0 --audio-driver Dummy --script <测试脚本绝对路径>` 运行。测试支持用户参数 `-- --evidence=<证据绝对目录>`，供独立导出程序的定向复核使用。

实测排错约束：让原生宿主在挂接时扩展到屏幕大小，不要预先把 Godot 窗口铺满屏幕后才保存原生矩形。Godot Windows 后端会按实际矩形判断全屏，此时普通 resize 被忽略。返回时先恢复原生窗口，再显式恢复 DisplayServer 窗口模式与 Godot 几何。挂接／返回期间临时恢复 60 fps 消息处理，完成后恢复原策略，避免低帧率拖慢跨进程同步窗口消息。

桌面层依赖 Explorer 的非公开 `WorkerW/Progman` 行为。代码包含旧式 WorkerW 与 raised desktop 分支、父窗口失效检测和有限重挂；这些不等于 Explorer 崩溃、强制终止宿主或所有系统更新都能自动恢复。验证时不得为此擅自重启用户 Explorer。

## 直接参考

- [Lively 的 WinDesktopCore](https://github.com/rocksdanister/lively/blob/core-separation/src/Lively/Lively/Core/WinDesktopCore.cs)：成熟的桌面层查找、Windows 新桌面层与 Godot 挂接顺序参考。上游 GPL-3.0；本模块独立实现，没有引入其源码或运行时。
- [tauri-plugin-wallpaper](https://github.com/meslzy/tauri-plugin-wallpaper/tree/867f97eedf64231df64c3f062f0fb6ceee6c9f4f)：独立应用挂接／解除、输入和重挂的结构参考；本项目不引入 Tauri；当前仅将筛选后的桌面空白点击用于农具唤醒。
- [Microsoft SetParent](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setparent)：窗口样式需由调用方处理，跨进程 DPI 行为有约束。不能把桌面嵌入称为官方壁纸 API。
- [Godot Windows 后端](https://github.com/godotengine/godot/blob/4.7-stable/platform/windows/display_server_windows.cpp)：`WM_WINDOWPOSCHANGED` 的全屏识别和 `window_set_size` 的模式限制。

后续优先根据玩家在目标 Windows 版本上的反馈修正；不把成熟宿主的全部设置、播放器或下载功能搬进游戏。

## Demo 0.1.1

加入点击门口农具返回游戏，构建随包宿主。按用户要求本轮仅构建打包，不运行功能测试或桌面实机验收；上方2026-09-18证据仅属于旧的托盘返回实现，不能作为新增唤醒入口的通过证明。
实现参考：[Raw Input](https://learn.microsoft.com/en-us/windows/win32/inputdev/using-raw-input)、[AccessibleObjectFromPoint](https://learn.microsoft.com/en-us/windows/win32/api/oleacc/nf-oleacc-accessibleobjectfrompoint)。
## 2026-09-22 Demo 0.1.2
改为原位桌面交互和悬停高亮，提供 FolderOnly 构建；用户要求仅构建，未运行交互验收。低级鼠标钩子约束参考 [LowLevelMouseProc](https://learn.microsoft.com/en-us/windows/win32/winmsg/lowlevelmouseproc)。
