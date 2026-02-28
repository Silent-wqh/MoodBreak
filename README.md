# MoodBreak MVP0

一个极简 macOS menu bar 常驻应用，用来做自然休息提醒。

## 隐私说明

- 只读取系统空闲时长（用于判断 active/idle）。
- 不记录按键内容、鼠标位置、输入文本。
- 不保存原始输入事件日志。
- 不向外部服务发送行为数据。

## 运行方式

1. 打开终端进入项目目录：
   ```bash
   cd /Users/qinghaowang/projects/temp-projects/codex_app_home/MoodBreak
   ```
2. 启动应用：
   ```bash
   swift run
   ```
3. 应用会出现在 menu bar（状态栏）中，图标优先读取资源目录 `Sources/MoodBreak/Resources/Icons/cat.pdf`，失败时回退 `cat.svg`，并按模板图标显示。

## Debug 日志

- 默认开启，直接在终端输出（`swift run` 的同一窗口可见）。
- 日志格式：
  - `[MoodBreak][时间][模块] 消息`
- 常见模块：
  - `App`（启动/退出）
  - `Activity`（active/idle 切换）
  - `Tick`（每 30 秒一次状态摘要）
  - `Scheduler`（触发提醒、处理动作）
  - `Notify`（通知权限、系统通知/弹窗发送）
  - `Popup`（内置弹窗交互）
  - `Storage`（mute_until 持久化）
- 如果你想临时关闭日志：
  ```bash
  MOODBREAK_DEBUG=0 swift run
  ```

## 通知权限

- 以 `.app` bundle 方式运行时，应用会请求通知权限并使用系统通知。
- 以 `swift run` 方式运行时（开发模式），应用使用内置弹窗完成 Rest/Snooze/Skip，不依赖系统通知权限。
- 菜单中会显示当前提醒模式。

## 如何测试

### 测试模式（推荐）

直接用测试模式启动：

```bash
MOODBREAK_TEST_MODE=1 swift run
```

测试模式参数：

- `interval = 60s`
- `idle_threshold = 20s`
- `snooze = 10s / 20s / 30s`
- 提醒超时自动 dismiss = `20s`
- 菜单会显示 `Mode: TEST`

### 快速手工测试（推荐）

1. 在菜单中点 `Test Notify`，确认通知出现并可执行动作。
2. 观察 `Activity` 与 `Work Time` 的变化。
3. 触发提醒后测试：
   - `Rest Now`：重置本轮计时。
   - `Snooze`：按按钮显示的延后时间再次提醒（正常模式是分钟，测试模式是秒）。
   - `Skip`：结束本轮并重置计时。
   - 关闭通知不操作：按最短 `Snooze` 处理。
4. 测试 `Pause Reminders` 和 `Mute Today`。

## 单元测试

```bash
swift test
```

已覆盖：

- active 累加 / idle 暂停
- interval 到点触发
- Rest/Skip 重置
- Snooze 的 next_fire_time 优先级
- idle 状态下到点延后到恢复 active
- dismiss 视为 snooze 5 分钟
- Mute Today 当天抑制 + 次日自动恢复
