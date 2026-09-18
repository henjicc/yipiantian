# 主岛与桥头圆润岸坡 · 20260918

旧主岛来自`build_modules.py`的Blender参数化网格：16个轮廓控制点，沿直边加随机点，水平顶面加近乎垂直的土壁。细分没有改变折线本身，所以石缝处仍像切开的板子。旧脚本及`island_bank.glb`保留为历史源。

留存模型入口`build_smooth_banks.py`，Blender5.2.2：Catmull–Rom闭合轮廓，每段16采样，九层从平地到水下的缓坡、闭合底部、平滑法线。主岛保持0.13米耕作平地，向外圆润过渡，不改变六田和房屋的位置。留存主岛4608三角，右岸2592三角；均单材质、拓扑闭合、重导入面数一致，禁用额外自动简化。源和审计见`20260918/rounded-banks.blend`及`audit.json`。

留存GLB为`Game/art/environment/modules/island_bank_v2.glb`与`east_bank_v2.glb`。右岸独立轮廓、原点(12.65,-0.02,-2.8)，覆盖实际桥头出口(约10.37,0.21)，不再缩小主岛来碰运气拼接；桥后补七块石板连接岸上，桥模型不变。扩大岸后把右侧荷花湾移到(14,-0.40,3.4)，避免埋入土地。

运行时用实际网格切水线生成接触距离场。着色保留几何法线，只叠加细小草地法线，修复统一换成朝上法线导致圆坡仍像平面的原因；高度和色斑控制草土过渡，水线变湿变暗。

重建：`blender --background --python-exit-code 1 --python ArtSource/Environment/build_smooth_banks.py`。定向测试、前后证据和补拍节点统一见[邻居岛](../Islets/README.md#验证与视频节点)。

## 布局参数化节点 · 20260918

现役主岛与右岸改由 `Game/layout/courtyard_plan.gd` 的轮廓及 `bank_geometry.gd` 在建场时生成；沿用上面的造型和材质，旧 Blender 源及GLB保持原件。新增模型不经Tripo，不产生费用。主岛4604三角、右岸2588三角，单材质、不额外生成自动LOD。顶底使用轮廓三角化而非固定中心扇，保持凹轮廓边界；索引闭合、共享平滑法线。普通轮廓、扩大、不规则、岸坡宽度及高度变体已进行网格检查。

场景用 `bank_role` 元数据识别主岛与右岸，不再通过GLB文件名推断；水线距离场读取生成网格，鸡的安全区域受真实平地轮廓约束，草地密度和采样边界也跟随平地。当前默认场景的六田角落、右桥出口支承与7只动物初始化通过；全景、前岸和桥头正反近景已检查。此项还不是完整扩建：当前受控向西／向南扩岸（新Plan的 `expand_shore`）已同步岸树、竹花、荷花、岸石、船泊位和动物范围；屋、桥、右岸保持实际尺寸与既定支承。全景／布置取景距离及世界雾清晰区随扩岸更新。建筑草地避让使用实际脚印，墙脚贴花和藤架土床跟随锚点。布局保存、道路围栏重新生成及玩家预览／撤销已接入，见下方节点；地面高度／岸坡配置及其桥头和全部摆件联动仍在第08、09、12项后续工作内。

定向入口 `tests/bank_layout_test.gd`（`--visual`输出近景）。证据 `.local/verification/layout-banks/` 与 `layout-banks-visual.log`。无录屏，需要时可从留存版本与当前源码补拍。

Godot 4.7.2实测：`Geometry2D.triangulate_polygon` 输出二维逆时针索引，将二维Y映射为世界Z后恰好构成朝上的顺时针正面；底盖逆序，坡面法线按引擎朝向计算。官方说明：[Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html#class-geometry2d-method-triangulate-polygon)、[ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)。

扩岸联动检查：`tests/bank_layout_test.gd` 的 --expanded --visual 运行使用向西2.6米、向南3米的完整场景，证据在 .local/verification/layout-banks/expanded/。修复前真实检查发现桂花树已移动而落花发射点仍固定旧坐标；现改为相对树木的冠层采样及动态包围盒，GPU落地高度仍保持世界高度，新增非空发射点断言。默认布局定向检查干净退出；扩展图形检查断言通过，但退出时仍出现此前间歇性的12个ObjectDB／6个资源清理告警，不能当成独立发布包已验收。当前没有新增资产费用和录屏。

可变田块节点：田块定义现有稳定ID、位置／朝向／尺寸、行列、行列到格ID的映射及独立压边石种子。增加行列保留重叠区域原ID；移田和重排不改作物身份；删除占用格整体拒绝，时间和收成不发生部分更新。土面高度／法线、颗粒分布、边石、碰撞、高亮、作物接地、鸡的田块禁入区、聚焦取景和景深保护读取同一尺寸。布局与作物一起进入v5存档；先读布局再建场，备份恢复遇到不同布局则整场重建，避免旧动物路径／水岸缓存残留。当前数据边界为最多12田、每田2–8行／列、总计384格；这只是生成和读盘上限，不是满额性能验收。原默认六田构图仍保留，玩家编辑与空间占用提示见下方整理节点。

定向证据：`farm_state_test.gd` 371项、`farm_store_test.gd` 55项（384格约187KB，当前读盘上限512KB）、`farm_grid_layout_test.gd` 111项通过；`variable_fields_test.gd --visual` 实际七田、5×3／3×4、旋转、第五列播种、土面接缝、鸡禁入、景深清晰区、重进及破损存档恢复通过，本轮正常退出无清理告警。截图位于 `.local/verification/variable-fields/`，日志 `field-state-v5.log`、`field-store-v5.log`、`field-grid-v5.log`、`variable-fields-visual.log`。不是完整扩建或最终发行验收，无新增资产与录屏。

存档注意：JSON数字恢复后需把布局数组重新解码为引擎向量和整数，保持布局比较与初始化一致。Godot的默认JSON数字输出不承诺所有浮点位精确往返，见[JSON.stringify官方说明](https://docs.godotengine.org/en/stable/classes/class_json.html#class-json-method-stringify)；当前向量由布局解码规范化，不能直接用未经规范化的JSON数组与场景参数判定布局变化。


道路围栏节点：`courtyard_circulation.gd` 在真实建筑、植被和摆件建好后提取低处脚印，并加入田界生成静态可行走空间。以屋前真实宽石阶的可达边缘为入口，连接厨房、桥头、泊位、藤架与各田；复用原Tripo石板，单独随机种子使改路不改变植被变体。`fence_geometry.gd` 沿平地内沿生成竹栏、共用转角立柱、合并为两份材质网格；建筑、花石和道路附近留空。动物按每段围栏构建窄障碍，不能把整圈合并网格的凸包当作障碍封死院子。接触阴影覆盖真实布局包围盒，并按世界距离绘制圆形接触，避免非方形扩岸拉伸阴影。默认田和主要建筑未移动；水缸、水桶、晒盘、育苗架、柚子、篮子退离田界，陶罐移到桥侧屋前，柴堆移到厨房后空地，清理田边重叠及厨房堵路。

定向入口 `tests/courtyard_circulation_test.gd`，普通模式为六田，`--expanded --visual` 为向西2.6米／向南3米、首田移到新西侧并旋转8°、南侧新增第七田。两种布局均通过田与模型／地面冲突、道路全段避障、重要入口连通、围栏留口和鸡的实际寻路、移动摆件支承和互不重叠、阴影覆盖检查；无效重叠／岛外田会被空间检查识别。截图 `.local/verification/circulation/{original,expanded}/`；通过日志 `circulation-original-check.log`、`circulation-expanded.log`。空间检查现也用于下方玩家编辑器。

Godot4.7.2导航经验：AStarGrid2D的非实心格点不保证两点间没有几何尖角。实际扩展布局中，厨房旁两点 `(-4.44,-2.64)` 与 `(-4.44,-2.80)` 都可站立，但连线穿过摆件脚印；此前路径平滑阶段直接拒绝整条路线。现建图时缓存这些不可通行的相邻边，通过 `_compute_cost` 排除，同时保留整段碰撞验证；薄三角可绕行、横贯薄墙不可穿行的用例已覆盖。官方入口：[AStarGrid2D自定义代价](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html#class-astargrid2d-private-method-compute-cost)、[Geometry2D](https://docs.godotengine.org/en/stable/classes/class_geometry2d.html)。只改格点或启用禁止切角的对角模式不足以处理真实模型的尖角；惯性和同伴避让也须保留通向下一转角的可见路线。

动物受道路布局影响的回归：`tests/animal_behavior_test.gd` 原有360秒七只动物模拟通过，日志 `circulation-animal-corners.log`；两只鸡分别移动约59.8／55.6米，卡住恢复各6次（同布局修复前33／29次），全部留在允许区并维持间距，要求的日常动作均出现。含验证开销的本机单步样本约0.72ms，不外推长期整机性能。本节点复用现有模型，无新生成费用、无录屏；主岛高度／岸坡配置及桥头联动、后续玩法仍待继续完成；围栏样式与布局选择见下方整理节点。

### 玩家整理节点

入口「布置 → 整理田地」。俯视图可拖动田块，右侧选田、添田／移田、左右转、株距、行列及向西／向前扩岸；布局图显示现有作物、真实建筑／植物脚印、道路和围栏。字段只写草稿，取消或Esc不改变院子；拖动结束后才校验，避免短暂停手打断拖动。检查出越岸、碰撞、删去已种格、堵住重要通路时不能确认。扩岸使用同一批真实几何构造器提取新脚印，不能继续拿旧植物的位置验证新岸；没有扩岸时复用当前脚印。

权威事务仍在主场景：从实时种植状态构造候选，先由原FarmStore完成可靠写盘，再重建整个场景；写入失败保持原院和作物、保留草稿重试。重建传递本次景深、雾和预览光照。最近一次整理的撤销在本次运行内保留，跨空间重建传递；退出程序后清空。撤销只还原布局，不能回退已收获数量和生长；新田有作物时先拒绝，收获后可撤销。加入围栏样式后存档为v6／farm-v6，旧v5目录保留、不迁移。

`tests/courtyard_editor_test.gd` 覆盖取消、重叠拒绝、已有作物保护、实际七田扩岸／转田／缩行、写盘失败重试、重建、撤销保护、收成不回退及保存再读；`--visual`补画面，`--visual --ui-only`只检查真实鼠标拖动／释放／Esc、旋转／株距及最小窗口。原入口通过日志 `.local/verification/courtyard-editor.log`、`courtyard-editor-visual.log`、`courtyard-editor-input.log`；截图按同前缀目录保存。无需录屏、新模型或重复动物长测。仍须继续完成第08、09、12项剩余的完整高度、岸坡配置和桥头／泊位联动，不能把编辑入口当作整个参数化阶段已完成。

布局与围栏选择：`courtyard_presets.gd` 提供原院、西畔菜圃（西扩2.5米，首田旋转90°）、前庭宽院（西扩2.5米／前扩3米，两田移到新岸）。套用保留全部田块／田格ID、尺寸和作物，额外田也不删除；自定义大田或摆件有冲突时留在预览等待调整，不能强行覆盖。双横竹栏、交叉竹栏和细竹篱共用同一组支承、碰撞段与道路开口，样式进入存档，预览／取消／撤销走相同事务。

Godot4.7.2实测：围栏样图用独立世界的SubViewport显示真实模型，只在切换样式时UPDATE_ONCE。节点属性可能仍返回ONCE，不能以该缓存值断言它还在持续渲染；测试读取RenderingServer实际更新模式，三种样式均已停止。官方[SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html)、[RenderingServer.viewport_get_update_mode](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-viewport-get-update-mode)，相关[引擎问题33351](https://github.com/godotengine/godot/issues/33351)。查询只用于验证，产品不逐帧读取渲染服务器状态。

西扩预设暴露的入口问题：最近的可走采样点可能在岸石后方的孤立小空地。入口连接现按距离尝试既定容差内的可达点，不扩大容差，也不跨障碍直连。`--visual --presets` 覆盖三个真实布局的田块支承、入口连通、道路每段避障、草稿隔离、样式保存后实际几何与撤销；通过日志 `courtyard-presets-fixed.log`，画面 `.local/verification/courtyard-editor-1746801/`。v6存档原有定向检查通过，日志 `farm-store-v6.log`；新增控件后的真实鼠标／最小窗口检查通过，日志 `courtyard-presets-input.log`、截图 `courtyard-editor-1758356/editor-small-window.png`。此节点没有新模型费用或录屏。
