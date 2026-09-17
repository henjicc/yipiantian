# 氛围提升 rc.2 候选交付

2026-09-17，开发侧本地候选验收完成，未签名、未上架；不代表用户审美签收或商务核验完成。生产源固定为 `a3163dcc216e049b9ca873458807e925d6908df2`，版本 `0.1.0-rc.2`。此次只用新包验收，不沿用 rc.1 哈希和性能结论。

## 干净构建与资源

执行 `scripts/package-release.ps1 -Commit a3163dcc216e049b9ca873458807e925d6908df2 -Version 0.1.0-rc.2`，退出 0。构建目录为 `.local/releases/0.1.0-rc.2-a3163dcc/`；独立本地 clone 固定提交，恢复并逐一核验 202 个 LFS 路径／166 个不同内容对象。未借原工程 `.godot`、`.local`、忽略的美术源或制作留档；fresh Import 和 Export 均成功，构建后源副本 Git clean。没有配置远端，不宣称远程克隆或异机备份。

Godot 标准版及 Windows 模板为固定 4.7.2，具体工具哈希见随包 `version.json`。PCK 格式 4，248 条资源，禁止资源 0／缺失 0。额外核实六个新增资源已入包：`camera_foreground.gdc`、`plant_wind.gdc`、`plant_wind.gdshader`、`living_details.gdc`、`house_warmth.gdshader`、`soil.gdshader`；GDScript 同时有 remap。水／远景 shader 亦在包内。发行包没有开发执行入口、测试、Blend 源和录制依赖。

## 可交付文件

- ZIP：`制作留档/06_发行候选/0.1.0-rc.2-a3163dcc/我有一片田 0.1.0-rc.2 Windows.zip`，192,691,293 字节。相邻 `.zip.sha256`、`version.json`、`SHA256SUMS.txt` 及 `构建与原生验收证据/` 已保存；复制后 ZIP 哈希与原包相同，rc.1 原目录保留。
- 仓库外已解压入口：`D:/发行验证/我有一片田 候选/0.1.0-rc.2-a3163dcc/我有一片田 0.1.0-rc.2 Windows/Farm.exe`。
- 附带中文使用说明、版本说明、来源通知及 Godot／Noto 字体通知。Windows 文件版本 `0.1.0.2`，签名状态 `NotSigned`。未擅定项目开源许可证。

| 产物 | SHA256 |
| --- | --- |
| ZIP | `cce4f8face420cff1e252e3c04ec1312a2a0e8a62568439176c60253578598d8` |
| Farm.exe | `78f81336f154a2be2a3b7e00f4e801fd3898e31a9cebd59a111b5fbbc3c86f05` |
| Farm.pck | `fc9fb23f85f877cf62cb12a58ab69deb096a9a1e8bc98572ff39cb73eddd283d` |
| version.json | `e5893be8d30cdccf453ed05e4129fdfbdc5c44ff4a4cb439341cc099b0568948` |

## 普通发行程序验收

证据：`.local/verification/rc2-a3163dcc/`，已镜像至上述交付证据目录。使用 `start-isolated-game.ps1` 将 APPDATA／LOCALAPPDATA 指向独立 profile；没有触碰真实玩家档。实际权限令牌非管理员。原生操作逐次校验确切 EXE 路径、PID、启动时间，通过鼠标执行，不在发行程序中注入测试脚本。

1. PID 43272 首次新档启动，真实选第 03 田成熟青菜，收获 1 篮，再播种青菜、浇水，正常关闭。
2. PID 43984 同一隔离 profile 重开，真实选择第 03 田，确认累计仍为 1 篮、青菜幼芽且已浇水，六田和装饰状态未重置，再正常关闭。
3. 两进程均退出 0，stderr 去空白后为空。首次关闭到重开关闭，田 03 生长增量 `75.738999843597` 秒，等于 UTC 结算差，未修改时钟或存档制造结果。
4. 亲看 `04-overview.png`、`05-mature-focus.png`、`07-sown-watered.png`、`09-reopened-field.png`：新包暖光／冷影、前景虚化、门廊生活组和水面资源可见，操作反馈可读；未发现新的构建缺图或交互阻断。动态风、船摆、日夜和完整性能以本轮整合交接的专项证据为准，不把静帧或本次短冒烟当性能测试。

首次可交互时间**未测准**：自动探针 `first-startup.json` 写出约 7.75 秒及通过，但 `01-first-farm.png`／`02-first-settings-response.png` 实际仍为 Godot 启动 Logo，故该计时判定无效，不能声称 10 秒内可操作。之后 `03-current.png` 已确认设置面板真实响应；中间未连续采样，不推测精确首次首屏时间。原始证据保留，最终 `verification-summary.json` 明确覆盖其错误判定。`after-harvest.json` 在自动保存防抖结束前复制，仍是旧状态；农事成功以真实截图和退出完成的 `first.saved.json`／`reopened.saved.json` 为准。

验证机器仍安装开发工具，只证明此外部包可直接普通启动、操作、保存并重开，未启动编辑器或源构建流程；不能称在另一台未安装开发软件的电脑上验收，也未进行网络抓包。独立构建依赖与实际版本由清单记录，不宣称 ZIP 可逐字节重复构建。

## 交接与运行状态

所有本代理验证窗口已关闭，GPU 已交 2_1 录制。017 的录制信息已固定同一提交且 `working_tree_dirty=false` 后才写此文档，生产代码保持冻结。最终交用户启动用上述外部 EXE；本代理没有自行重新启动玩家窗口、修改旧包、提交或推送。

跟踪文件变更仅本文件及 `院落生活与船-handoff.md` 后续状态链接。根代理统一维护 README／项目上下文／整体验证交接。
