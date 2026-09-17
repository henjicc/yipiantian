# 主岛与桥头圆润岸坡 · 20260918

旧主岛来自`build_modules.py`的Blender参数化网格：16个轮廓控制点，沿直边加随机点，水平顶面加近乎垂直的土壁。细分没有改变折线本身，所以石缝处仍像切开的板子。旧脚本及`island_bank.glb`保留为历史源。

现役入口`build_smooth_banks.py`，Blender5.2.2：Catmull–Rom闭合轮廓，每段16采样，九层从平地到水下的缓坡、闭合底部、平滑法线。主岛保持0.13米耕作平地，向外圆润过渡，不改变六田和房屋的位置。主岛4608三角，右岸2592三角；均单材质、拓扑闭合、重导入面数一致，禁用额外自动简化。源和审计见`20260918/rounded-banks.blend`及`audit.json`。

正式GLB为`Game/art/environment/modules/island_bank_v2.glb`与`east_bank_v2.glb`。右岸独立轮廓、原点(12.65,-0.02,-2.8)，覆盖实际桥头出口(约10.37,0.21)，不再缩小主岛来碰运气拼接；桥后补七块石板连接岸上，桥模型不变。扩大岸后把右侧荷花湾移到(14,-0.40,3.4)，避免埋入土地。

运行时用实际网格切水线生成接触距离场。着色保留几何法线，只叠加细小草地法线，修复统一换成朝上法线导致圆坡仍像平面的原因；高度和色斑控制草土过渡，水线变湿变暗。

重建：`blender --background --python-exit-code 1 --python ArtSource/Environment/build_smooth_banks.py`。定向测试、前后证据和补拍节点统一见[邻居岛](../Islets/README.md#验证与视频节点)。
