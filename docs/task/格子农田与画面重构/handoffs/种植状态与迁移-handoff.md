# 逐格种植状态与存档迁移交接

2026-09-17；基线 `955f253`。本切片完成逐格权威状态、v3 存档与相关测试夹具改造。未自行提交；GPU 场景验证等待根代理排期，下面的纯核心通过不代表画面和完整发行验收通过。

## 最终接口

- 六个 `FIELD_IDS` 不变；每田 `CELL_IDS = cell_01..cell_16`，4×4 行优先，列沿 +X、行沿 +Z。
- `snapshot()`：`{fields:{field_id:{cells:{cell_id:{crop_id,growth_seconds,last_settled_utc_seconds,watered}}}},harvested:{greens,radish}}`。时间与数值仍只由 FarmState 持有，返回深拷贝。
- `get_field(field_id)` 返回 `{id,cells}`；每个 cells 字典值等同 `get_cell(field_id,cell_id)`，含原四字段及 `id=cell_id`、`field_id`、`stage`、`progress`、`remaining_seconds`。不存在的标识返回空字典。没有整田作物／阶段的兼容字段。
- `sow(field_id,cell_id,crop_id,now)`、`water(field_id,cell_id,now)`、`harvest(field_id,cell_id,now)`。不保留旧整田签名、不默选某格；未知／空 cell_id 返回 `invalid_cell`。单格成熟收获 1 篮，两作物原时长、浇水 20% 和阶段阈值不变。
- 动作前按同一时间结算全部格，失败动作连时间也不改变；操作作物与奖励只影响选中格。`changed_fields` 仍为去重的大田 ID，供既有刷新入口使用，不增加无人消费的 changed_cells。
- 空格、成熟格同样保持最新结算基准；回拨不倒退，前跳只推进当前一轮，无自动收获。新档原有四份作物分别放于原第 03～06 田的 `cell_06`，其余为空，不将历史 16 个视觉实例变成 16 份奖励。

## v1／v2 → v3

`FarmStore.VERSION=3`。v3 必须恰好六田、每田恰好16个稳定ID、每格原四字段；拒绝缺格、多格、错ID、旧结构冒充v3、新结构冒充v2、非法数值与非法装饰。

真实旧 v1／v2 每田四字段严格验证后，完整复制至 `cell_06`；其余15格为空，`last_settled_utc_seconds` 与该旧田一致。累计篮数原样保留。v2 装饰解锁、槽位、旋转原样保留；v1 本来没有装饰，只按原累计导出已获解锁，不发明位置。

读取迁移不写原档；第一次成功写 v3 前保存 `farm.v1.<旧内容SHA256>.json` 或 `farm.v2.<旧内容SHA256>.json`。同内容重试复用原件，已有原件字节不符或链接则拒绝，不覆盖。写入中断保留旧 main 和原件；恢复旧备份后再保存，同样留存旧版原件。迁移后再读不重复迁移／发奖。

保留 pending／backup／安全替换、显式损坏恢复、未来版本锁写、已读字节期待值拒绝旧实例覆盖新档的现有机制。没有放松未来版本或坏数据为默认新档。未引入新的跨进程锁；测试覆盖既有双实例较旧快照冲突拒绝，不声称验证操作系统级同时竞争的全部时序。

`MAX_BYTES` 保持65,536。96格均带长小数和极大有限时间、最大精确累计数、三件完整装饰，实际生产格式序列化45,029字节并成功保存重载，无需扩大上限。

## 首轮纯状态验证

固定 Godot 4.7.2，经 `scripts/godot.ps1 -Action Run`，仅 `--headless --script`／`--check-only`，无导入、GPU、玩家程序操作。

| 验证 | 实际结果 |
| --- | --- |
| farm_state_test | 237 项，0失败，退出0；16格混种、相邻格隔离、单格奖励、失败原子性、阶段边界、在线离线等价、回拨／前跳、深拷贝、96格严格schema |
| farm_store_test | 289 项，0失败，退出0；v3往返、真实v1/v2迁移、原件冲突、写失败重试、旧版备份显式恢复、坏档／未来版保护、Windows只读替换失败、旧实例拒写、96格大小 |
| decoration_state_test | 47项，0失败，退出0；逐格收获阈值不消费、实际旧v1迁移与装饰保存恢复 |
| 七个场景夹具 check-only | complete_scene、focus_detail、plant_presentation、performance_validation、atmosphere_scene、prototype_smoke、decoration_interaction 均退出0，无解析错误 |

日志在 `.local/verification/cell-core/{state,store,decoration}.log` 和七份 `check-*.log`。最终存档测试隔离路径为 `.local/verification/farm-store-177593/`；装饰测试为 `.local/verification/decorations-190915/`。预期失败分支产生 FARM_STORE warning，最终无 SCRIPT ERROR 或 ERROR；不把预期失败 warning 隐去。

排错事实：旧夹具以相对 `--script ../tests/...` 运行会获得 `res://..`，已将本切片涉及的夹具根目录改为显式 globalize 后的工程外 `.local/verification`。Godot JSON 版本为浮点数，数组 membership 不能代替此前的数值相等比较；版本接受保留显式 `!=1 && !=2 && !=VERSION`，已由实际重载通过验证。两个早期失败的自有 headless 进程均已关闭。

## 场景夹具后续

- complete_scene：96格逐格混种并覆盖两作物六阶段，逐一核对 `Crops/cell_XX` 模型、尺寸、根深；同构图全成熟对照使用真实96格状态。
- focus_detail、plant_presentation、performance_validation：每田16格交替两作物、共96个成熟状态，保持原LOD／DOF／风动／帧时／后台UTC断言。性能脚本的动作改为选择格再点工具，不重复调用 `_apply_tool()`。
- atmosphere_scene：先真实点击成熟 `cell_06`，再点击收获按钮，检查音效与单次奖励；后台生长读具体格。
- decoration_interaction：先选空格再进入布置，检查田／格／工具选择均清除且布置点击不改农场。prototype 保留镜头输入与小窗断言并补正确资源清理。
- decoration_state 的 v1 fixture 不再把新snapshot冒充旧档，改为真实旧平铺田；未来版本用 VERSION+1。

此处为首轮交接时状态：七个场景当时仅完成解析。后续原生结果见下文最终冻结段，performance由根代理单独执行。farm_interaction／farm_storage_scene／ui_settings_scene 三个测试归2_2，录制脚本归根代理，本切片未修改。实际画面重构／灯光／镜头／main接入也不在本切片写范围。

## 精确交付范围

生产仅 `Game/farm/farm_state.gd`、`Game/farm/farm_store.gd`。

测试十个：`farm_state_test.gd`、`farm_store_test.gd`、`decoration_state_test.gd`、`complete_scene_test.gd`、`focus_detail_test.gd`、`plant_presentation_test.gd`、`performance_validation.gd`、`atmosphere_scene_test.gd`、`prototype_smoke.gd`、`decoration_interaction_test.gd`，均在 `tests/`。

首轮文档为本文件。随后根代理明确增派共享文档所有权，本代理另更新 `README.md`、`docs/development-setup.md`、`rules/project-context.md`：当前操作、96格v3和原件迁移为现事实，rc.1／rc.2的旧整田性能／截图／录屏／包验收均标为历史，不提前宣称rc.3通过；保持 `template_state: ready`。本轮没有运行用户rc.2、触碰真实档、导出或提交。

## 独立调用链审查

在2_2格子接入后独立阅读main／FarmLayout／HUD与核心／存储的本轮diff，未发现需要报告为缺陷的状态错位或单格改邻格问题。这是当时的静态审查结论，不替代后续真实窗口验证。

- 土面射线先取得field，再以相同4×4行优先坐标取得cell；边面只聚焦田，不虚选小格。视图、状态与存档均使用同一稳定ID。
- 全景点田清除旧cell；聚焦后世界点击只选cell。按钮按下／松开必须绑定同田同格；镜头移动、模态、保存失败、失焦与拖动取消可阻止补发操作。工具执行完成不留下武装状态。
- renderer按field/cell缓存作物阶段与湿土，目标格变化不整田重建；浇水只改该格土材质，收获只清该格作物。所有格的UTC自然结算仍统一推进，这不是相邻格被错误种植或浇水。
- 迁移先严格验真实旧形状，再校验完整v3候选，读阶段不覆盖原文；旧唯一作物仅产生一份奖励，已有装饰和累计未被视觉数量改变。坏档／未来版与旧实例字节冲突仍拒绝写入。

已将审查结果发根代理和2_2，未越权改其main／layout／HUD。七个已适配场景夹具保留原测试意图，后续GPU证据由根代理安排后补。

## 本轮原生窗口回归（进行中）

固定 Godot 4.7.2 / Vulkan Forward+ / RTX 4090，按根代理 GPU 时隙顺序执行，每项新的隔离目录；截图不是性能证据。首轮输出位于 `.local/verification/grid-regression/`。

| 测试与目录 | 结果 |
| --- | --- |
| `complete-final` | 219项／0失败／退出0，12张截图；新档、96格混种六阶段、96格全成熟、聚焦与夜景。首轮6项射线失败是夹具仍将终点设于旧厚碰撞体上方，改为实际碰撞中心后全过，保留首轮日志。 |
| `focus-final` | 51项／0失败／退出0；实际3840×2160，高低LOD与DOF对照、96格混种。 |
| `plant-final` | 132项／0失败／退出0；1920×1080，成熟作物区域812个像素、树冠4027个像素随正常shader TIME变化，布置净空／低档／夜景截图。 |
| `prototype-final` | 0失败／退出0；真实射线选田、镜头切换／拖动／失焦、小窗960×600。 |
| `decoration-final` / `decoration-diagnostic` | 各32项／1失败／退出1，真实缺陷待修复：ground_04投影(779.6309,578.5554)命中底部Lantern按钮，pot留在ground_03；其余7槽可输入。几何可见性全部true不能证明未被GUI遮挡。已报告根代理及界面／镜头所有者，未越权改产品、未绕过或放松输入断言。 |

本代理已查看全场景／聚焦／夜景、LOD、布置及小窗实际截图。以上五项完成后已释放所有自有Godot进程，交给镜头代理做最后前景调整；之后按根安排接气氛三项及装饰修复复验。最终结果补在下节，不能以本节提前认定全部通过。

### 气氛补充检查

- `atmosphere-scene-diagnostic`：27项／0失败／退出0，四时段真实主场景、实际点击cell_06收获一次、后台UTC与音频静音／恢复。收获PCM峰值0.115067，foreground=true且动作播放时戳已更新。首轮 `atmosphere-scene-final` 有一次音效捕获峰值失败，其余26项通过；加入只读诊断后复验通过，未改声音实现或阈值，首次采样失败原因未确定，保留原日志。
- `atmosphere-final`：42项／0失败／退出0，独立实际混音、循环、静音、去重、最小化与昼夜连续性。
- `mixed-wind-final`：22项／0失败／退出0，藤架与花盆高低档叶片限定运动，木架／器皿固定；8张原生截图已目检代表藤架图。
- 布置首次取景修复让ground_04避开按钮，却造成ground_02／03被几何遮挡；`decoration-fixed` 35项／4失败含连带失败，已再次报告并将GPU交镜头负责人修正。小窗用真实点击先迁到另一空槽再回ground_04，增加中间状态断言，不能将未移动误作同槽取消。

## 最终冻结结果

装饰最终输出 `.local/verification/grid-regression/decoration-complete/`：**38项／0失败／退出0**。1280×720逻辑视口下八槽均经真实鼠标分派完成放置；地面第02槽预览与花盆确认、四挂点、旋转／取消／失焦、只读保存失败与重试、重开一致均通过。最小窗口先把陶罐由04移到03，再选择并确认04，实际结果均正确。

镜头所有者修复布置专用临时取景（yaw25／pitch34／distance31，目标点为默认点−Y1.8），主场景所有者接模式生命周期；本切片仅修测试。最终八槽几何可见、真实GUI点击不遮挡。首次修复中两槽被景物挡住的证据保留，不充当通过。

小窗验证曾因夹具坐标系失败：Control rect／Camera3D投影是逻辑视口坐标，而 `push_input` 默认再次按窗口转换。依据[Godot 4.7 Viewport.push_input](https://docs.godotengine.org/en/4.7/classes/class_viewport.html#class-viewport-method-push-input)及既有focus_detail夹具，鼠标事件明确传 `in_local_coords=true`，仍经过GUI／unhandled输入／真实世界射线，没有直接发信号或调用放置。最终日志实际 `DisplayServer.window_get_size=(960,600)`、逻辑 `(1280,720)`、缩放0.75；截图内容 **960×540**，不能称渲染960×600。

五项全场景回归与三项气氛最终均已取得通过结果，实际数字见上表与补充检查。气氛首次捕获失败仍保留边界说明。最后前景锚点微调发生在complete／focus／plant之后，后续气氛主场景截图已包含最终前景；布置复验采用最终专用镜头。没有用旧截图替代最终画面证据。原生小窗、昼夜及藤架代表图已亲看。

所有本代理验证窗口已退出，GPU已交根代理做本轮性能。当前尚未由本代理执行新候选构建／发行程序验证／新录屏，不提前宣称rc.3通过。状态、存档、十个测试、README、development-setup、project-context和本handoff至此冻结，未git add／commit；后续性能／候选／录屏事实由根代理更新共享文档。
