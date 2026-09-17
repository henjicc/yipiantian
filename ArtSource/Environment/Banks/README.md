# 主岛与桥头圆润岸坡 · 20260918

旧主岛来自`build_modules.py`的Blender参数化网格：16个轮廓控制点，沿直边加随机点，水平顶面加近乎垂直的土壁。细分没有改变折线本身，所以石缝处仍像切开的板子。旧脚本及`island_bank.glb`保留为历史源。

留存模型入口`build_smooth_banks.py`，Blender5.2.2：Catmull–Rom闭合轮廓，每段16采样，九层从平地到水下的缓坡、闭合底部、平滑法线。主岛保持0.13米耕作平地，向外圆润过渡，不改变六田和房屋的位置。留存主岛4608三角，右岸2592三角；均单材质、拓扑闭合、重导入面数一致，禁用额外自动简化。源和审计见`20260918/rounded-banks.blend`及`audit.json`。

留存GLB为`Game/art/environment/modules/island_bank_v2.glb`与`east_bank_v2.glb`。右岸独立轮廓、原点(12.65,-0.02,-2.8)，覆盖实际桥头出口(约10.37,0.21)，不再缩小主岛来碰运气拼接；桥后补七块石板连接岸上，桥模型不变。扩大岸后把右侧荷花湾移到(14,-0.40,3.4)，避免埋入土地。

运行时用实际网格切水线生成接触距离场。着色保留几何法线，只叠加细小草地法线，修复统一换成朝上法线导致圆坡仍像平面的原因；高度和色斑控制草土过渡，水线变湿变暗。

重建：`blender --background --python-exit-code 1 --python ArtSource/Environment/build_smooth_banks.py`。定向测试、前后证据和补拍节点统一见[邻居岛](../Islets/README.md#验证与视频节点)。

## 布局参数化节点 · 20260918

现役主岛与右岸改由 `Game/layout/courtyard_plan.gd` 的轮廓及 `bank_geometry.gd` 在建场时生成；沿用上面的造型和材质，旧 Blender 源及GLB保持原件。新增模型不经Tripo，不产生费用。主岛4604三角、右岸2588三角，单材质、不额外生成自动LOD。顶底使用轮廓三角化而非固定中心扇，保持凹轮廓边界；索引闭合、共享平滑法线。普通轮廓、扩大、不规则、岸坡宽度及高度变体已进行网格检查。

场景用 `bank_role` 元数据识别主岛与右岸，不再通过GLB文件名推断；水线距离场读取生成网格，鸡的安全区域受真实平地轮廓约束，草地密度和采样边界也跟随平地。当前默认场景的六田角落、右桥出口支承与7只动物初始化通过；全景、前岸和桥头正反近景已检查。此项还不是完整扩建：当前受控向西／向南扩岸（新Plan的 `expand_shore`）已同步岸树、竹花、荷花、岸石、船泊位和动物范围；屋、桥、右岸保持实际尺寸与既定支承。全景／布置取景距离及世界雾清晰区随扩岸更新。建筑草地避让使用实际脚印，墙脚贴花和藤架土床跟随锚点。玩家预览／保存、围栏道路重新生成、任意桥头迁移与地面高度联动全部摆件仍在第08–13项后续工作内。

定向入口 `tests/bank_layout_test.gd`（`--visual`输出近景）。证据 `.local/verification/layout-banks/` 与 `layout-banks-visual.log`。无录屏，需要时可从留存版本与当前源码补拍。

Godot 4.7.2实测：`Geometry2D.triangulate_polygon` 输出二维逆时针索引，将二维Y映射为世界Z后恰好构成朝上的顺时针正面；底盖逆序，坡面法线按引擎朝向计算。官方说明：[Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-triangulate-polygon)、[ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)。

扩岸联动检查：`tests/bank_layout_test.gd` 的 --expanded --visual 运行使用向西2.6米、向南3米的完整场景，证据在 .local/verification/layout-banks/expanded/。修复前真实检查发现桂花树已移动而落花发射点仍固定旧坐标；现改为相对树木的冠层采样及动态包围盒，GPU落地高度仍保持世界高度，新增非空发射点断言。默认布局定向检查干净退出；扩展图形检查断言通过，但退出时仍出现此前间歇性的12个ObjectDB／6个资源清理告警，不能当成独立发布包已验收。当前没有新增资产费用和录屏。
