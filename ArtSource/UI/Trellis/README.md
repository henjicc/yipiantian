# 丝瓜图标与程序藤蔓 · 2026-09-20

第11项菜架种植使用一张丝瓜图标和随架子尺寸生成的藤蔓。Tripo 付费模型生成继续暂停；本次没有调用 Tripo，也没有 Blender 后处理。

## 图标来源

- 工具：内置 `image_gen.imagegen`；工具未回显精确模型版本与费用，不推断。
- 原图：`luffa-generated.png`；运行资源：`Game/art/ui/crops/luffa.png`，与原图相同，没有二次像素编辑。
- 用途：菜架播种选择、持种子光标、菜篮库存；不是三维纹理。
- 原始输出：`%USERPROFILE%/.codex/generated_images/01a0b678-f598-7d00-915f-051f5aa8efc6/exec-172547c0-5ae8-4739-923b-f21d474049cd.png`，仓库内保留源图供复现和追溯。

实际生成提示词：

> Create one game inventory icon of two fresh luffa gourds (丝瓜), slender gently curved tapered green ridged fruit with a short stem and one small lobed vine leaf. Jiangnan Chinese gongbi fine ink contours with restrained pale watercolor washes; muted sage and moss green with organized delicate longitudinal rib lines, warm natural tiny highlights, no glossy plastic or thick cartoon outline. Clean centered isolated composition, slight diagonal, whole fruits fully visible with generous transparent padding, recognizable at 48px. Genuinely transparent alpha background. No text, no label, no border, no ground, no basket, no shadow backdrop. Square 1024x1024 PNG, matching a quiet traditional Chinese miniature farming game UI.

## 三维来源与重建

- `Game/presentation/trellis_vine.gd` 为可编辑程序源；茎、五裂叶、叶脉、吊绳、带纵棱果实均由代码生成，复用 `pigment.gdshader` 的工笔淡彩材质。
- 幼苗、攀爬、成熟三个状态由真实生长状态选择；尺寸只改变空间结构，不决定生长进度或收获。没有把成熟果实数量当作收获篮数。
- `Game/layout/trellis_slots.gd` 定义稳定根部身份，`trellis_crops.gd` 负责显示与点选；作物数据在 `FarmState`。
- 几何随当前菜架长宽高重建，不生成额外 GLB，不额外制作人工 LOD 或风动。精细藤蔓美术仍待后续资产阶段。
- 验证入口：`tests/trellis_planting_state_test.gd` 与 `tests/trellis_planting_test.gd`；实景验收结果以项目上下文中的最终批次为准。本节点可以从程序源补拍，没有录制视频。

最终实景批次 `.local/verification/trellis-planting-1789835286/`，31项操作检查通过，已查看成熟藤蔓两侧近景、原地保存后与重开夜景。根部与提示面按菜架土床的同一高度剖面贴地；聚焦时局部提示增强后的夜景补查在 `trellis-planting-1789835467/`，2项操作通过并查看小窗口图。当前模型用于实际玩法验证，不宣称已完成精细藤蔓美术或用户主观验收。
