# 参数化基础构件研究

2026-09-24 开始。本阶段范围是栏杆与竹架、一种阔叶树、一套单层双坡江南民居，以及独立交互演示。此目录保存可编辑部件与生成来源；没有替换主岛或背景岛。

## 当前状态

栏杆和竹架已有可运行的第一组标准构件与参数组合。树木的 Tripo 枝叶簇已生成并下载，实际120积分，尚未整理或接入；民居尚未开始。整阶段没有验收完成。当前竹材偏旧木色，主岛实景对照及最终组合质感仍需继续检查。

- 场景：`Game/scenes/procedural_lab/component_lab.tscn`。共用岛屿研究室的日光、主题和相机操作；不加载农场或读写存档。
- 参数规则：`railing_kit.gd`。木栏杆长度 2.4–8 米、栏高 0.7–1.4 米、最大开间 0.8–1.8 米，直线／转角／折线，地面坡度 ±0.18。竹架长度相同，高 1.6–2.8 米、宽 1–3 米。长度改变重新分配柱数与横杆；角点共用立柱。竹架设倾斜支脚、纵向撑杆和顶部格栅。
- 种子影响木柱纹理朝向与竹节分布；结构轮廓由尺寸和路径参数控制。相同版本、种子与参数复现。对比模式展示三条路径或三种长宽组合，复制时包含当前参数及三个对比组合。
- `kit_parts.gd` 缓存导入网格；每组物件、每种构件使用 MultiMesh。26 米附近淡化竹节与绑绳、切换低档竹杆及木柱；没有按零 LOD 偏置强制全场减面。高低档关闭额外自动 LOD。

## 源与工具贡献

木柱复用 [ProceduralBridge](../ProceduralBridge/README.md) 的 Tripo 任务 `18e92ae5-d11c-4987-81d4-babb51731181`；横杆复用该目录的 Blender 倒角木料。未重新生成木柱。竹杆、竹节、绑绳由本目录 `prepare.py` 在 Blender 5.2.2 LTS 按真实米制尺寸构建；不能称为新的 Tripo 产物。

`bamboo_modules.blend` 保留可编辑网格、UV 与打包贴图。杆件局部长度一米，导出长轴为 Godot Z，绕原点定位；木柱底部为原点。`audit.json` 保存实际三角形、尺寸及干净重导入结果。竹杆高／低 192／44 三角形，竹节156、绑绳1060，木柱低档553；原木柱高档1847。

新杆件的颜色贴图复用既有 `painted_elm.png`。正式 GLB 直接引用 `Game/art/environment/procedural_bridge/beam_PaintedElm.png`，木柱低档引用原木柱图片；同内容不另存新运行贴图。打包源中的纹理保留，原始 Tripo 模型未修改。

重建（仓库根目录）：

```powershell
blender --background --python-exit-code 1 --python ArtSource/Environment/ParametricKit/prepare.py
& scripts/godot.ps1 -Action Import
```

会覆盖本目录的 `bamboo_modules.blend`、`audit.json` 与五个对应 GLB；不覆盖原木桥源或参考图。脚本先重导入核对 UV、有限坐标、贴图与三角数，再通过项目现有 GLB 打包函数链接已有相同贴图。

## 验证与复现

```powershell
& scripts/godot.ps1 -Action Run -ExtraArgs '--script','../tests/component_lab_scene_test.gd'
& scripts/godot.ps1 -Action Run -ExtraArgs 'res://scenes/procedural_lab/component_lab.tscn'
```

专项检查默认／上下限、确定性、实际导入木柱接地、角点共柱、按钮应用、参数复制、空种子保留原场景。截图覆盖全景、正反接头、三种结构、坡地、远景返回近景和小窗口。截图与测量原件在 `.local/verification/component-lab/`，阶段归档在 `制作留档/03_处理与验证/20260924_参数化基础构件/`。

测量按 1600×1000、D3D12 Forward+、RTX4090、每项120帧记录。CPU render 是渲染提交加帧准备，process 是引擎监视器值；工作集由 Windows 查询，video 是引擎上报的纹理／缓冲分配量，不冒充整进程专用显存驻留。完整场景含湖面、主岛日光与界面，数字不是单一栏杆成本，也不证明相比旧背景岛省资源。三类系统齐备后仍须最终代表场景测量。

本节点可从源重现，尚未制作视频。参考图与枝叶簇任务 `67c5df09-8c45-404e-9689-5125cd47da95` 见 `generation-record.json` 与 `raw/`；使用 P2-20260801、v3.5-20260815 detailed、5000面请求，参考图通过后再图生模型。首次下载中断后只重新下载同一成功任务，没有重复生成或重复付费。原件尚需背面、接枝轴向、厚度及风动检查。用户尚未进行本批主观验收。
