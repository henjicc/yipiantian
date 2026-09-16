# 工笔淡彩风格基准 v1

> 2026-09-17 用户确认：A 工笔淡彩全景 + A 淡彩青菜。此页是以后生成图片、制作模型及检查风格的入口；固定参考并降低漂移，不承诺随机生成逐次完全一致。

## 固定输入与用途

| 固定文件 | 负责什么 | 不从中推导什么 |
|---|---|---|
| [全景基准 v1](images/approved/farm-gongbi-v1.png) | 观察距离、空间层次、温暖江南氛围、建筑与环境的整体质感 | 不照搬全部作物、船桥、道具数量或生成 UI；它们不是新增功能 |
| [青菜基准 v1](images/approved/greens-gongbi-v1.png) | 圆润宽叶、短粗浅色叶柄、选择性细线、灰绿淡彩与哑光体积 | 不要求其他物件变绿；画中明暗不是可以直接贴到模型上的完整贴图 |

![已确认全景](images/approved/farm-gongbi-v1.png)

![已确认作物](images/approved/greens-gongbi-v1.png)

两张均从用户明确指出的原始输出逐字节复制，不裁切、不重新压缩。它们的 SHA-256、原始文件名与生成记录 ID 保存在 [生成记录](generation-record.json) 的 `approved_style`。原始提示词仍在 `images` 中的 `ink_A` 与 `crop_light_colour`，原样保留。`style-trials/` 中 B、C 和墨色青菜属于历史探索，不作为默认风格输入；此前 C + A 的建议已被本次选择取代。

## 看图时固定的判断

- 形体：圆润、宽大、连贯，保留真实三维体积与遮挡关系。叶片有厚度和弯曲，不能成为一张平面插画或融化的团块。
- 线条：局部用深苔绿、茶褐与墨灰细线交代边缘和交叠。线条可轻重变化，不给所有边缘加同样粗黑的描边。
- 颜色：植物灰绿、鼠尾草绿与淡青绿；墙面和叶柄暖米白；瓦墨灰，木和土为柔和赭褐。各材质保留本色，不把青菜颜色套到木头与陶器上。
- 表面：保留用户选中图里的淡彩层次、适量色斑及边缘积色。避免摄影级叶脉、毛孔、泥垢、密集木纹，也避免统一塑料高光。简化应按实际屏幕大小判断，不能把用户喜欢的笔触全部抹平。
- 空间与光：近处清楚、远处疏淡；全景有温暖光线，单体图用中性柔光。不要把夕阳、强投影或纸张黄化固定到所有资产表面。
- 内容：图片里的纸底、接触影、文字和 HUD 不作为模型的一部分。画意通过物体自身的线条和设色表达。

## 复用步骤

1. 先读本页并打开两张固定参考。新单体图默认按“青菜 v1、全景 v1”的顺序输入；新场景图按“全景 v1、青菜 v1”输入，提示词中的序号同步调整。
2. 使用下面固定风格段，再填写物件和画面要求。不必重复引入博物馆原画；已确认的生成图是当前风格参照，原画留作来源与研究。明确的结构图可作为第三张输入，注明只约束结构。
3. 按商业项目的 Tripo 优先分工，作物、道具和静态建筑先考虑整件或部件生成；精确田块、道路接缝和占位仍用 Blender / Godot。Tripo 输入需要清楚的单体图，不能把两张风格图当成同一物件的多视图。
4. 先完成一个代表性资产。检查风格、轮廓、部件连接、背景与裁切；有偏差时基于同一图只修改具体问题。不要连续拿新生成图作下一张唯一参考，造成逐步漂移。
5. 采用的新图保留实际完整提示词、输入顺序、输出路径、用途和检查结论；工具返回模型版本或种子时才记录，不编造。当前新模板尚未通过新一轮生成测试。
6. 图像符合方向后再做三维。三维资产在 Godot 全景、聚焦和小幅转动下复查材质、轮廓及昼夜可读性。生成图好看不代表三维实现已经达到。

固定 v1 不覆盖；只有用户明确改变整体方向时另建 v2 并更新此入口。一般资产变化只修改物件段，不重新选风格，不要求用户逐个批准叶片或道具。

## 可复用提示词

以下是依据获选图整理的**后续模板**，不是伪称已经执行的原始提示词。实际生成时将固定段与本次物件、视角段连接，并记录完整请求。

### 单体固定风格段（输入 1 青菜、输入 2 全景）

```text
Use case: stylized-concept.
Create one complete single-object concept for our 3D Jiangnan miniature farm game.
Input 1 is the APPROVED close-up style reference: match its rounded broad forms,
selective fine moss-green / tea-brown brush contours, layered pale colour washes,
controlled pigment variation and softly shaded matte volume.
Input 2 is the APPROVED world reference: match its warm, restrained Jiangnan
courtyard atmosphere and coherent natural materials. Transfer visual language,
not its buildings, crops, scene layout, UI or lighting baked onto the object.
Keep the specified object's own material colours and recognisable structure.
Use solid dimensional forms with a gongbi-inspired light-colour painted surface.
Preserve some broad pigment variation; do not polish it into plastic.
Avoid photographic microtextures, dense botanical veins, distressed surfaces,
glossy toy shading, heavy uniform black outlines, flat paper cutouts and ink holes.
No calligraphy, seal, watermark, text, frame or collage.
```

### 单体画面段

```text
Show exactly one complete object with a continuous readable silhouette,
in a weak-perspective three-quarter view, slightly above its centre.
Keep its base and every essential part inside the frame with a clear margin.
Use a plain neutral contrasting background, soft neutral diffuse lighting,
only a faint contact shadow, and sharp contours throughout.
No landscape, decorative pedestal, extra props, UI or depth of field.
Do not draw a checkerboard. Show occlusion honestly; do not invent a cutaway view.
```

### 首批物件段（一次选一个）

| 对象 | 放进提示词的物件段 |
|---|---|
| 成熟青菜 | `Object: one mature bok choy plant, a squat connected rosette with about five or six broad rounded cupped leaves, short thick pale stems gathered at one stable base. Keep the approved crop's shape language and painted surface. Not a spherical cabbage. No pot, soil clump, exposed trailing roots or detached leaves.` |
| 粗陶罐 | `Object: one squat unglazed earthenware jar with a broad rounded belly, thick open rim, two short attached loop handles and a stable flat base. Use muted warm grey-brown clay with restrained painted colour variation and fine selective contour accents. Keep rim and handle openings readable. No lid, plant, intricate ornament or glossy glaze.` |
| 江南民居 | `Object: one modest single-storey Jiangnan farmhouse, warm ivory walls, dark grey grouped roof tiles, simplified timber posts and a small front porch. Show the front and one side, consistent roof construction and a clear complete base. Match the approved world's proportions and warmth. No palace roof, European barn, furniture cluster, yard, tree or landscape base.` |

幼芽、幼株可以分别生成参考并交给 Tripo，也可由 Tripo 叶片在 Blender 中组合。阶段图共用同一成熟参考，明确改变阶段与叶片展开程度，再检查品种、根部、色彩和大小；独立生成并不天然保证关联，但离散阶段无需相同拓扑。整株与部件的选择见 [资产工作流](../asset-workflow.md)。

### 场景变体模板（输入 1 全景、输入 2 青菜）

```text
Use case: stylized-concept.
Create one full-bleed 16:9 view of our 3D Jiangnan miniature farm.
Input 1 is the APPROVED scene master: preserve its comfortable diagonal overview
distance, farm proportions, warm restrained colours and gongbi-inspired light-colour
surface treatment. Keep clear wall sides, plant volume and near/mid/far depth.
Input 2 is the APPROVED crop material and rounded shape reference.
Apply its selective fine contours, layered muted washes and matte volume where
appropriate, while retaining wood, ceramic, stone and plaster material identities.
Change only: [explicit change requested for this image].
Keep interactive fields legible. No new gameplay objects, labels or extra panels.
No photoreal microtexture, plastic gloss, blanket aged-paper filter, heavy ink
splashes, calligraphy, seals, collage or flat top-down map.
```

新场景图只辅助设计；真正的全景到聚焦必须在同一个三维场景里实现。若要无 UI 的纯美术图或特定工具状态，在本次画面要求中明示，不把全景中生成的文字当成 UI 设计资产。
