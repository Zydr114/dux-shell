# Clavis 布局修复

日期：2026-10-31。分支：`feat/clavis-integration`。对应用户提供的 `osd-error.png` 和 `radius.png`；前一轮整合记录见 [Clavis 验收](clavis-integration-acceptance.md)。

## 通知文字与倒计时

截图中的通知使用两行文字，却仍受紧凑灵动岛的固定高度限制，标题接近上缘，摘要与倒计时挤在一起。

`NotificationCompact` 现在根据图标、实际字体行高、行间距和内边距报告所需高度，并为启用的限时通知倒计时预留独立空间。Controller 在可用屏幕范围内使用该高度。测量不依赖宿主当前高度，避免尺寸反馈；更新通过合并的 `Qt.callLater` 提交，不增加轮询或定时器。竖栏继续使用图标布局。

现有 Niri / Quickshell 会话中，以字体缩放 1.15、紧凑厚度 40、2200ms 通知验证：两行文字和倒计时分离，到期后活动恢复为 media。[修复后通知](evidence/clavis-20261031-fixes/notification.png)。

## 卡片圆角

电池液面、天气山丘等背景铺满卡片时越过圆角。共享 `DCard` 的 `clipContent` 将内容直接挂到 `ClippingRectangle` 本体，而有效裁剪发生在其默认 `contentItem` 内；原有开关没有裁切这些背景。

电池、日期、Clavis 系统指标和天气内容改用局部 `ClippingRectangle`，让背景成为其默认内容，裁剪半径跟随外卡 `bodyRadius`。天气页主视觉同样传入宿主半径。此次没有修改共享子模块；替换相关 Clavis 卡片原有但无效的裁剪路径，没有新增后台进程、定时器或服务订阅。

原七卡布局的实机截图确认电池四角、天气底部山丘及网络卡片外轮廓正确裁切。[修复后仪表盘](evidence/clavis-20261031-fixes/dashboard.png)。日期、独立 CPU / 内存 / 磁盘卡及天气页主视觉完成源码与解析检查，额外布局截图受桌面交互打断，未计入视觉验收。

## 检查与边界

- `make lint-qml` 两入口通过；9 个变更 QML 文件解析通过；`git diff --check` 通过。
- QML 测试 Qt 31、lock 38 及 logic 套件通过。没有新增加载 UI 模块的测试，没有另启动 shell 或 compositor。
- 截图在本机已有会话、HDMI-A-1、2048×1152 逻辑尺寸和 1.25 缩放下采集；只归档界面裁图。
- 字体放大、较薄状态栏、关闭倒计时等额外截图受桌面交互打断，未计入视觉验收；多屏、竖栏及其他 compositor 未复验。
- 临时实验后的 `settings.json`、`plugin_settings.json` 与进入本轮修复时的备份逐字节一致；保留原来的七卡布局和用户选项。
- 检查区间没有新增指向通知或裁切组件的 QML 报错；仍观察到前轮已记录的缺少 `khal` 和临时网格恢复时的 `DashCardGrid.slotLayout` binding loop。没有重新进行性能或长期内存测试。
