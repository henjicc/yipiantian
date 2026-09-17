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

禽类使用Tripo真实骨架与权重，本地在Blender制作4秒 `Paddle`／`Forage` 循环，含头部与脚部小动作；鸭绑定输出的辅助 `Icosphere` 排除在游戏资产之外。导出头部顶点核验鸭朝+Z、鹅朝-Z，分别补偿朝向，尾波始终跟随行进方向而非模型的假定正向。Godot给水禽安排小范围平滑路线、浮动和淡尾波；母鸡在前岸原位啄食，不引入饲养玩法。三维生成、语义分件及骨架由Tripo完成，本地动作与水面运动由Blender/Godot完成，不能混称Tripo自动生成了整套动画。

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
