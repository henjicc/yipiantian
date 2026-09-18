# 农场声音源

## 时令环境层 · 20260918

`compose_season_audio.py` 复用本目录原始合成／导出函数，分别制作48秒秋日叶片与竹席沙沙声、雨后稀疏水滴声；新增两条OGG和PCM24母带。完整数值见 [seasons.json](seasons.json)，均非田野录音，无外部采样或付费音频服务。运行时只激活对应的一条环境层，九月日常关闭附加层，雨后略压低原日间环境；沿用环境音总线、失焦暂停和退出释放。

Godot 4.7.2实际播放跨循环末尾、失焦暂停和恢复通过，证据 `tests/season_scene_test.gd` 及 `.local/verification/season-scene-final.log`。暂停时 `playing` 不足以判定是否已有播放实例，应依照官方 [AudioStreamPlayer.has_stream_playback](https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html#class-audiostreamplayer-method-has-stream-playback) 检查；恢复后再核验播放位置跨末尾。数值和运行验证不代表主观听感复核，下面原声音制作记录中的听感限制仍适用。

任务 3.4，2026-09-17。采用原创程序作曲／合成，不使用外部采样；“筝类拨弦／笛类气息”描述合成音色，不能写成真实古筝、箫或田野录音。素材目录服务曾尝试 media-use，因本机无 HeyGen CLI 未能返回音源；没有安装服务、调查账户或继续商务核验。

## 制作入口

`compose_farm_audio.py` 保存完整声部、音符、包络、谐波、混响、种子与导出过程。`score.json` 是实际 128 秒、60 BPM、八个四小节乐句的乐谱事件，旋律以 D 大调五声音阶组织，拨弦伴奏保留和声与句末空白；不以几声提示音替代背景曲。日夜环境床各 64 秒，柔和空气层配稀疏合成鸟声／虫声，四个短音对应播种、浇水、收获、界面。

```powershell
& python ArtSource/Audio/compose_farm_audio.py
& python ArtSource/Audio/analyze_audio.py
```

开发端需 Python 的 numpy／scipy／soundfile 和 FFmpeg；游戏仅加载冻结音频，不执行合成脚本。`masters/` 为 48kHz 双声道 PCM24 母带；运行音乐／环境为 Ogg Vorbis，操作为 PCM16 WAV，3 个 OGG `.import` 已设 loop=true。所有音色从数学谐波／固定随机种子生成，没有调用付费音频供应商。

## 输出与检测

| 资源 | 时长 | 测得 LUFS | 4× 过采样真峰值 dBFS |
|---|---:|---:|---:|
| courtyard_theme | 128s | -26.95 | -13.07 |
| ambience_day | 64s | -35.22 | -22.52 |
| ambience_night | 64s | -35.04 | -22.80 |
| sow | .48s | -27.25 | -13.13 |
| water | 1.15s | -23.30 | -13.15 |
| harvest | .65s | -23.34 | -16.48 |
| ui | .13s | 长度不足响度门限 | -16.29 |

`audio-report.json` 保存解码后 RMS／采样率／端点差，`validation-report.json` 保存 FFmpeg loudnorm 测量、过采样真峰值、DC、有限值、削波与端点检查。全部零削波；三个循环接点幅差均小于素材内正常相邻采样峰差。循环混响回卷到曲首，空气床周期构造；Godot 已实际跨末尾播放验证，不只查看 loop 参数。

必须区分数值和听感：当前模型工具返回“audio content omitted because you do not support audio input”，故**未完成模型主观听感复核**。已产出可播放完整曲与尾首拼接片段，不能把输出非零、峰值合格或成功播放称作“已经听过／无听感问题”。不等待用户而继续全部可完成的功能与实景验证。

播放／静音接口见 `Game/audio/farm_audio.gd`，3.3 已接入正式场景，设置持久化由 4.1 管理。3.4 的独立及正式场景验证已完成，接口与音轨证据见 [3.4交接](../../docs/task/首个可发布版本/handoffs/3.4-handoff.md)；40秒有声阶段片及录制退出清理记录见 [3.3交接](../../docs/task/首个可发布版本/handoffs/3.3-handoff.md)。主观听感边界仍如上所述。
