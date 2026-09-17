# 江南九月院落：植物、生活摆件与水禽

视频节点：`20260918-courtyard-life`。修改前代码基线 `fc3a27e`；本轮已入景并完成定向检查，用户主观效果待确认。按用户标注制作，保留主要房屋、田地、桥和邻居岛的世界尺度。

## 原件、版本与费用

所有原件在 [20260918](20260918/)。14张图片工具参考分别生成并检查，再提交14次Tripo图生模型，不从文本直接跳过参考。提示词、原始图片工具路径和采用的两张风格图见 [image-records.json](20260918/image-records.json)；图片工具没有返回具体模型版本或种子，不猜写。`<id>-reference.png` 是实际采用图。

[generation-record.json](20260918/generation-record.json) 汇总全部任务ID、服务回显参数、状态和费用；每个 `<id>-original/` 保留未修改GLB、服务预览及脱敏任务记录。图片、原模和服务分件不覆盖。

- 14次 H3.1 Ultra，每次60积分，共840。CLI别名 `tripo-v3.1`，服务实际版本 `v3.1-20260211`；detailed geometry/texture，纹理 `v3.5-20260815`，delight=true、smart_low_poly=false、pbr=false、enable_image_autofix=false，明确面数预算和91831–91844种子。
- 桂花语义分件 `v2.0-20260430`，balanced、split_by_connectivity=true，48区，40积分。结果在 `osmanthus-parts/`。
- 鸭／鹅／鸡先免费rig-check，确认支持avian后绑定：`v2.5-20260210`、rig_type=avian、spec=tripo、GLB；每次25，共75积分。原件在 `*-rig/`，检查结果为 `*-rig-check.json`。曾提交不存在的 `v2.5-20260427` 被服务400拒绝、未扣费，随后按服务支持版本纠正；不要猜测后处理版本。
- 总计 **955积分**，余额变化已核验，冻结状态未公开。图片工具没有提供独立费用账单，不把这部分算入Tripo余额。

## 实际采用与位置

| id | 用途与落点 | 高档三角数 | 人工低档预算 |
|---|---|---:|---:|
| kitchen | 主屋左侧独立厨房／储物厢房，(-4.5,.115,-5) | 65407 | 26000 |
| osmanthus | 左前桂花(-6.05,.09,4.3)及屋后桂花 | 76320 | 35000 |
| willow | 屋后及桥对岸柳树 | 75888 | 35000 |
| bamboo | 屋侧、屋后、沿岸竹丛 | 58264 | 22000 |
| chrysanthemum | 主岛岸边小菊丛 | 44732 | 11000 |
| lantern | 门廊两盏素纸木框灯笼 | 29116 | 9000 |
| pepper | 西侧地面晒盘内红辣椒 | 19196 | 7000 |
| slices | 晒架和桌面盘内食材薄片 | 18796 | 6500 |
| pomelo | 前岸草垫上柚子 | 19708 | 6500 |
| radish_bundle | 前栏晾晒绳上的萝卜束 | 23857 | 8500 |
| seedling | 两个育苗框内的小苗，根部入土 | 9000 | 3500 |
| duck | 三只家鸭，主岛左侧水面(-9.15,.90)附近 | 28928 | 9000 |
| goose | 两只家鹅，前方水面(2.9,8.85)附近 | 29954 | 10000 |
| hen | 两只母鸡，前岸小路(-.70,4.58)、(.05,4.58) | 28962 | 7000 |

水禽坐标为XZ。高档是实际导出值，低档是预算，实际值见各 `*-audit.json`，不能把源三角数当成运行绘制数。灯笼是朴素传统家用造型的美术表达，不宣称考古级明代器物复原。

## 整理、动画与重建

编辑源为各 `<id>.blend`，脚本 [prepare.py](prepare.py)，Blender 5.2.2 LTS。重建示例：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python ArtSource/Environment/CourtyardLife/prepare.py -- duck goose hen bamboo osmanthus willow chrysanthemum lantern kitchen pepper slices pomelo radish_bundle seedling
```

导出到 `Game/art/environment/courtyard_life/`。原始高模和UV、4K颜色贴图保留，唯重复且很小的幼苗整理为9000三角；人工低档减面前处理几何接缝，导出后重导入核对三角、UV、纹理与尺度。这批资源明确关闭Godot额外自动LOD，沿用项目人工高低档切换；不全局关闭LOD。厨房原模有6条边界、萝卜束2条，整理前后不增加；其余为0，所有资产零面积面为0。保留这些继承边界，不盲目补洞或覆盖原件。

桂花48个区域辅助原纹理网格的顶点分组，连续顶点权重负责根部固定、枝干摆动和叶片抖动。分件文件保留用于后续着色／爆炸展示，运行时不把切开的枝条硬拼成关节。其余植物也有根部固定的连续风动权重。云端分件不等于自动动画。

禽类使用Tripo真实骨架与权重，Blender源中保留首版4秒 `Paddle`／`Forage` 循环；鸭绑定输出的辅助 `Icosphere` 排除在游戏资产之外。导出头部顶点核验鸭与鸡朝+Z、鹅朝-Z。当前运行已由下节的行为与骨骼控制替代固定循环；原件和历史动作仍保留。三维生成、语义分件及骨架由Tripo完成，本地动作与水面运动由Blender/Godot完成，不能混称Tripo自动生成了整套动画。

### 动物行为节点：20260918-animal-roaming

改造前独立包为 `.local/snapshots/20260918-4abc256/`，本轮复用同一批模型与骨架，无新增生成费用。新增运行入口是 `Game/scenes/environment/courtyard_animals.gd`、`animal_space.gd` 和 `bird_pose.gd`。7只动物固定数量，未增加饲养经济或离线惩罚。

- 活动区、休息点、物种速度／转向／停留参数集中在动物控制器；实际岛岸、岸石、邻居岛、荷叶、船、建筑和摆件投影派生禁入区，田地禁入区取真实田块变换。16厘米导航网格只在建场时生成；每米障碍索引减少逐步查询。后续布局改造必须调用重建并更新地面采样，不能沿用旧空间。
- A*路径做可见直线压缩，移动保留加减速、到达减速、同伴分离、硬间距和受阻重选目标。不可在离拐点较远时无条件跳下一段，否则平滑惯性会把动物推到障碍边反复卡住。鸭鹅能在左侧与前方水域跨区游动，间歇选择同伴附近目标并短时跟随；鸡沿田间小路与屋侧走动。
- 使用现有骨架的髋／膝／踝链做双段求解，步相由实际路程推进，两脚错半周期；支撑段向后移动匹配身体位移，摆腿段抬脚，地面高度来自实际低矮石板三角形。停步淡出，水禽划脚与尾波强度随速度变化。没有改写Tripo骨架原件或重减面。
- 啄食／探水与理羽使用有限转角的颈部链求解，目标来自实际地面／水位／肩羽；鸡导航余量21厘米覆盖身体与转身。导入禽类保留骨架父级归一化变换，**不能直接用 `mesh.to_global(vertex)` 测量嘴尖**：必须先按Skin逆绑定矩阵、权重和骨骼姿态计算实际蒙皮点，再换到世界坐标。否则数值接触通过而画面仍悬空。此问题已用实际近景反证并修正，原始骨架和网格不改写。
- 定向检查入口 `tests/animal_behavior_test.gd`：真实主场景、隔离存档，模拟360秒，检查7只活动边界、相互间距、单步位移、活动跨度、状态出现和反复卡住；`-- --visual`附近景连续相位截图，`-- --poses-only --visual`只检查啄食／探水／理羽与昼夜近景。当前宽身体余量检查中鸭鹅累计54–78米、两鸡58/50米，路径恢复0–10次，鸡最大跨度约10.3×7米。模拟每步约0.48ms，含检查开销，不是整机帧耗时或GPU结论。
- 证据 `.local/animal-behavior/{check,visual,contact-visual,contact-lifecycle}.log` 和 `.local/verification/animal-behavior/`。步行近景已观察到两脚交替；啄食最低嘴尖约0.149米（当地地面约0.13米），鸭鹅最低约-0.257米（水面-0.25米）。白天和夜晚三种禽类近景已检查。源码 `a6cd9ff` 动物阶段独立包已留存于 `.local/snapshots/20260918-a6cd9ff/我有一片田_动物行为版_20260918/`：672资源审计无禁入／缺失，第二屏实际运行、正常关闭exit=0与隔离保存通过，标准输出／错误输出没有资源残留。独立证据在 `.local/verification/animal-release/`，这是本机缓存导出，不是干净克隆发布认证。第02–07项已完成，后续布局与玩法未完成。图形测试退出曾偶发12实例／6资源残留，最新verbose图形退出与headless退出均无残留；不把一次无警告当成引擎清理问题已根治，独立程序退出继续检查。
- 无新增录像。参考图、原模、骨架仍在上述20260918源目录，当前行为和动作可按源码重现，需要视频时补拍；连续截图是验证资料，不冒充实时录屏。

方案参考：[Reynolds行动选择、转向和运动分层](https://www.red3d.com/cwr/steer/gdc99/)、[Godot 4.7 AStarGrid2D](https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html)、[Skeleton3D局部姿态接口](https://docs.godotengine.org/en/4.7/classes/class_skeleton3d.html)。本项目直接使用内置寻路与现有骨架，没有引入第三方AI框架。

落花是本地制作的14个共享小网格，GPU按渲染时间连续计算轨迹，出生点采样真实桂花树冠，落地和回收平滑缩隐；没有每帧CPU逐片上传或逐片物理模拟。另修复第二屏可见开发预览失焦降至15fps的问题：现在最高60fps并尊重更低用户上限，最小化仍15fps，静音策略不变。这是帧率上限策略，不是长期实测性能保证。

## 接触、光照与环绕雾

移除与门廊摆件重叠的旧长凳，调整晒架。磨盘移至桥左侧岸地(5.07,.14,-2.92)，相邻栅栏外移避免相交。六田各自用固定种子组合已有五类石头，保持可复现但不复用同一压边形状。灯笼可见发光配合两盏局部灯和两盏弱农田补光，昼夜统一控制，没有昂贵的实时散射模拟。

参考用户《Godot_模型融合与边缘柔化操作指南》后，采用实际接触点投影暗池、植物根部压入和根部颜色过渡处理交界。新厢房与树根进入接触烘焙来源；不对所有不透明模型开启透明近邻淡出，避免深度排序与景深副作用。倒角、法线平滑、抗锯齿和接触融合分别处理。

默认景深170%、雾28%。`courtyard_haze.gdshaderinc`以主岛XZ清晰椭圆为基准，外围左右及后方逐渐增雾，主田始终保持清晰；共享函数作用于远岛、植被、水和绘景水面，镜头放大不重新起雾。相机近处框景显式豁免。雾色上传需由sRGB转线性，否则夜晚被错误抬亮。保留水面的 `depth_draw_always`，避免MSAA+景深下叶片边缘出现虚线黑边。

契约参考：[Godot空间着色器FOG和深度写入](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)、[全局shader uniform](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html#global-uniforms)。统一世界雾是本项目美术方案，不是引擎物理雾保证。

## 定向验证与视频素材

- `tests/courtyard_life_test.gd`：实际新资源、绑定动作播放、左右岛0/100%雾像素对照、聚焦过程景深不清零、昼夜和前后接触机位、水禽连续运动取样。截图 `.local/verification/courtyard-life/`，日志 `.local/courtyard-life/scene-delivery.log`。
- `tests/camera_tuning_test.gd -- --fog-regression`：远岛雾、六田作物清晰带和聚焦／返回连续性；4K边缘图 `.local/verification/dof-tuning/dof-edge-fixed-4k.png`，日志 `.local/courtyard-life/dof-final.log`。
- `tests/window_preview_activity_test.gd -- --dev-preview`：可见失焦60、最小化15及用户30帧上限，日志 `window-activity.log`；`tests/living_details_test.gd`验证局部灯控制、材质与布局，日志 `living-final.log`。
- 导出重导入审计28份资源通过，昼夜、背面、桥侧及游动截图已检查。不重复跑存档或全资产测试，尚未做长期性能认证。

后续视频从本页查素材：参考图已有；原始模型／转角可从保存GLB重现；48区语义拆件有原件但展示片待补拍；禽类骨架和本地动画可从blend重现；最终游戏截图已有，连续演示片待补拍。旧版用基线 `fc3a27e`，对比必须固定镜头、光照、尺度，标注“按保存源文件重现”，不要冒充生成过程的实时录屏。本轮未录成片，原件由Git LFS本地管理；仓库无远端，不声称已异地备份。
