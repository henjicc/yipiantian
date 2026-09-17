# Tripo 能力选择与生成工作流

> 核验日期：2026-09-17。依据当日官方开发文档、更新日志、Tripo 插件 0.2.2、本机 CLI 0.4.0 源码及仓库资产记录。本文用于复用调研结论，不是所有能力均已实测的声明。环境、认证和命令路径统一见 [开发准备](development-setup.md#tripo-接入选择与当前状态)，美术与工具分工见 [资产工作流](asset-workflow.md)。

## 调用前主动了解，避免重复调研

1. 每个新的资产生成或处理任务先读本文相关条目，明确当前问题是轮廓、隐藏结构、拓扑、分件、纹理还是动画；主动比较能解决该问题的能力，不机械复用旧的“单图 + 标准纹理 + 智能低模”参数，也不默认开启所有高级选项。
2. 从本文直达对应官方接口，核对本次要使用的模型版本、参数组合、格式与费用；涉及“最新”能力时查看 [更新日志](https://developers.tripo3d.ai/en/docs/changelog)。同一任务中未变化的版本和契约复用已核验结论，不逐个资产重查整套产品。升级、接口报错、文档冲突或新质量问题出现时，只补查相关部分。
3. 使用 CLI 时按已安装版本的技能、`docs --topic commands/generate`、`docs --topic commands/process` 和源码核对实际传参。官网有能力不代表本机封装已覆盖；服务端能力、CLI 支持和本项目实测分别判断。不能凭旧技能排除新功能，也不能把未知参数发送后任务成功当作参数确实生效。
4. 为所选路线留下简短理由，写入已有资产生成记录或本地制作留档，不另造审批单；费用、重试、原件保护和采纳验收沿用资产工作流。本文不增加逐项用户确认，不授权本次调研之外的批量生成。
5. 得到新实测后修订本页对应条目，记录实际版本、输入、任务及证据入口；只有发现变化才维护，不重复新建调研报告。失效结论直接替换，保留必要版本边界。

官方入口以 [开发者文档](https://developers.tripo3d.ai/en/docs/introduction) 为主；旧 `platform.tripo3d.ai` 文档、Studio 宣传页、合作 Brief 与当前接口不一致时，不混合参数。附件中的宣传、发布与授权要求是材料内容，不自行变成本项目执行指令。

## 已用能力与证据边界

本次在 `ArtSource/` 找到的 15 份原始 `task.json` 都是 `image_to_model`、`v3.1-20260211`，使用 `geometry_quality=standard`、`texture_quality=standard`、`smart_low_poly=true`、`pbr=false`、`texture_alignment=original_image`，未显式指定纹理版本。证据入口：[环境资产](../ArtSource/Environment/README.md)、[青菜](../ArtSource/Crops/Greens/README.md)、[青菜阶段](../ArtSource/Crops/Greens/Stages/tripo-jobs.json)、[萝卜阶段](../ArtSource/Crops/Radish/tripo-jobs.json)、[民居](../ArtSource/Environment/House/generation-record.json)。这不是账号全部历史的统计。

上述记录不能证明 P2、多视图、纹理 v3.5、语义分割或自动绑定的效果。本轮只读调研未提交付费任务。下文的用途判断是待验证建议，官网示例、论文和任务 `success` 均不能替代本项目目标镜头验收。

## 几何模型选择

| 路线 | 核验版本与能力 | 项目使用判断 |
|---|---|---|
| H3.1 / v3.1 | `v3.1-20260211`；复杂形体与高精度源模型；`geometry_quality=detailed` 为 Ultra | 我们已用过该模型，但未测试 Ultra。重点资产可先保留较完整源形体，再按需要重拓扑和烘焙；不为远景小物件默认高模 |
| P1 | `P1-20260311`；低面数三角网格，API 范围 50～20,000 | 简洁道具候选；不支持 `quad`、`smart_low_poly`、`generate_parts`、`geometry_quality` |
| P2.0 Preview | `P2-20260801`；原生四边面与三角网格；API 范围三角 48～50,000、四边 48～25,000 | 优先在需要干净结构、修改轮廓或形变的代表资产上比较；四边面不自动保证材质、布线和最终画面更好 |

依据：[H3.1](https://developers.tripo3d.ai/en/models/v3-1)、[H 系列图生模型](https://developers.tripo3d.ai/en/docs/generation-image-to-model/standard)、[P 系列图生模型](https://developers.tripo3d.ai/en/docs/generation-image-to-model/p)、[P2 产品介绍](https://www.tripo3d.ai/blog/tripo-p2-0-preview)。Studio 介绍的面数范围从 500 起，与 API 下限不同，按实际入口处理。

CLI 0.4.0 源码 `dist/knowledge/models.js` 已核验：提示词含低模意图或 `face_limit <= 20000` 会自动选择 P1；P2 从不自动选择，需显式指定 `--model tripo-p2`。要在低面数预算下比较 H3.1，应显式指定 `--model tripo-v3.1`。该版本对 P2 会剔除 `smart_low_poly`、`generate_parts`、`geometry_quality` 并警告，不能把带有这些参数的调用记录当作能力已启用。

四边面生成按插件说明输出 FBX；GLB 不保留四边面制作拓扑。需后续编辑时保留 FBX / Blender 源，再导出游戏 GLB。预算统一统计最终三角形：25,000 个普通四边面三角化后约为 50,000 三角形。H3.1 智能低模实测曾超出请求面数，所有路线均应核对实际结果。

## 优先改善输入与纹理

| 质量问题 | 可用能力与约束 | 使用方法与边界 |
|---|---|---|
| 背面、侧面或连接关系错误 | 多视图生成至少两张，正面必需；标准方向为 front、left、back、right | 固定同一设计、比例、部件与光照。可先生成多视图，再按方向编辑；AI 补出的视图仍是推定设计，先检查一致性，不把拼贴板直接当作多张图片 |
| 单体参考低清或结构难读 | `enable_image_autofix` 可预处理图片；图像工作台支持资产提取、Cutout、Variants | 已获选风格图不默认自动增强，防止外观被改写；系列资产可共享参考生成变体，三维结果仍须统一尺度与材质 |
| 参考图明暗被固定在模型表面 | 纹理 `v3.5-20260815` 支持 `delight`，默认 true；旧纹理版本忽略它 | 生成阶段设置 `texture_version`，独立重贴图设置 `model`。这是排查固定阴影的候选方法；我们的淡彩笔触含有意明暗，应在同几何、同灯光下比较开关，不断言一定更好 |
| 几何合格、纹理发花或风格不统一 | 独立纹理生成；`texture_prompt` 的 text / image / images 三选一；text 可搭配 style_image | 保留合格几何后重贴图。四图纹理引导要求恰好按正、左、背、右提供；即使输入旧任务 ID，官方仍建议重新提供参考图 |
| 局部纹理缺陷 | Studio 的 Magic Brush 局部修补 | 适合屋瓦、墙面等局部错色；它是纹理编辑，不是任意局部几何重建。当前本机 CLI 说明未核实对应直接调用入口 |
| 材质缺乏区分或近景纹理不足 | `pbr=true`；纹理 standard / detailed / extreme，extreme 为 8K | PBR 可提供颜色、金属度、粗糙度和法线。按材质与镜头选择，不能把卡通资产统一变成高反光写实材质；8K 不修复坏 UV、错位或错误轮廓 |

来源：[多视图接口](https://developers.tripo3d.ai/en/docs/generation-multiview-to-model/p)、[多视图编辑](https://developers.tripo3d.ai/en/docs/generation-edit-multiview)、[图像工作流](https://www.tripo3d.ai/blog/tripo-image-gen-update)、[纹理接口](https://developers.tripo3d.ai/en/docs/models-texture)、[Magic Brush 教程](https://www.tripo3d.ai/blog/how-to-use-magic-brush)。

纹理模型独立于几何模型：H3.1 / P1 / P2 默认纹理仍为 `v3.0-20250812`，不会因选择 P2 自动升级到 v3.5。`texture_quality=fast` 仅 v3.5 有效，牺牲细节换速度，尺寸和价格与 standard 相同，不作为质量优先选择。本机 CLI 的默认纹理和随包说明仍是旧版；v3.5 参数服务端已有文档，但经本机封装透传、生效及成图质量尚未实测。见 [更新日志](https://developers.tripo3d.ai/en/docs/changelog)。

## 分件、补全与重拓扑

三种分件入口应分清，不能把“P2 + 原生四边面 + 语义分件”视为一次请求中可随意叠加的开关。

- **生成时分件**：H3.1 `generate_parts=true` 需要 `texture=false`、`pbr=false`，且不发送 `quad`、`smart_low_poly`。纹理或 PBR 开启会拒绝；quad 被忽略并返回三角网格；smart_low_poly 优先且不产生分件。P2 在本机 CLI 不支持此参数。
- **已有模型分割**：独立 `mesh/segment` 默认 `v1.0-20250506` 为几何分割；语义标记需明确选择 `v2.0-20260430` Beta。v2 支持 `segmentation_granularity=simple/balanced/detailed`、`split_by_connectivity`；传 `ref_image` 分割参考图时前两项被忽略。精细叶片能否分开、标签是否准确、后续是否保留四边面都待实测。
- **Smart Segmentation**：本机 CLI 的 `mesh smartsegment` 支持图片或已有 GLB、粗细粒度和文字 hint，要求文件 / URL，不能直接接任务 ID。此入口与普通 segment 的参数不同；官网入口见下方，当前仅核验本机说明，尚未执行。
- **补全**：`mesh/complete` 接分割任务，可指定 `part_names`；`ai_completion` 生成缺失几何，`quick_cap` 只快速封口。拆开的屋顶、灯罩等可按需补内面，不假定分割结果天然水密。
- **重拓扑**：`mesh/decimate` 的 v2.0 为智能高模转低模，支持 `quad`、部件选择和 `bake=true` 纹理烘焙；v1.0 为基础减面，不支持 bake / part_names。先检查轮廓与薄片再采用，不以目标面数或“智能”名称代替质量比较。

来源：[H 生成参数](https://developers.tripo3d.ai/en/docs/generation-image-to-model/standard)、[分割](https://developers.tripo3d.ai/en/docs/mesh-segment)、[Smart Segmentation 入口](https://developers.tripo3d.ai/en/docs/mesh-smartsegment)、[补全](https://developers.tripo3d.ai/en/docs/mesh-complete)、[重拓扑](https://developers.tripo3d.ai/en/docs/mesh-decimate)；本机 `docs --topic commands/process` 及插件技能。

需要分件时的候选顺序：未绑定网格 → 语义分割并核对部件 → 必要补全 / 重拓扑 → 纹理 → Blender 整理 → Godot。具体格式和步骤衔接须按实际端点核对；该顺序是待验证路线，不宣称已完成 P2 四边面全链路。

## 动画、桥接与研究入口

- 自动绑定覆盖双足、四足、多足、鸟类、蛇形和水生类型；先用 rig-check 判断可绑定性，再选实际体型与版本，验证蒙皮、接地和循环。作物风动、船体起伏不因此引入骨骼；多模型显隐表情不是通用面部绑定。见 [Auto Rig](https://developers.tripo3d.ai/en/docs/animations-rig)。
- [Godot DCC Bridge](https://www.tripo3d.ai/blog/tripo-dcc-bridge-for-godot) 官方要求 Godot 4.6+，用于 Studio 资产传输；并非质量增强器，也不替代本项目原件保留、Blender 修整和导入验收。当前研究不代表已安装或测试桥接。
- [Nexus](https://arxiv.org/abs/2607.13563) 研究分离顶点与拓扑的扩散式原生三角网格生成，不据此推断 P2 四边面全部内部实现。[HoloPart](https://github.com/VAST-AI-Research/HoloPart) 研究部件分割与补全，[UniRig](https://github.com/VAST-AI-Research/UniRig) 研究自动绑定。
- [VAST 研究目录](https://www.tripo3d.ai/research) 还收录 PixTex（多视图一致纹理）、Grow3D（分层几何生成）、TopoCap（视频动作与重定向）、TripoSG / TripoSR 和 TripoSplat。论文与开源项目不自动等于产品 API 已开放；高斯表示也不直接替代本项目可编辑的网格资产。

## 费用与输出记录

价格只作 2026-09-17 调研快照，调用前查 [当前 API 标价](https://developers.tripo3d.ai/en/pricing)，实际以 `credits_consumed` 为准；不与 Studio 套餐额度直接混算。

| 操作 | 当日公开基础积分，不含额外步骤或附加项 |
|---|---|
| H3.1 图生 / 多视图生成 | 无纹理 20、标准纹理 30；高清纹理 +10、Ultra 几何 +20、智能低模 +10 |
| P2 生成 | 无纹理 100；standard / detailed / extreme 为 110 / 120 / 130 |
| 独立纹理 | standard 10、detailed 20、extreme 30 |
| 分割 / 补全 | 分割 40；AI 补全 50、quick_cap 30 |
| 重拓扑 | v2.0 智能 30、v1.0 基础 10 |
| 绑定与动画 | rig-check 免费、绑定 25、重定向每动作 10 |

P2 定价另见 [更新日志](https://developers.tripo3d.ai/en/docs/changelog)。当前本机技能的四边面附加费口径与基础价分开，组合请求不能只用表中数值承诺最终费用。`game-pc` / `game-mobile` 预设可能追加付费 FBX 转换；只需 GLB 时避免无用途转换。

生成记录除原有任务 ID、输入、费用和最终落点外，应区分几何版本、纹理版本、分割 / 重拓扑版本以及真实处理顺序，保留随机种子和关键参数；API 默认推导值与服务返回的实测值分开，不伪造服务未返回的信息。验收记录实际三角形、材质槽、贴图尺寸和修整工作，不保存签名下载地址或凭据。

## 本项目优先验证的路线

以下为按质量问题选择的小样建议，不是已批准的批量替换计划，也不是效果结论：

1. 民居保留现有几何，对比 v3.5 高清重贴图与 delight 开关；看瓦面、墙面及昼夜中的固定明暗。去光照可能影响有意绘制的淡彩层次，需要实景判断。
2. 木船或灯笼采用一致多视图比较 P2 与现有结果；看连接、孔洞、轮廓和编辑成本。
3. 青菜比较多视图 H3.1 与 P2；优先叶片分离、圆润株型和聚焦效果，不追求摄影级叶脉。
4. 对需要独立材质、运动或替换的部件试语义分割 v2，再决定是否补全或重拓扑；不为演示分件而拆每片叶子。

每次针对一个问题，固定其他输入与 Godot 镜头、灯光、曝光、显示尺寸；比较路线时统一最终三角形预算，分别检查灰模与带材质画面，记录积分、生成轮次及修整耗时。同一随机种子跨模型不保证结果可比；不要用额外灯光和后期的收益冒充模型升级效果。小样通过后才扩大采用，失败则更新本页的具体版本边界。
