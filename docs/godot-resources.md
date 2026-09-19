# Godot 资料、技能与工具选择

> 核验日期：2026-09-17。面向本项目 Windows 三维微缩农场。引擎精确版本以根 [.godot-version](../.godot-version) 为准，环境入口见 [开发准备](development-setup.md)。

## 开发时怎样查证

遇到不确定的 API、参数、生命周期、格式、兼容性或错误处理，先确认版本与具体问题，再打开官方原文；官方信息不足时查 GitHub Issues、源码和社区复现。不要凭技能中的示例或搜索摘要直接认定行为。官方已说明与本机已实测要分别表达，最小验证也不能外推为整个功能通过。

优先使用英文检索，保留类名和原始错误信息，例如：

- `site:docs.godotengine.org/en/4.7 Resource duplicate resource_local_to_scene`
- `site:github.com/godotengine/godot "具体错误原文" Vulkan Windows`
- `site:forum.godotengine.org glTF reimport material override 4.7`
- `site:docs.blender.org glTF export animation Blender 5.2`

本页使用版本固定的英文文档；若页面失效，从版本首页搜索同一主题，不猜新的 URL。中文翻译可辅助阅读，遇到差异回到对应版本英文原文。结论有长期价值时更新现有规则或操作文档，不累积一次性搜索日志。具体约束见 [research.md](../rules/research.md)。

## 官方资料入口

| 需要解决的问题 | 入口 |
|---|---|
| 版本、下载与升级 | [下载归档](https://godotengine.org/download/archive/)、[4.7.2 发布与校验文件](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) |
| 类、方法与属性 | [4.7 英文文档](https://docs.godotengine.org/en/4.7/)、[类参考](https://docs.godotengine.org/en/4.7/classes/index.html)、[ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html) |
| GDScript 与代码组织 | [类型标注](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html)、[代码风格](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html)、[场景组织](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html) |
| 三维、相机和光照 | [3D 入门](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html)、[渲染器](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html)、[环境与后期](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html) |
| Blender / Tripo 模型进入游戏 | [支持格式](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)、[3D 导入专题](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html) |
| AI 操作、运行和导出 | [CLI](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html)、[Windows 导出](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_windows.html) |
| 场景文本、资源身份和 Git | [TSCN 格式](https://docs.godotengine.org/en/4.7/engine_details/file_formats/tscn.html)、[版本控制](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html)、[UID 变更说明](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) |
| 复现与范例 | [官方示例项目](https://github.com/godotengine/godot-demo-projects)、[引擎源码与问题](https://github.com/godotengine/godot)、[Godot 社区论坛](https://forum.godotengine.org/)；示例分支必须匹配引擎版本 |
| 发布许可 | [Godot MIT 许可及署名要求](https://godotengine.org/license/)；不要求游戏开源，发行时保留所需声明；美术、字体、音乐和插件分别核对许可 |
| Blender Python 与导出 | [5.2 Python API](https://docs.blender.org/api/5.2/)、[Blender 手册](https://docs.blender.org/manual/en/latest/)、[官方 Lab MCP](https://www.blender.org/lab/mcp-server/)；latest 页面先确认版本 |

## 光照能力核验 · 2026-09-19

本机仍为Godot 4.7.2官方版、Forward+／Vulkan。官方[4.7 beta说明](https://godotengine.org/article/dev-snapshot-godot-4-7-beta-1/)及[已合并PR 99119](https://github.com/godotengine/godot/pull/99119)确认加入RenderingDevice的Vulkan光追管线、加速结构与指令接口；这是底层能力，不代表当前农场已使用实时光追。项目使用实时阴影、SSAO、SSIL、辉光，以及可选高画质SDFGI；不能将SSIL或SDFGI命名为硬件光追。方案边界见官方[全局光照方案比较](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/introduction_to_global_illumination.html)，本项目视觉与开销记录见下方。

已接入三盏高挂路灯：`day_night.gd::_apply_lanterns`取消白天最低亮度，`living_details.gd::set_night_weight`统一控制门廊／路灯照明和纸灯笼发光，室内材质仍由`set_window_warmth`独立控制。标准画质保留三盏路灯投影，低画质关闭局部投影但保留照明，日间灯光不可见且能量为0。真实昼夜、通行及画质往返验证见`tests/night_lighting_test.gd`，来源与素材见[院落灯笼节点](../ArtSource/Environment/CourtyardLife/README.md#田边高挂灯笼--20260919-path-lanterns)。整体色调已完成中性高光／适度夜光与接触阴影调整，晨昏和季节连续性及十二菜混植实景通过，见同页色调节点。可选高画质SDFGI已接入，详见下节；未接入硬件光追。

### 高画质SDFGI与湖面边界

2026-09-19正式增加设置→画质→高画质，默认仍为标准。高画质保留标准的4×MSAA、景深、SSIL和路灯投影，增加SDFGI四级、最小格.12m、能量.50、反馈.20、遮蔽与天空采样。只让主屋、廊台、厨房、架子、主／东岸和石桥贡献静态遮蔽；`presentation/indirect_lighting.gd`初始化分类并监听本场景新增几何，作物、风动植物、动物、船、相机前景及可移动摆件仅接收间接光。新增作物／成长替换／摆件都不进入静态体素；院落布局重载会替换Environment，重新构建体素。[官方说明](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/using_sdfgi.html)确认SDFGI不支持动态遮蔽物，因此不能把这项效果当作动物或风动叶片的动态反射／遮蔽；原实时阴影仍工作。

前期小样能改善屋檐与菜地反射光，但原湖面出现环岛浅色亮带及水中物体边缘亮线。`.local/verification/lighting-20260919/gi-probe/`保留12张四时段／聚焦对照；`gi-water-probe/`证明仅令水面RADIANCE归零不能解决。`gi_debug.gd`及`gi-debug/`六张固定夜景进一步确认：关SSIL、关MSAA、关水下透射都不能消除，水面加`ambient_light_disabled`则消失但整体偏暗。

正式水面共用`quiet_water.gdshaderinc`：标准入口保持原计算；高画质入口仅关闭水面的环境／GI采样，加入随昼夜与季节变化的天空漫反射补光（线性环境色与天空顶色各半，再乘环境光能量）。原有水色、手绘天空反射、直接灯光、碎波、近岸透色、深度和雾气仍保留。这是美术近似，不是物理天空积分或光追倒影。切换保留同一材质及岸线／涟漪数据；船体遮罩在两档水面均持续跟随船姿，不能用旧的单一shader路径判断跳过更新。

[4.7.2渲染源码](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl)在custom_irradiance／custom_radiance混合之后才进行GI计算；因此写IRRADIANCE／RADIANCE不能当作关闭SDFGI的等价办法。`AMBIENT_LIGHT_DISABLED`明确包住GI区段，与本机消除亮圈的观察一致。另有[官方仓库水面深度／颜色采样问题113540](https://github.com/godotengine/godot/issues/113540)，报告4.5.1／4.6.dev5的相关透明水异常；它仅作为排查线索，尚未证明与本例同一根因。

验证入口`tests/high_quality_scene_test.gd -- --output=<本地目录>`：真实菜单点击与方向键选择、保存／重载、高→低→高→标准往返、昼夜与季节、作物生长和新增摆件、船遮罩跟随、场景替换均通过74项；截图与性能原始记录在`.local/verification/lighting-20260919/high-quality-4/`。`high-quality/`、`high-quality-2/`、`high-quality-3/`是菜单输入验证失败的中间证据，不能按文件名当成高画质实拍。既有灯光179项、设置存储36项通过，包含写入失败与重试。重现时不要在正式目录外另写平行材质配置。

本机RTX4090、1920×1080、6田96格（采样时95株十二菜混植），每档60个前台帧：白天标准／高画质视口GPU中位4.364／4.586ms，夜间5.093／5.785ms；渲染器报告显存增加约408／374MiB。不是完整GPU帧预算、长期帧率或低配承诺，首次开启的体素与shader准备成本未纳入稳定采样；4K高画质尚无新性能结论。

`water_motion.gd`及`water-motion/`补拍昼夜各六张靠近／转角过程，已检查中途帧和转角末帧，未再出现环岛大亮圈。首次保持高画质退出有12个ObjectDB／6个资源未释放告警；在间接光照控制器`_exit_tree`中断开新增节点监听并关闭SDFGI后，同一场景与镜头复测正常释放，见`water-motion-exit.log`。该verbose日志仍包含本机旧Vulkan覆盖层路径和RGB8转RGBA8提示，未改系统配置，不宣称整份日志零告警。

菜单验证经验：Godot 4.7.2的PopupMenu按键先由Window路径处理（见[官方源码](https://github.com/godotengine/godot/blob/4.7.2-stable/scene/gui/popup_menu.cpp)的`_input_from_window`），直接对PopupMenu调用`Viewport.push_input`不会完成条目选择。需使用带实际window_id的`Input.parse_input_event`，逐次检查聚焦条目后Enter，并核对实际设置与画面；它只向游戏投递事件，不操作系统键盘。最小复核见本地`menu_input_probe.gd`，完整回归已使用同一路径。

## 当前接入方式

采用 **Godot 原生 CLI + 文本场景 / 资源 + 项目技能**。CLI 已能完成导入、运行和 Windows 导出；不需要让游戏接入大模型 API，也不需要在游戏中放通用远程执行服务器。需要读画面、调试运行时对象或模拟输入时，再按具体任务选择引擎调试接口或经过核验的工具。

技能放在本仓库 `.agents/skills/`，随 Git 同步；它们补充流程知识，不是运行时依赖。两个已选技能使用官方 `skill-installer` 按下列提交安装，保留完整相对引用和 MIT 许可证。本次没有执行它们附带的资产检查脚本，也没有下载或运行其他候选框架。

| 已安装技能 | 作用 | 固定来源 |
|---|---|---|
| [godot](../.agents/skills/godot/SKILL.md) | 脚本、场景、Resource、生命周期、三维、持久化与 CLI 的按需知识入口 | [saschb2b/skills](https://github.com/saschb2b/skills/tree/007d499932facd683aae4775dc0d341dca91e53b/skills/engineering/godot)，提交 `007d499932facd683aae4775dc0d341dca91e53b`；[许可](../.agents/skills/godot/LICENSE) |
| [blender-3d-asset-generation](../.agents/skills/blender-3d-asset-generation/SKILL.md) | 轮廓、拓扑、UV、材质、资产预算、导出和交接检查，不绑定某个 MCP 实现 | [源仓库](https://github.com/lovecatisgood-sudo/3d-asset-generation-blender-unity-game-development-skills/tree/00221bb0a8ffcb8eb577daf5ddf9e8d8edcdbc98/skills/blender-3d-asset-generation)，提交 `00221bb0a8ffcb8eb577daf5ddf9e8d8edcdbc98`；[许可](../.agents/skills/blender-3d-asset-generation/LICENSE) |

采用限制：

- Godot 技能自述为 2026-06-19 的知识快照，包含 AI 生成内容；本次审阅入口及 CLI / 文件格式参考，没有逐条验证整套游戏系统。示例中的 Autoload、事件总线、测试框架和目录结构不是本项目强制架构，实际以项目规则为准。
- Godot 技能的 `MAINTENANCE.md` 中 `scripts/check-*.mjs` 是上游仓库的维护命令，这里没有引入该仓库的维护设施，不能在本项目直接照抄执行。
- Blender 技能的审计脚本已静态审阅，尚未在 Blender 5.2 跑过。其三角形统计取基础网格，不能当成修改器求值后或 Godot 最终导入网格的预算；`passed` 也不代表动画、材质与视觉通过。使用时按实际资产风险选择检查，开放叶片等有意非流形几何不能机械判为失败。
- 保持已配置的 Blender 官方 Lab MCP；技能不要求换成另一套桥接。当前不默认安装插件、升级软件、付费生成或加入联网玩法。
- 后续技能升级先审查差异和引用完整性，核对许可与实际收益，再更新固定提交；不自动跟随 `main` / `latest`。上游知识错误应纠正对应本地副本并记录改动，不能带着已知错误使用。

## 对 godot-fun/godot-agent 的判断

已查看 [仓库](https://github.com/godot-fun/godot-agent)、README、`project.godot`、框架入口与音频技能样例；审阅提交为 `78b890119a020ba160196239ea2c396b9939db5f`（2026-09-16），MIT。结论：**暂不整套接入；媒体处理技能按实际需求参考。**

- 它包含媒体处理技能和 `zfoo` 通用游戏框架；技能多用于音频、图片、视频和分镜处理，名称不能理解为“Godot 官方 AI 控制器”。
- 框架需要注册 Autoload，包含网络、热更新、AI 聊天、日志、音频和调度等能力。源码入口会初始化音频、日志、计时器并逐帧更新组件，属于实际运行时依赖；当前空白农场没有这些整体需求。
- 上游工程配置为 Godot 4.6 / Compatibility，与本工程 4.7 / Forward+ 不同；没有对整个框架做兼容性测试，不宣称不兼容，也不直接套用。
- 媒体技能可能依赖 `.ai/` 脚本及专门依赖目录，不能只拷贝一个 `SKILL.md` 就说接入完成。有具体音频或图片处理任务时，再评估那一项是否比现有工具更合适。
- 不复制它的根 AGENTS.md，不为采用其中一个工具带入整套框架。今后若复用代码或脚本，固定来源、保留许可证并核验真实效果。

## 其他检索结果与后续使用时机

| 候选 | 当前判断 |
|---|---|
| [wshobson/agents 的 godot-gdscript-patterns](https://github.com/wshobson/agents/tree/main/plugins/game-development/skills/godot-gdscript-patterns) | 已读技能入口；可参考游戏系统模式，但与已装 Godot 技能重叠，示例偏二维，不再重复安装 |
| [RobLe3/cc-blender-skill](https://github.com/RobLe3/cc-blender-skill) | 覆盖建模、材质、灯光、镜头等专门流程；README 与技能指定另一套 Blender MCP，不能当作本机官方 Lab MCP 的现成接口。保留为按主题阅读的候选，不整体替换工具 |
| [aigengame/godot-agent](https://github.com/aigengame/godot-agent) | 与用户提供的同名仓库是不同项目；提供 gda CLI / 技能 / MCP 和运行时控制。后续确需原生 CLI 不覆盖的观测或输入能力时再审计，当前未安装、未验证 |
| [GUT](https://github.com/bitwes/Gut)、[GdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) | 是测试框架，不是 AI 技能。出现实际玩法回归需求时比较适配成本，当前不同时安装两套 |
| [官方示例项目](https://github.com/godotengine/godot-demo-projects) | 对相机、输入、三维和导入问题优先找对应示例。按需读取或在 `.local/` 复现，不把整套示例放进正式工程 |

游戏设计、农场时间语义与产品范围继续由现有 rules 管理。宽泛的“游戏工作室”技能或一次性安装大量角色技能没有当前收益，先不增加；后续有具体缺口再定向检索。
