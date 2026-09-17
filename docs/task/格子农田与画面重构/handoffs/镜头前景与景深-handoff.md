# 镜头、前景与景深交接

日期：2026-09-17。状态：完成并冻结。主代理已实际查看并接受最后前景构图；布置专用取景最终真实点击38/0，主链headless12/0。未提交代码。

## 范围与接口

仅修改 `Game/scenes/farm_camera.gd`、`Game/presentation/camera_foreground.gd`、`Game/presentation/focus_detail.gd`。保留 `focus_field`、`return_overview`、`reset_view`、`view`、`focus_point`、`motion_finished`、`is_transitioning`，不复制农场状态，不改变格子选择或存档。前景仍使用 `configure(camera, fields, environment)` 与 `set_overview_visible(value, immediate)`；画质仍为 `set_quality('standard'|'low')`、`set_depth_of_field(enabled,strength)`、`get_settings()`。

- 全景目标 `(0,.85,0)`，yaw25°／俯角28°／距离28m，垂直 FOV29°。原视角为 yaw32°／俯角34°／距离29.5m／FOV35°。在相同新光照下实拍31、28、27m，主代理接受28m：放大院落、减少空水、桥船不裁切；27m底部更挤。
- 聚焦40°／10.4m，缩放8.5～16m；全景缩放27～38m。微调俯角聚焦32～54°、全景24～40°，转场仍.75秒并保存返回姿态。低全景角度不直接用于操作近景，近景仍露出四行格土表面。
- 不再将整棵树冠贴在镜头四角。两片岸石、曲枝、错位双叶及草叶在初始化时投到世界水岸平面 y=-.18，此后不追随镜头；石根半入画，具有真实视差，极端移动可自然出框。复用3个现有 Blender 岸石模型，枝草为本轮 Godot 程序几何，未生成新 Tripo 资产。
- 三种叶色、静态枝干和同材岸石在每个岸片初始化时合并；最终共16个表面。叶片沿用共享风动 shader，枝石不动，叶片世界位移上限6mm、微扰2mm，合并叶组下缘根锁。两岸世界根点约 `(-2.982162,-.18,11.92815)`、`(11.07094,-.18,5.53591)`。
- 前景整片避开六田及八槽投影保护区，不再以 shader 矩形裁切叶缘。聚焦、布置、低画质时淡退；DOF关闭时保留真实几何。根锚向内移至屏幕(.08,1.02)/(.92,1.03)，左枝3～4.05m、右枝1.7～2.42m形成不对称层次；最终左侧叶片约占y.70～1、右侧y.82～1。仍不能把它描述为已逐像素还原。
- DOF采用圆形散景、高质量、无抖动采样。全景近清晰界线由六田最近深度减1m计算，近过渡4.5m、强度.085；聚焦使用全田包围盒深度前后各.6m余量、近过渡2.5m／远过渡5.5m、强度.045。UI为独立Canvas不模糊，同深度邻田可能清晰。快速换田先清除旧焦距，保护带立即扩张、平滑收缩。
- 标准4×MSAA、SSIL开启并应用用户DOF偏好；低档2×MSAA、SSIL关闭、DOF与前景临时关闭。低档不覆盖用户的DOF开关/强度，关DOF不关闭LOD。SSIL操作唯一现有WorldEnvironment，不新增环境副本。

- 增加 `set_decoration_framing(active: bool)`：布置临时固定yaw25°／pitch34°／距离31m、目标点(0,-.95,0)，避免地面槽被底栏覆盖并保持八槽真实几何可见。缓存进入前全景姿态，正在返回全景时取tween目的而非途中姿态；退出恢复，重复调用幂等。reset清布置取景并恢复正常默认，focus_field会先退出临时取景。主场景信号由交互代理接入。

## 实际证据

Godot **4.7.2 stable official ed1daf0bf / Forward+ / RTX4090 / 1920×1080**。只用 `.local/verification/camera-reconstruction/` 隔离农场及偏好目录；UTC夹具固定1800000000，12/16.5/21仅视觉展示时间，并在截图前临时同步HUD时钟；不改系统钟或真实玩家档。96株为显式成熟混种夹具，不是新玩家默认。

1. `pilot-01`／`pilot-02` 为独立院落构图过程图，非主场景验收。`tones/01-overview.png`、`tone-linear09.png`、`tone-agx13.png` 为同16.5时刻/相机的Filmic1、Linear.9、AgX1/contrast1.3/white6探针。主代理据此选择并自行实施生产Linear光照；本代理未改day_night或project配置。
2. `main-final-pilot/` 为真实主场景/HUD，首次默认仅4株：`default-distance-31.png`、`default-distance-28.png`、`default-distance-27.png`；`default-hour-12.0.png`、`default-hour-16.5.png`、`default-hour-21.0.png`。另有 `mature96-overview.png`、`mature96-focus.png`、`mature96-focus-no-dof.png`、`mature96-overview-no-dof.png`、`mature96-low.png`。此轮前景世界根在31m初始化后靠近，底角自然出框，故它不是最终前景图。
3. **合批初图（露出不足，已替换）**：`final/01-overview.png` 与 `final/02-dof-off.png`，默认28m初始化、16.5时刻、默认4株。两图已实际目检，六田/桥船/主体完整，关闭DOF仍是弯曲叶面而非透明贴片；前景仅占底角，主体清晰；主代理复核认为露出不足，未接受为最终前景，待向内调整。`final/measure.json`：16个前景表面，同镜头全场绘制997次，隐藏前景981次，增加16次；low_ssil=false、standard_ssil=true。这是单帧绘制计数对照，不是帧率或性能长期承诺。
4. **最终前景补修图**：`final-anchor/01-overview.png`，叶柄连续、左高右低、近石遮根，六田/工具无遮挡。本人实际目检通过，主代理也已实际查看并接受最终前景构图。`final-anchor/measure.json`仍为997/981绘制、16表面及SSIL开关正确。
5. Import与独立/主场景探针均exit0，日志无ERROR；最终日志 `final.log`，运行方式 `scripts/godot.ps1 -Action Run -ExtraArgs @('--script', '<repo>/.local/verification/camera-reconstruction/foreground_final.gd', '--', '--output=<repo>/.local/verification/camera-reconstruction/final')`。探针文件与PNG均仅本地留档。
6. 交互代理此前真实16格输入62项通过。状态代理完成28m/合批快照complete219/0、focus51/0、plant132/0、prototype0失败；decoration32/1确认为ground_04屏幕(779.63,578.56)被底栏Lantern按钮遮挡，不是几何可见检查失败。初次30m/低目标试验又使ground_02/03被竹叶/藤架遮挡，保留失败日志；最终采用固定34°/31m/目标y=-.95，定向探针8槽geometry均true，1280×720与960×600实际GUI hover均空，ground_04投影(766.30,504.59)，在底栏上方。最终真实点击38/0、exit0通过，1280窗口八槽、960×600窗口ground_03→04均实际可点，含失败重试/重开；不弱化断言。小窗测试事件因push_input默认重复坐标缩放造成的一次假失败由测试owner明确改为已局部坐标=true，未修改产品拾取。交互代理新增main接线headless12/0，本代理在最终固定pose上再次headless12/0、exit0无ERROR（`framing-final.log`），覆盖聚焦返回中进入布置、快速开关重入、重复finish、reset、设置覆盖/返回、Esc以及镜头缓存不漂移。最后前景根锚/高度补修在这五项之后，仅影响边缘几何，不将首轮回归冒充布置修复后的通过。

## 版本行为依据

已核验官方4.7文档及真实本地4.7.2：

- [CameraAttributesPractical](https://docs.godotengine.org/en/4.7/classes/class_cameraattributespractical.html)：近远距离与过渡使用米，正过渡逐渐达到blur_amount；只调amount不能保证全田清晰。
- [RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html)：`camera_attributes_set_dof_blur_bokeh_shape` 与 `camera_attributes_set_dof_blur_quality` 是全局渲染配置；本项目单操作镜头，无并行不同相机散景需求。
- [Environment](https://docs.godotengine.org/en/4.7/classes/class_environment.html)：AgX独立`tonemap_agx_contrast`／`tonemap_agx_white`，并非Filmic的white参数；SSIL由environment开关控制。

## 参考差距与后续边界

已实际查看原参考主界面和旧rc2实机ready图。新构图更低、更近，房屋立面与远岸层次更明确；仍不是参考插画的像素复刻，资产风格、岸坡连续性和叶群密度仍有差异。色调、桥岸、远景属于主代理整合，不能把其他代理贡献算作镜头代码。前景遵循有限世界位置，极限绕看时可能退框；正常聚焦/布置会主动隐藏，不强行保持四角框景。全景与近景按深度景深，不提供按对象抠图虚化。

本轮自有Godot探针正常退出，GPU已直接交状态代理。用户既有PID48360、38488、74488未操作。未录像、未导出候选、未修改真实存档。后续正式性能、录屏与候选由主代理统筹；本轮不把旧rc2性能或影片冒充新源码。布置探针证据 `decor-framing2/candidates.json` 第二组，以及 `pitch34-distance31.png`（同组）；未跳过遮挡算法，也未扩大可点击距离。
