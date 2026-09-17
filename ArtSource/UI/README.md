# 首个版本界面资源

## 当前字体：汇文明朝体

- 用户于 2026-09-17 指定替换所有游戏字体；正式资源为 `Game/art/ui/fonts/汇文明朝体.ttf`，保留中文名与完整原始字节，大小 24,426,256 字节。
- 具体来源、内部版本与 SHA-256 见 [随包来源记录](../../Game/art/ui/fonts/字体来源.txt)。字体映射包含 14,051 个 Unicode 字符，当前 GDScript 字符串中的非 ASCII 文案均覆盖。
- 项目全局默认、HUD／设置共享主题和作物样片 Label3D 使用同一内置字体；无需系统安装。中文路径经 Godot 导入与实景检查。
- 原 Noto 字体与 OFL 移到本目录 `历史字体/` 保留，不进入游戏包；以下记录只描述旧版。
- 4.7.2 实测：HUD、设置与来源页无缺字／溢出；逐节点确认普通字体及 RichTextLabel 五种字形均解析到 Huiwen-mincho。导出 PCK 后独立加载内置字体成功，字体数据 24,426,256 字节。证据位于 `.local/verification/font-swap/`，截图另存中文制作留档；未重跑玩法、存档或性能回归。
- 全局字体配置依据 [Godot 4.7 ProjectSettings](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-gui-theme-custom-font)，运行加载与打包结果以上述实测为准。

## 历史字体：Noto

- 正式文件：`ArtSource/UI/历史字体/NotoSerifCJKsc-Regular.otf`，原始字体未修改。
- 官方文件：https://raw.githubusercontent.com/notofonts/noto-cjk/main/Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf
- 官方仓库：https://github.com/notofonts/noto-cjk
- 版本由字体内部 name 表核对：Noto Serif CJK SC Regular，Version 2.003；© 2017–2024 Adobe。
- 文件大小 24,543,080 字节；SHA-256 `2a2eae2628df83556c54018c41e20fa532c1b862c5256ae8b3f23feb918d12ca`。
- 字体对应的 SIL Open Font License 1.1 原文保存在 `ArtSource/UI/历史字体/OFL.txt`，来自官方仓库 `Serif/LICENSE`。包中保留字体和许可。字体不是从 Windows 系统目录复制。
- 本地 FontTools 读取成功，含 44,777 个 Unicode 映射，当前界面文案字符全部覆盖；4.1 实景及普通 Windows 发行程序已检查中文排版与 960×600 至 4K / 150% DPI 的控件可读性。

## 游戏图标

- 正式文件：`Game/art/ui/game-icon.png`，1254×1254，RGBA，有真实透明通道。
- 来源：内置 imagegen，一次生成；以项目已确认的 `docs/design-baseline/images/approved/greens-gongbi-v1.png` 为造型与淡彩风格参考。
- 生成返回文件：`exec-6a5ab74e-b5fb-48fd-a7dd-0dd16d2fef42.png`。未调用 Tripo，未后期改画；复制原 PNG 进入正式工程。
- 提示词要求 1024 方图，实际工具返回 1254 方图，以真实产物为准。工具未返回费用数据，不能记为免费或虚构金额。
- 程序窗口与发行图标由 Godot 使用该原件生成所需尺寸；4.1 已导出并在普通发行窗口验证。
- 初看大尺寸透明预览有红黄碎边；针对性 imagegen 清边一次得到 `exec-344f79bd-8ead-409c-8041-e2354c213256.png`，未采用：它没有改善该预览现象。原图像素统计表明彩边 alpha 最高仅 4/255，多数为 1/255，没有 alpha 大于 10 的红黄边。随后用 Godot 在浅纸、深绿、灰底按 32 / 48 / 128 像素真实显示，未见红黄碎边，保留原件；证据见 `制作留档/03_处理与验证/07_成品界面/00-assets.png`。

### 清边候选实际提示词

Edit this exact application icon, preserving the bok choy painting, cream rounded square tile, fine brown border, composition, scale, and all interior colors unchanged. CLEANUP ONLY: remove every stray yellow, red, magenta or bright colored fringe/pixel/fleck outside the rounded tile, including yellow fragments along the left edge and red fragments below the bottom edge and tiny detached specks in the upper transparent area. Everything outside the smooth warm-brown rounded-square silhouette must be truly fully transparent alpha, completely clean, with smooth antialiasing only in the original brown edge color. No colored matte or glow. Do not repaint the vegetable, do not change proportions, do not add any objects or text. Output single transparent PNG.

### 实际提示词

Create a single polished Windows indie farming game application icon for 我有一片田, using the attached approved greens painting strictly as the subject/style reference. Square 1024x1024 PNG with genuine transparent outside background. A softly rounded cream paper tile fills 88% of the square, subtle warm brown thin edge and very restrained dimensional shadow INSIDE the tile, containing ONE plump simplified bok choy plant with 5 broad rounded sage/jade leaves and ivory stems, gently painted gongbi淡彩 watercolor texture matching reference. Front three-quarter view, clear broad silhouette readable at 32x32, leafy top and ivory bulb bottom separated cleanly. Crop large enough occupying 78% of tile height, no fine veins, no soil, no extra scenery, no letters, no text, no badge, no photographic gloss. Calm Jiangnan garden palette, crafted illustrated game art rather than flat corporate vector. Preserve centered simple distinct crop identity; no full UI screenshot.

## 界面贡献

Godot 的字体、布局、控件、边框与实际状态由程序绘制。图标生成不等于完整游戏界面生成，也未用一张概念图覆盖交互场景。`farm_theme.gd` 仅为本游戏 HUD 与设置共享纸色、描边和中文字体，不建立通用组件库。农场和装饰数字读取权威玩法状态；时钟读取系统本地时间。

播种、浇水、收获、篮子、太阳和月亮六枚小图标由项目直接编写 SVG 曲线，使用棕色细描边、淡彩填色与少量渐变，不冒称图像模型生成。它们只承托真实按钮和状态，不承载按钮文字。
