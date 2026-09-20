# E + F 淡彩 UI 材料

用户选择：F 的淡彩叠染为主，E 的细边和规整结构为辅。不是把一整张概念图拉伸进界面。

## 生产与复用

- `pigment-source.png`：内置图片生成工具生成的原始淡彩色层。实际原件有透明外缘，因此只取不透明中心，不把生成轮廓用于按钮。
- `icons-source.png`：同批参考作物画风的竹篮、日、月透明图标。只切分和等比归一，不将图标烘焙进按钮。
- 完整提示词、生成文件名及工序见 [generation.json](generation.json)。工具未返回费用。
- `build_materials.py` 从 `Game/ui/ui_tokens.gd` 读取语义颜色。运行 `python ArtSource/UI/Pigment/build_materials.py` 重建 `Game/art/ui/pigment/`；依赖 Pillow、NumPy。
- 肌理转灰度后用 token 调色，中心取样双轴镜像；像素断言确认对边完全一致。256 px 九宫格，固定 20 px 四角，216 px 中段原尺寸重复；8 倍超采样精确圆角和细边。尺寸变化不拉伸边框，也不要求为每个宽高重新生成图片。
- 大面板低对比浅纸；普通、悬停、按下、禁用四种按钮色层；选中增加赭色底线。键盘焦点用独立透明描边，不能用不透明 focus 底板覆盖选中状态。
- 24 px 哑光滑块单独导出。图标保持透明，去除 alpha 低于 8/255 的导出浮尘，等比装入 128 px 标准画布；不按颜色抠图。

## 程序入口与规范

- `Game/ui/ui_tokens.gd`：墨、纸、边、叶、淡彩状态、赭色提示以及内边距／间距／图标槽／切片宽度的单一入口。素材颜色修改后须运行构建脚本再导入。
- `Game/ui/farm_theme.gd`：共享 Theme，按钮、选项、面板、滑条复用；字体继续使用汇文明朝体。正文和选中项都用深墨，不照搬概念图的低对比白字。
- `Game/ui/status_badge.gd`：菜篮和时间共用 Button + MarginContainer + HBoxContainer + 图标槽 + VBoxContainer。图标保持宽高比；文字块与图标槽垂直居中；子节点不截获点击，完整底板负责命中。标签变长会更新组件最小尺寸。
- `Game/ui/item_card.gd`：已有上图下字组件继续复用主题。圆环保留已确认的方案 A 结构／浅赭木料，仅文字、纸色与反馈引用共享 token，不另做一套圆角九宫格。
- 普通控件不要覆写独立色号或手摆图标文字；特殊形状只负责自己的几何，仍消费 token。父布局管理组件位置，组件管理自己的内边距。

## 验证入口

`tests/game_menu_test.gd -- --visual`：四种窗口尺寸、面板包含关系、焦点、设置交互及真实渲染。

`tests/debug_time_preview_test.gd -- --dev-preview`：960×600／3840×2160 下 HUD 包含关系、图标文字对齐与等比模式、真实点击时间控件、日夜切换和截图。每次使用新测试存档目录，避免旧格式干扰视觉测试。

`tests/field_menu_scene_test.gd`：九宫格平铺、同心环及真实选菜行为。

`tests/harvest_book_test.gd -- --visual`：真实菜篮入口与共享主题面板。
