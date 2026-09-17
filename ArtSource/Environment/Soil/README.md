# 松土、选中与种植反馈

2026-09-17，Godot 4.7.2 / Forward+。本轮替换六田的平整拼片观感与悬空绿框；不改变六田 96 格、作物时间或存档。当前效果供用户观察，尚未主观签收。

## 制作来源

- 内置 image_gen 两次：一张 [土畦与根部参考图](20260917/reference.png)，一张直接接入的 [土壤颜色纹理](../../../Game/art/environment/soil/loam.png)。原始输出分别为 `exec-e59b0927-8653-4eb3-b24c-b7b42e46a9cd.png`、`exec-87d648f7-6d3a-40c0-8caf-52354c63811e.png`；未用脚本编辑生成图。完整提示词：[参考图](20260917/prompt.txt)、[纹理](20260917/texture-prompt.txt)。工具未返回底层模型版本、种子和单次价格，不猜测补填。
- 参考图只指导松土形态、低矮培土和色彩，不是游戏截图。正式纹理开启 mipmaps，世界坐标采样；纹理亮度仅作低强度微凹凸的美术近似，并非经过测量的高度图。
- 本轮没有调用 Tripo、没有新 GLB、没有 Blender 减面。作物与压边石继续复用原资产。土面要求连续拼接、逐格变形与稳定命中，因此由 Godot 生成精确网格比生成整块不可控模型更直接。

## 调研结论与选择

用户提出“整片土是否可以是粒子”，需要区分**表面颗粒感、短时飞散粒子、具有相互作用的颗粒物理**。有粒子发射器并不等于有完整的土粒堆积与碰撞模拟。

| 方法 | 可以解决 | 本项目取舍 |
|---|---|---|
| 颜色 / 法线 / 凹凸 / 贴花 | 细颗粒、干湿色差、接触暗部 | 使用纹理与微凹凸；单独使用不能改变低角度轮廓，不能代替培土 |
| 高度场 / 网格位移 | 土垄、坑和根部土包，接受场景光照 | 本轮核心：连续高度函数生成基础网格，种植参数驱动局部顶点位移 |
| 合并几何 / MultiMesh 实例化 | 可见碎土块的体积和轮廓，减少独立节点与提交开销 | 每格 32 颗小土块并入同一网格；不逐颗建节点。暂不增加另一套 MultiMesh，现有格网格已能合并这些静态碎土 |
| 短时粒子 | 播种瞬间弹起和散落的土屑 | 成功空格→有作物时发射 12 颗、寿命 0.42 秒、结束释放，无常驻发射和粒子碰撞 |
| 土粒物理 / 可任意挖掘体素 | 铲土、堆积、滑坡、洞穴、材料搬运 | 当前没有这类玩法，不引入求解器；不能把本轮视觉土包宣称为质量守恒或真实土壤模拟 |

一手资料（2026-09-17 查阅）：

1. [GIANTS：Farming Simulator 25 地面形变技术访谈](https://www.farming-simulator.com/newsArticle.php?country=us&lang=en&news_id=569)：采用密度数据、程序几何和近远地形网格，远处通过法线细节延续形变观感。该游戏的车辆物理与稀疏地图系统服务其大世界，不是本项目必须照搬的架构。
2. [GDC 2014：Deformable Snow Rendering in Batman: Arkham Origins](https://media.gdcvault.com/GDC2014/Presentations/Barre-Brisebois_Colin_Deformable_Snow_Rendering.pdf)：用运行时高度图、位移 / relief mapping、细节法线分层表达变形。可借鉴“形变数据与细节材质分离”，不是土壤模拟的直接实证。
3. [Godot：首个 3D shader](https://docs.godotengine.org/en/stable/tutorials/shaders/your_first_shader/your_first_3d_shader.html)：网格位移需要对应的法线处理。这里基础网格与法线都按同一高度函数取样，局部培土在 shader 中同时改位置与法线。
4. [Godot：MultiMesh 优化](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)：适合大量重复对象，但有整体可见性边界；实例化减少提交开销，并不消除几何和像素着色成本。
5. [Godot：粒子属性](https://docs.godotengine.org/en/stable/tutorials/3d/particles/properties.html)、[GPUParticles3D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html)：one-shot、amount、lifetime 服务短促发射；本轮不启用碰撞，结束后销毁发射器。
6. [Godot：GeometryInstance3D](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html)：逐实例 shader 参数允许共享材质时分别控制选中和培土，避免选一格时整田一起改变。

上述资料支持技术原理，以下参数与视觉取舍为本项目实现，不是外部资料承诺的性能或效果。

## 实现与复用

- `Game/presentation/tilled_soil.gd`：每格 20×16 四边形细分后转三角，整田共用连续的浅垄和扰动函数；接边高度和法线相同，逻辑格之间没有凹下去的棋盘缝。每格少量静态土块合并绘制，16 份不同格位置的网格由六田复用。
- `Game/scenes/environment/soil.gdshader`：颜色纹理、微凹凸、干湿柔边、根部局部变形和选中四角。基底高度由 CPU 一次生成，不每帧重建网格；选中通过不透明土面着色表达，没有额外漂浮框体和透明叠层。
- `Game/scenes/farm_layout.gd`：权威状态仍从 FarmState 派生。初次加载直接恢复培土，不播放播种效果；成功播种动画隆起，收获动画回落，浇水和阶段刷新不重复播种粒子。幼芽 / 幼株 / 成熟培土比例为 .38 / .68 / 1，作物锚点跟随实际基础土面并略微埋入。
- `Game/presentation/planting_soil_burst.gd`：短时土屑。没有粒子间碰撞、土体质量守恒、坑洞持久化或真实土壤松软度玩法；需要这些能力时重新评估范围，而不是在本效果上假称已支持。
- 世界点击继续使用稳定田块碰撞和格坐标。表面只有厘米级起伏，网格碎土不添加碰撞体，避免选格身份随颗粒或作物模型变化。
- 检查纹理凹凸时必须同时开 mipmaps 和匹配过滤；本轮初版未开 mipmaps 造成近远颗粒噪点，修正后再留档。不能用未经滤波的密集高频纹理冒充精细度。

## 验证与视频节点

- `tests/farm_grid_layout_test.gd`：109 项通过，涵盖 96 格身份、接岸高度、相邻网格接缝、浇水 / 生长独立性及新土面选择。
- `tests/soil_presentation_test.gd`：原生 Vulkan，隔离状态，检查培土中间值与结束状态、邻格不变、粒子释放、六种作物阶段、输入射线及收获回落；保存空田 / 选中 / 播种 / 正反根部 / 低角度特写 / 夜间 / 收获画面。短动画中间值采用真实 Tween 的确定步进，避免后台 15fps 或初次资源上传让短时间采样失准；不是帧率测量。
- 定向命令：`scripts/godot.ps1 -Action Run -ExtraArgs @('--script',(Join-Path $PWD 'tests/soil_presentation_test.gd'),'--','--output=<REPO_ROOT>/.local/verification/soil-presentation-final')`。
- 实机证据在 `.local/verification/soil-presentation-final/`；采用的截图与用户原始两张反馈图归档在 `制作留档/03_处理与验证/20260917_松土与种植反馈/`。修改前基线 `0c89425`，可结合本次参考图、纹理、网格 / shader 源重现过程。没有把初版泥面或无 mipmaps 的试图当作终稿。
- 新视频未录；登记至既有中文剪辑索引，后续可补拍“旧平板粗框→图片参考→土面与培土→播种土屑 / 收获回落”，图像生成贡献和 Godot 实现分别标明，不归因给 Tripo。
- 场景测试仍有既存的退出资源警告，未扩大到无关清理。没有运行全存档回归、独立发布或长时性能测试；不把固定小数量粒子或截图当作整机性能达标证据。
