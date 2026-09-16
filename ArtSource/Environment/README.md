# 正式院落资产（3.2）

本目录交付能独立导入的可编辑环境源、真实生成来源、同源高低档与可复现的精确模块。玩法、保存、解锁、声音和动态水不属于本目录职责。

## 来源与分工

- 内置 image_gen：以固定青菜与全景图为风格参考，生成船、庭院树、竹、野花、荷叶、藤架和三件装饰的单体图。野花去除误带的白粗茎、荷叶去除光晕，各仅定向修正一次；所有生成/修正均使用图像工具。
- Tripo CLI 0.4.0：九个原始 image_to_model 任务，全为真实 `v3.1-20260211`，texture=true、PBR=false、smart_low_poly=true、standard 纹理、original_image 对齐、image_autofix=false。各 **40 积分，共 360 积分**；没有为高低档重复付费。逐项真实 ID、请求参数、成功时间与费用见各目录 `tripo-original/task.json`（已移除签名下载URL）。
- Blender 5.2.2 LTS：`prepare_assets.py` 统一米制、接地/顶挂原点、同源低档、清理/法线、GLB重导入；`build_modules.py` 制作自然岛岸、五种河石、石桥拱券/栏杆、竹栏、入口棚、側屋瓦顶/山墙/窗门、廊台、田框；`House/repair_ridge.py` 只闭合原民居屋脊两端局部缺口，闭合塞用匹配的深灰瓦色，中段原纹理保留，原始 Tripo 模型不动。
- Godot 4.7.2：独立对象组装、地表/石材温和色层、自然间距、低档独立可控；独立实机验证环境 `Game/scenes/environment/environment_sample.tscn`。所有镜头截图均为真引擎输出，不是概念图覆写。
- 远景：`Backdrop/river-distance.png` 为单独生成的山水远岸画，不包含本场院落或交互物件；映射完整环形曲面，水面远处渐隐承接。允许平面远景，近景全为三维对象。

每项图像工具未单独返回模型版本、种子或价格，记录为未返回。用户要求暂不执行商用身份/授权调查，不把此项写成已通过。此处为开发侧视觉检查，不冒称用户已审美确认。

## 工程接口

`res://scenes/environment/courtyard.tscn` 可独立实例化；不改主场景、不加载农场状态。它仅依赖纯定义 `farm/decoration_catalog.gd` 的 ID/类型/可旋转角数。

- `get_decoration_slots()` 返回8槽 `id,type,transform,allowed_turns,radius`；`get_slot_marker(id)` 返回实际 Marker3D。坐标唯一真相在本场景，3.3存槽ID及quarter_turn，不另存坐标。
- 地面 `ground_01..04` 半径 .45m，允许0/90/180/270°；悬挂 `hanging_01..04` 固定0°，顶环归零、灯体向下 .65m，实体杆/绳接点。
- `get_decoration_scene(item_id,low_detail)` 返回 PackedScene；陶罐玩法ID `pot` 映射资源 `jar`；另有 `flowerpot,lantern`。
- `get_water_surface()` 返回 `WaterSurface`，180×180m XZ水平平面、法线上+Y、y=-.25；静态水shader径向22..35m淡出。3.4必须接管 `material_override`，不能被起始材质盖住。
- `get_backdrop_material()` 返回 ShaderMaterial，`atmosphere_tint` 默认白，3.4用它改变夜间远景；不使用全时白天的固定未着色背景。
- `get_asset_keys()` / `set_asset_detail(key,low_detail)` / `set_low_detail_enabled(bool)` 可独立控制复杂对象，高低来自同一网格与颜色贴图。简单测量模块共用单档，保留Godot导入自动LOD。
- 六田仍为两排三列、中心 `(-3.3+col*3.25,.2,row*2.8)`、soil2.6×2.05m；本环境只放田框，农田交互和作物由3.3实例化。

## 验证与边界

各 `asset-audit.json` 记录真实高低三角、尺寸、材质、纹理、非流形边、孤点及重导入结果。非流形边来自叶/窗/瓦等生成细节，不承诺打印/室内/物理船舶用途。复杂资产轮廓及开放结构另用实机正背图检查。

本地 `制作留档/03_处理与验证/05_完整院落环境/` 保存1920×1080全景/近景/高低/轻DOF/合法极限/背面/三装饰/四挂点图、对照网页及验证JSON。6田射线只证明字段碰撞命中，视觉遮挡由截图目检，二者不混淆。合法相机yaw[-12,68]、pitch[28,58]、概览distance[22,34]、平移±2；180°背面为额外结构压力检查。

图中动态水、反射、时段光色和灯笼光留3.4；样片所有田统一放青菜是环境可见性标尺，正式两作物全阶段由3.1/3.3接入。没有扩展航行、建筑或角色系统。没有宣称静帧是实时性能证明；3.5/4.2据正式场景计时选择档位。
