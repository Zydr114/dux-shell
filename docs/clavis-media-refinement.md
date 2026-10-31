# Clavis 媒体卡复刻修正

日期：2026-10-31。开发分支：`feat/clavis-integration`。参考仍为本地 Clavis 快照 `c3ee54f147d5e85db072573857a83ca949a317a0` 的 `CaelestiaCover.qml`、`WaveProgressBar.qml`、`MaterialWaveProgressBar.qml` 及媒体卡参数。按视觉和行为独立实现，未引入 Clavis 的 GPL QML 或原生模块。

本记录更新 [前轮整合验收](clavis-integration-acceptance.md) 中 Caelestia 的开关语义和两种进度条实现。

## Caelestia 封面

前轮用全局 `audioVisualizerEnabled` 同时阻断封面订阅和共享服务，导致用户选择 Caelestia 后仍看不到频谱。原版则将频谱作为该封面自身的效果。现在选择 Caelestia、封面可见且正在播放时会独立订阅；普通可视化开关继续控制其他媒体可视化，设置页说明同步更新。

- 标准区域为 180，封面占其 80%；36 根柱使用 45 个真实频段的分组峰值，保留窄频峰值。
- 柱宽 4、静止长度 2、最大长度 20、封面间隔 6。柱的方向固定，按封面当前旋转角度反查轮廓距离；九瓣遮罩每 23.5 秒反向旋转一周，专辑图本身保持正向。
- 轮廓由 360 点缓存插值，环绕接缝连续。Canvas 预留柱尖的绘制范围；窄卡按尺寸缩放频谱，防止峰值被截断或挤占控制区。
- 暂停、减少动态效果或 Cava 不可用时保留低透明度静态柱；隐藏或销毁封面时释放订阅。启动异常也进入静态回退，订阅/模式变化才允许再尝试，没有新增重试轮询。

共享服务仍只管理一个 Cava 进程。45 段模式改用自动增益、100% 灵敏度、85% 降噪、50–10000 Hz 和 45 fps；单独的六段模式保留原参数。高分辨率输出聚合到旧六段接口时，映射至已有 blob / backdrop 的 45 满量程，避免自动增益后的 0–1000 输出让普通组件饱和。两种采样模式的滤波、增益和频段划分仍不同，并非波形等价转换。

[有音频输入的动态画面](evidence/clavis-media-refinement-20261031/audio-reactive.gif) · [频谱不同帧](evidence/clavis-media-refinement-20261031/spectrum-frames.png)

## 两种进度条

移除不等价的通用 `M3WaveProgress` 使用，独立绘制 Clavis 的两种外形；没有改动共享控件。

| 参数 | Wave | Material |
| --- | --- | --- |
| 形状 | 下缘平直、上缘起伏的填充水波带 | 圆头正弦曲线与右端圆点 |
| 厚度 | 6 | 6 |
| 振幅 | 6，叠加小幅次级波 | 2.5 |
| 波长 | 约 125.66 | 约 52.36 |
| 缺口 | 10，围绕进度位置分开 | 4，沿用参考的线端余量 |
| 细节 | 两端 30 范围渐平 | 3.3 的末端圆点，无常驻竖向播放头 |
| 动画周期 | 1200ms | 1200ms |

进度条区域高度为 36。播放位置按两种样式分别平滑，拖动直接跟随；暂停和减少动态效果冻结波形，保留外形。保留 DMS 的拖动预览、MPRIS 跳转、键盘处理及可访问性。封面与控制区间距也调整为参考的 24，并保留窄卡的控制区最小宽度。

[Wave](evidence/clavis-media-refinement-20261031/caelestia-wave.png) · [Material](evidence/clavis-media-refinement-20261031/caelestia-material.png) · [暂停](evidence/clavis-media-refinement-20261031/caelestia-paused.png) · [减少动态效果](evidence/clavis-media-refinement-20261031/caelestia-reduced.png) · [普通封面](evidence/clavis-media-refinement-20261031/rounded-wave.png)

## 验证

- `make lint-qml` 两入口通过；变更的 8 个 QML 文件解析通过，进度条定向严格 qmllint 通过，`git diff --check` 通过。
- 全仓 QML 测试：Qt 31、lock 38、logic 通过。频谱与轮廓的 8 项纯逻辑测试通过，其中 5 项为本轮新增，覆盖独立采样条件、峰值保留、六段输出范围和轮廓插值；没有加载 UI 模块的新增测试。
- 在已有 Niri / Quickshell 会话验证，HDMI-A-1 为 2048×1152 逻辑尺寸、1.25 缩放。没有另启动 shell 或 compositor。
- 普通开关关闭时，Caelestia 显示与采样正常；隐藏、暂停、减少动态效果后 Cava 数量为 0。启用普通组件并同时打开 Caelestia 时为 1；收起封面后保留 1 个普通采样进程；关闭普通开关后为 0。[场景状态](evidence/clavis-media-refinement-20261031/visual-status.json)、[并发与声音输入状态](evidence/clavis-media-refinement-20261031/audio-status.json)。这是有限场景计数，未做 CPU A/B 或长期内存测试。
- 使用人工 MPRIS 来源和低音量测试信号验证真实声音输入的频谱响应，查看动态截图的多个帧。没有向真实播放器发送控制指令。左右键产生两个实际 `SetPosition` 调用：[记录](evidence/clavis-media-refinement-20261031/seek-calls.json)。
- 最后一轮声音、并发及键盘检查的临时设置均逐字节恢复，测试来源与声音进程已清理。期间用户修改的状态栏、布局等选项予以保留，没有用早期整轮快照覆盖它们；插件设置未修改。
- 最后声音输入检查和此前有效视觉矩阵的日志均无新增 QML 警告。较早热重载过程有既存控件初始化、插件和图标提示，没有将热重载打断的截图计入验收。

本轮未完整复验鼠标拖动、Home / End 焦点路径、所有配色组合、多屏、缺失 Cava 的实际启动故障及其他 compositor。声音采集、平滑、字体和主题仍使用 DMS 基础设施，不承诺与 Clavis 逐帧一致。

另在较早的本机交互日志看到 Open Orpheus 对 `Shuffle` / `LoopStatus` 写入返回 `UnknownProperty`；对应播放器与 Quickshell 的能力报告需要单独核对。本轮没有向它发送控制指令，也未修改这条兼容路径。
