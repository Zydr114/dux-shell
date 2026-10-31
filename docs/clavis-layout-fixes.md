# Clavis 布局修复

日期：2026-10-31。分支：`feat/clavis-integration`。对应用户提供的 `osd-error.png` 和 `radius.png`；前一轮整合记录见 [Clavis 验收](clavis-integration-acceptance.md)。

## 通知文字与倒计时

截图中的通知使用两行文字，却仍受紧凑灵动岛的固定高度限制，标题接近上缘，摘要与倒计时挤在一起。

`NotificationCompact` 现在根据图标、实际字体行高、行间距和内边距报告所需高度，并为启用的限时通知倒计时预留独立空间。Controller 在可用屏幕范围内使用该高度。测量不依赖宿主当前高度，避免尺寸反馈；更新通过合并的 `Qt.callLater` 提交，不增加轮询或定时器。竖栏继续使用图标布局。

现有 Niri / Quickshell 会话中，以字体缩放 1.15、紧凑厚度 40、2200ms 通知验证：两行文字和倒计时分离，到期后活动恢复为 media。[修复后通知](evidence/clavis-20261031-fixes/notification.png)。

## 检查与边界

- `make lint-qml` 两入口通过；9 个变更 QML 文件解析通过；`git diff --check` 通过。
- QML 测试 Qt 31、lock 38 及 logic 套件通过。没有新增加载 UI 模块的测试，没有另启动 shell 或 compositor。
- 截图在本机已有会话、HDMI-A-1、2048×1152 逻辑尺寸和 1.25 缩放下采集；只归档界面裁图。
- 字体放大、较薄状态栏、关闭倒计时等额外截图受桌面交互打断，未计入视觉验收；多屏、竖栏及其他 compositor 未复验。
- 临时实验后的 `settings.json`、`plugin_settings.json` 与进入本轮修复时的备份逐字节一致；保留原来的七卡布局和用户选项。
