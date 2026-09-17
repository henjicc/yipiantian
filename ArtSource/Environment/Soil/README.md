# 松土、选中与种植反馈

2026-09-17，Godot 4.7.2 / Forward+。实现版 `e4fd421` 替换六田的平整拼片观感与悬空绿框；不改变六田 96 格、作物时间或存档。用户确认明显改善，但指出纹理重复、颗粒仍平、根部接触生硬；整体尚未签收。下文“近景二次调研”为待实施方案，不代表这些问题已经修复。

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

## 近景二次调研：去重复、颗粒体积与根部融合

2026-09-17，针对用户近景反馈查阅论文、引擎文档与 GPU Gems。检索方向包括 stochastic texture tiling / hex tiling / texture bombing、parallax occlusion mapping silhouette、mesh terrain material blending / world height、MultiMesh culling。以下分清代码事实、资料原理与本项目建议；本次只调研和留档，未修改运行时实现，未取得新性能数据。

### 已确认的局限

- `soil.gdshader` 以 `world_xz * .65` 重复采样同一颜色图，约每 1.54 个世界单位重复。低频颜色噪声没有改变石粒、裂隙的布局，因此不能消除可识别图案。
- 微凹凸来自颜色图亮度，并非同源测得的高度。颜色深浅可能表示色素或原图阴影；加深这种凹凸不能可靠还原颗粒。现有材质也没有独立、同源的细节法线与粗糙度图。
- 每格 .60×.44、20×16 细分，基底顶点间距约 3×2.75 厘米，无法表达毫米颗粒。每格 32 颗压扁球形碎土覆盖稀疏，且 16 份格网格在六田复用；纹理和几何均存在重复来源。
- 培土是通用椭圆隆起，埋深没有按每种作物各阶段的根颈外形匹配；只处理土面，未处理植物根颈的沾土过渡。再加圆形黑影也不能解决根部轮廓过于整齐的问题。

### 成熟方法及本项目采用建议

| 层次 | 原理与来源 | 下一版小样建议 / 限制 |
|---|---|---|
| 去重复 | [Practical Real-Time Hex-Tiling，Mikkelsen 2022](https://jcgt.org/published/0011/03/05/paper-lowres.pdf)：随机取样偏移、旋转和保对比混合；[Deliot / Heitz 的随机纹理方法](https://eheitzresearch.wordpress.com/738-2/)讨论保留统计特征及 mip 过滤 | 采用连续世界坐标的随机拼贴，各田固定不同种子，再叠大范围土色 / 干湿变化。颜色、高度、法线、粗糙度必须使用对应的坐标变换；法线方向随旋转修正。避免普通线性混合把颗粒糊掉，并检查边界导数与 mip 闪烁。不要每帧重新随机或每逻辑格独立产生接缝。 |
| 细颗粒材质 | [Godot StandardMaterial3D](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html)：法线改变光照而非几何；height 深度效果也不实际修改网格 | 图片生成继续提供美术参考。正式颗粒由同一份高度 / 几何源制作配套颜色、法线、高度、粗糙度及微遮蔽，避免几张独立生成图片对不上。颜色不带固定方向光影；粗糙度独立创作。Godot 法线采用 OpenGL Y+ 约定。 |
| 可见土块体积 | [Godot MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)：重复几何批量绘制，但以整体包围盒处理可见性 | 制作数种有棱角、裂面与大小差异的土块；按疏密簇分布、随机埋深，根颈和田边增加真正影响轮廓的块。按田或小区域合批，不逐粒节点 / 碰撞，也不把六田合成一个无法局部剔除的大批次。细小到不足像素的颗粒交给材质。 |
| 视差遮蔽 POM | [NVIDIA GPU Gems 3 §4.2](https://developer.nvidia.com/gpugems/gpugems3/part-i-geometry/chapter-4-next-generation-speedtree-rendering)：高度追踪产生视差及自遮挡，普通 POM 不改变轮廓；支持轮廓需额外方法 | 可作为近景对照选项，不能代替真实根部遮挡和土块外轮廓。其逐像素多次采样开销需在 4K / 低角度实测；不能认定一定比少量几何省。不要无评估地叠加随机多路采样、三平面和多步 POM。 |
| 接触处材质融合 | [Unreal RVT 官方文档](https://dev.epicgames.com/documentation/en-us/unreal-engine/runtime-virtual-texturing-in-unreal-engine)：共享颜色、法线与世界高度等地表属性 | 借鉴地面 / 物体共享高度与材质信息的思路，Godot 内先用局部高度及根颈遮罩；不是移植 Unreal RVT。RVT 本身不生成接触几何，也不适合把频繁动画对象当作静态缓存写入者。 |

根部建议按“作物种类 × 阶段”制作可控接触范围：基础埋深 → 不规则局部压陷与侧向培土 → 几颗真正遮住根颈下缘的土块 → 根颈少量不规则沾土和对应粗糙度 → 小范围接触阴影。避免每株一圈相同的圆土环、均匀黑晕或简单半透明淡出。作物现有风动 shader 使用共享材质，需根部专用遮罩 / 实例参数，不能改共享颜色误染整株或所有作物；根部过渡也不能随叶片风动漂移。此处是本项目设计推导，不是上述引擎文档已经提供的作物功能。

### 实施顺序与验收边界

1. 先做一块田的小样：同源配套材质 + 随机拼贴；检查正午 / 傍晚、全景 / 近景是否还能辨出重复。
2. 加入大小混合的真实土块，重点检查低角度轮廓和旋转视角的视差；不能仅凭俯视静帧判定体积真实。尽量离线或加载时确定分布，种植变化只更新受影响局部。
3. 在同一块田对照两类作物各生长阶段的根部融合，确认没有悬浮、规整泥环、露底或泥土染叶。需要接触的埋入是有意遮蔽，桌柱等不合理结构穿插仍须避免。
4. 必要时单独比较“材质 + 局部几何”和“增加近景 POM”；采用同一机位、分辨率、光照，记录 GPU 帧时间、提交数和显存，再看满六田成本。失焦 15fps 样本不算前台性能证据；不抢主屏焦点。
5. LOD 依据实际屏幕尺寸保留可辨轮廓，远处材质延续颗粒明暗；检查拉近 / 拉远连续过程中的跳变、破面和闪烁，不能重演全局强制最低档。新材质尚无帧时间实测，不承诺帧率。

参考图 → 同源材质 / 土块源 → 游戏多机位小样 → 相同条件性能比较 → 扩展六田，是下一轮建议流程。静态颗粒不用物理求解；播种时仍只用短时飞散粒子。仅当未来玩法真的包含铲土、搬运、堆积时再评估颗粒物理或体素方案。

本次反馈截图保存在 `制作留档/03_处理与验证/20260917_松土与种植反馈/用户反馈_纹理重复与根部生硬.png`；可与 `e4fd421` 及此前 `0c89425` 做后续视频对照。没有新录屏，不将本节建议当成已实现片段。

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
