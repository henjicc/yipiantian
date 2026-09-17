# 风动与前景交接

## 实现与接线

- `Game/presentation/plant_wind.gd` / `.gdshader`：`PlantWind.new().apply(root, kind)`。覆盖 tree、bamboo、flowers、lotus、grass、greens、radish、trellis、flowerpot；院落代理已接环境高低资源与岸草，FarmLayout 接全部作物。运行时表面材质覆盖保留已审计资源的颜色贴图、UV、标量 PBR；不改 Mesh、导入 LOD、节点位置或碰撞。
- trellis 顶点通过原贴图的绿色比率乘高度遮罩，只让棚叶/藤叶轻摆，木色与黄色葫芦的遮罩为零。使用官方支持的 `textureLod(..., 0.0)`，不依赖顶点阶段缺少的屏幕导数；其余植物不额外查此贴图。flowerpot 的 0.62 m 资源固定底部 42%（约 0.260 m），盆体与土固定，盆上茎叶/花轻动。FocusDetail 在读档刷新及新增实例回调按正式资源路径接花盆，覆盖确认件与移动预览。
- 根部高度遮罩为零，树干中心额外固定，树冠轻摆并叠加细微叶颤；菜的主位移上限 5 mm，幼苗按高度进一步缩小。节点不做整树钟摆，shader 使用真实 TIME，不接生长时钟。
- `Game/scenes/farm_layout.gd`：统一 4×4 共 16 个种植锚点，X 为 −.90 + 列×.60，Z 为 −.66 + 行×.44；跨阶段锚点及朝向固定，正式资源、scale=1、入土量、田块 ID 保持。六田最高 96 株。土与沟垄接根代理新增 `soil.gdshader`，保留原色并传 wetness。
- `Game/presentation/camera_foreground.gd`：FocusDetail 在 Camera3D 下创建，无主场景新入口。复用已有 Tripo tree / bamboo 的低模，四角少量真实三维枝叶，无碰撞或存档状态。默认全景显示，聚焦与布置约 0.29 秒退让；低画质在切换 MSAA 前立即移除。关闭景深时前景保持清晰，尊重用户偏好。
- `Game/presentation/focus_detail.gd`：全景只启用近景虚化，6 m 前景与院落分离；原聚焦整田清晰带保留。前景投影保护区包含六田角点及八槽，只有镜头/尺寸变化才更新；中部裁切只作保护，构图须以自然叶缘为准。

材质支持范围根据当前 GLB 审计确定（opaque、double-sided、albedo texture、无 normal map），并非任意材质转换器。Godot 4.7 的坐标/实例参数契约参见 [Spatial shader](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html) 与 [GeometryInstance3D](https://docs.godotengine.org/en/4.7/classes/class_geometryinstance3d.html)。

## 验证证据

原生 1920×1080、隔离农场与 preferences，`tests/plant_presentation_test.gd` 最终 **127 项 / 0 失败，退出 0**。固定测试农场 UTC，视觉 shader TIME 正常推进，不改系统时间或玩家档。

```powershell
./scripts/godot.ps1 -Action Run -ExtraArgs @('--script', "$PWD/tests/plant_presentation_test.gd", '--', "--output=$PWD/.local/verification/atmosphere-plants/final")
```

- 96 株与六田根变换、环境树变换固定，六田真实射线仍命中；贴图与粗糙度保留，农场快照不变。
- 固定镜头/光照下，相隔 1.7 秒的树冠 160×140 区域有 2771 像素变化，近景菜叶 84×84 区域有 483 像素变化（通道差阈值 .015）；这是实际渲染变化，不将节点位移充作风动证据。
- 全景近景虚化、关闭 DOF、低画质、快速换田、布置退让、夜景均覆盖。截图与 `results.json`、`run.log` 位于 `.local/verification/atmosphere-plants/final/`，01/02 全景、03/04 聚焦、05 关闭 DOF、06 低画质、07 布置、08 夜间。
- 初轮 pilot 的测试节点路径错误已修；pilot-02 暴露低画质切换时半透明前景残留，已修为切换前立即隐藏，最终 06-low 实图无残留。失败目录原样保留，不计为通过。

上述动态回归后，根代理要求加强两侧框景：左树改为 scale .90 / anchor (−1.04,−.60)，右树 .85 / (1.09,−.88)，上角竹枝未加密。随后补全棚叶与花盆接入，原生整合测试增至 **132 项 / 0 失败、退出 0**，证据 `.local/verification/atmosphere-plants/all-foliage/`；包括花盆读档实例、合法移动预览接风、取消不改装饰快照。新 01 全景已目视两边自然叶缘、无明显直切，聚焦/布置/低档退让仍过。

`tests/mixed_plant_wind_test.gd` 单独实例化棚架与花盆的高低模，无农场或存档：**22 项 / 0 失败、退出 0**，证据 `.local/verification/atmosphere-plants/mixed-pilot/`。源顶点/UV/贴图审计中，棚架高低模分别 13137/7435 个木色/葫芦色顶点遮罩为零；花盆 2785/1375 个底部顶点遮罩为零，实际配对帧盆体区域均 0 像素变化，四资产叶部均有变化。源 Mesh 与贴图引用保持；全模型 Transform 不动。测试首启动仅修正 Windows 路径分隔符的输出保护判断，未触碰玩家档。新增 API 依据见 [4.7 textureLod](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/shader_functions.html#shader-func-texturelod)。

## 所有权、贡献与后续

本切片为两个已有脚本、三个新呈现文件及其 UID、两个新测试和本交接；不改 main、courtyard、day_night 或农场序列化。植被与前景使用既有 Tripo 模型，本次新增贡献为风动 shader、材质接入、镜头框景/景深与种植密度；土 shader、暖窗、生活组、水面/远云分别由其他代理提供。

植物定向测试与性能测试窗口已全部正常结束，GPU 已释放，用户原有实例不关闭。八槽完整交互由院落代理验证。旧 54 株性能结论不直接套用于本次 96 株与新增材质，独立性能证据位于 `.local/verification/atmosphere-performance/`。没有声称完成真实用户试玩或所有镜头角度人工验收；最终整合图、提交与录制由根代理统一调度。

## 本轮整合性能证据

生产内容为 `c64b0e9` 加本次氛围提升工作树，使用 Godot 4.7.2 普通引擎运行正式主场景并采样，非 MovieMaker，也不冒称发行包逐帧测量。六田共 **96 株成熟作物、3 件装饰、近岸屏幕反射、植物风动、全景镜头前景与两盏暖窗灯**均存在。标准档 4×MSAA、VSync/cap 60，分全高 / LOD / LOD+DOF；关闭 DOF 的比较组按设计不虚化，聚焦时镜头前景退让。

机器为 Windows 10 19045 / Ryzen 9 5900X / 64 GB / RTX 4090，显卡驱动 610.47。两个已知用户 Farm.exe 路径只读取证均无运行实例，复核文件 `background-processes-rechecked.json` 同时保存全体 Farm.exe 查询空结果；没有关闭用户进程。GPU 遥测仍是整卡数据，不等同测试进程独占整台机器。

- **1080p smoke：164 项 / 0 失败、退出 0**，目录 `smoke/`。覆盖昼夜全景/聚焦/布置各三种细节共 18 组，加靠近、缓转和后台恢复；每采样组仅 2 秒，为链路检查。各组最差 p95 **17.278 ms**、p99 **17.949 ms**，最长单帧 **30.807 ms**；工作集峰 **920219648 B**（约 878 MiB），private bytes 峰 **2253213696 B**（约 2.098 GiB），两者口径不同。启动至采集器确认可操作上界 **6.334 秒**。实际后台 5.067 秒为 **14.999 fps**、音轨峰 0，恢复音轨非零，UTC 继续；不称 OS 休眠或长时间后台验收。
- 首次 `4k/` 在第一组失焦到 ChatGPT，自动降为后台 15 fps，尺寸也发生变化；按实际证据中止自有 PID，保留 `interrupted.json` / 原始 CSV / stderr。此目录不纳入达标结论，未过滤失焦帧或修改后台行为/阈值。
- **4K 重测：56 项 / 0 失败、退出 0**，目录 `4k-retry/`。中午全景/聚焦各三种细节共六组，每组实际 60.001～60.013 秒、全部 0 失焦帧，实际原生渲染 3840×2160。进程共 409.718 秒，正式场景 402.835 秒，stderr 为空。既有产品目标 p95≤20 ms / p99≤33.4 ms 是标准 1080p 目标；以下另列本机实际 4K 数字，不将 4K 扩充为夜晚/布置全矩阵或最低配置承诺。

| 4K 中午条件 | 平均 fps | p95 / p99（ms） | 最长帧（ms） | GPU 中位（ms） | CPU render+setup 中位（ms） |
| --- | ---: | ---: | ---: | ---: | ---: |
| 全景 / 全高 | 60.015 | 17.078 / 17.294 | 26.509 | 5.747 | 0.774 |
| 全景 / LOD | 60.020 | 17.038 / 17.282 | 32.514 | 5.390 | 0.782 |
| 全景 / LOD+DOF | 60.020 | 17.001 / 17.262 | 30.994 | 5.773 | 0.779 |
| 聚焦 / 全高 | 60.021 | 17.021 / 17.380 | 32.917 | 5.789 | 0.804 |
| 聚焦 / LOD | 60.020 | 17.032 / 17.333 | 31.338 | 5.788 | 0.806 |
| 聚焦 / LOD+DOF | 60.021 | 17.010 / 17.376 | 32.925 | 5.590 | 0.809 |

4K 工作集峰 **1018982400 B**（约 972 MiB），private bytes 峰 **3187322880 B**（约 2.968 GiB）。原目标是工作集≤2 GiB，不能把此结论说成所有内存口径均≤2 GiB。各分钟工作集中位约 984.7～985.8 MB，短段未见持续上升；这不是长期泄漏证明。启动可操作采集上界 **6.479 秒**。60 fps 上限下 GPU 动态频率会变化，三组 GPU 小幅差异不作为 LOD 必然提速的证明。

CPU render+setup 不包含脚本/物理；Windows 窗口所属线程 CPU 为 1 Hz 累计增量，不能当逐帧 p95。原始引擎帧 CSV、Windows 工作集/private/线程数据、GPU 频率遥测、启动与后台 JSON 可追溯。此次不复用旧 30 分钟 201/0 来证明新增画面长期稳定性。
