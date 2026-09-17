# 光影、材质与资产交接

本轮按用户提供的院落参考图实施；根代理负责此切片。这里记录实现与已取得证据，整合、性能和候选发行结果另见整体验证交接。

## 实现

- `day_night.gd`：环境光由单色改为天空方向光，冷天空、暗地面帮助区分植物背面与屋檐；SSAO 收紧接触范围，低强度 SSIL 补局部反射光。低画质由 `focus_detail` 关闭 SSIL。
- 对比同相机、16:30 的 Filmic、Linear、AgX 实图后选 Linear／曝光 1。原 Filmic 抬亮远山，AgX 本次参数使整体偏灰；没有为使用新技术而直接采用。日间主光减轻黄色偏色，仍保留傍晚暖光、夜间冷光与窗内暖灯。
- 方向光阴影图 8192、高档软阴影采样；缩小阴影偏移和太阳角直径，减少植株底部悬浮感。标准 MSAA 4×、低档 2×，没有叠加会模糊风动叶片的时域抗锯齿。
- 默认独立窗口提高为 1600×900，保留 1280×720 界面设计基准、960×600 最小窗口与正常缩放；全屏仍使用显示器实际尺寸。
- `pigment.gdshader`：石材增加低幅矿物色层、湿色与苔痕；地面使用更宽的色块变化，仍保留原材质身份。`plant_wind.gdshader` 对绿叶色域微调，白萝卜根肩、花与葫芦不统一染绿；原纹理、根部锁定和微风不变。
- 远景减少白色云层遮盖，保留山村固定投影与独立云动，适度恢复山体色彩对比。
- Blender 石桥加厚开放拱圈、错缝桥台、两层石栏板和压顶；五种岸石收窄错位石顶、保留大切面，修正纵向放大后的圆桶感。摆放位置和农田碰撞不变。

## 资产与验证

制作源为 `ArtSource/Environment/build_modules.py` 和 `Modules/courtyard_modules.blend`；正式 GLB 为 `Game/art/environment/modules/stone_bridge.glb`、`stone_0`～`stone_4`。选择性重出入口 `--only` 保留无关导出物，完整源场景仍可重建。

- Blender 5.2.2 LTS 实际生成并在干净场景逐个重新导入，三角数一致。新桥 15800 三角、5 材质；岸石 184～216 三角／个、1 材质／个。
- 技能审计结果：这六个资源均无非流形边、游离点，缩放为 1。原岛岸底部开放边和侧屋原开放结构是未改历史资产，不表述为全场全封闭拓扑。
- Godot 4.7.2 正式导入通过；主场景实图已检查桥洞、石栏和岸石。生活摆件／船体运动测试 22 项全部通过。
- 实图对照位于 `.local/verification/camera-reconstruction/tones/`、`main-final-pilot/`；Blender 审计与原桥工作备份位于 `.local/verification/bridge-rework/`。这些是隔离证据，不是正式运行依赖。

## 官方核验与限制

核验依据：[4.7 环境与后处理](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html)、[Environment 属性](https://docs.godotengine.org/en/4.7/classes/class_environment.html)、[抗锯齿说明](https://docs.godotengine.org/en/4.7/tutorials/3d/3d_antialiasing.html)。天空光提供方向差异；屏幕空间间接光只覆盖当前可见几何，不能代替完整离线全局光照。没有把渲染调整宣称为与参考图逐像素一致，也没有改变真实 UTC 生长规则。
