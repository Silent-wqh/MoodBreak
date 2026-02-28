MoodBreak MVP0 (无情绪价值极简版) — Spec for Coding Agent (Revised)

变更摘要
- interval 默认值改为 25 分钟
- menu bar 图标使用 repo 根目录的 cat.pdf（优先）/ cat.svg（备选）
- 图标要求为“单色模板图标”（适配浅色/深色模式）

0. 目标
实现一个可运行的 macOS menu bar 常驻应用，用于“自然的休息提醒”。
本版本不包含 LLM、不包含情绪输入、不包含长期统计。
重点验证：调度节奏、active/idle 暂停计时是否合理、交互是否不打断。

1. 平台与技术约束
- 平台：macOS（menu bar app）
- UI：AppKit + NSStatusItem
- 不依赖云服务
- 允许后续扩展模块化结构

2. 隐私约束（必须）
- 仅检测用户是否“有操作”（active/idle）以及最后交互时间
- 不记录具体按键、鼠标位置、输入内容
- 不保存任何原始输入事件日志
- 不向任何外部服务发送输入行为数据

3. 核心概念与状态
3.1 状态
- active：用户在使用电脑（有交互）
- idle：连续一段时间无交互（默认阈值 5 分钟）

3.2 时间量
- work_time：连续工作累计时长（仅在 active 时累加，idle 时暂停）
- interval：提醒间隔（默认 25 分钟）
- jitter：随机抖动（MVP0 默认 0，可不实现）

4. 调度规则（验收以此为准）
4.1 work_time 累计
- active：work_time 以真实时间累加
- 连续 idle_threshold(=5min) 无交互：进入 idle
- idle：暂停累计（work_time 不增长）
- 恢复交互：回到 active，work_time 继续累加（不清零）

4.2 触发提醒
- 当 work_time >= interval 时触发一次提醒
- 触发后等待用户响应；用户响应后进入下一轮计时

4.3 用户响应逻辑（至少 3 个动作）
A) 现在休息（Rest Now）
- 本次完成
- work_time = 0，开始下一轮

B) 稍后（Snooze）
- 5 / 10 / 20 分钟选项
- next_fire_time = now + snooze_minutes
- 到达 next_fire_time 后触发提醒（仍受 idle 影响：idle 时延后到恢复 active 再触发）
- Snooze 不强制重置 work_time（推荐：不重置，且 next_fire_time 优先）

C) 跳过本次（Skip）
- 本次结束
- work_time = 0，开始下一轮

可选（推荐，简单且体验完整）：
D) 今天不再提醒（Mute Today）
- 当天剩余时间不再触发提醒
- menu bar 提供撤销入口“恢复提醒”
- 次日自动恢复（记录 mute_until = 明天 00:00 本地时间）

5. UI 需求（MVP0）
5.1 menu bar 图标（必须）
- 使用 NSStatusItem
- 图标资产位于 repo 根目录：
  - cat.pdf（优先使用，作为模板图标）
  - cat.svg（仅作备选或用于生成/修改）
- 图标必须作为“模板图标/单色图标”使用（适配浅色/深色）
  - 若使用 NSImage：设置 template 属性（或等价方式）以跟随系统颜色
- 不使用 Apple emoji 作为 status bar 图标

5.2 menu bar 菜单（至少）
- 立即测试提醒（Test Notify）
- （可选）暂停/恢复提醒（Pause/Resume）
- （可选）今天不再提醒 / 恢复提醒
- 退出（Quit）
- （可选调试项）显示 active/idle、work_time

5.3 提醒呈现
- 轻量、不抢焦点优先
- 可用 UNUserNotificationCenter 通知 + actions，或自定义小窗口
- 必须能完成 Rest/Snooze/Skip 三类操作

6. 数据与持久化（MVP0）
- 默认不需要持久化（重启后状态丢失可接受）
- 若实现 Mute Today：使用 UserDefaults 保存 mute_until

7. 组件划分（建议）
- ActivityMonitor：输出 active/idle 与 lastInteractionTime
- Scheduler：work_time、interval、idle_threshold、mute_until、next_fire_time
- UIController：menu bar 菜单与提醒交互
- Storage（可选）：UserDefaults 封装

8. 最小手动测试清单（验收）
- 将 interval 临时设为 1 分钟：能稳定触发提醒
- Rest Now：work_time 重置并开始下一轮
- Snooze：到点触发（测试时可把 5 分钟改成 10 秒）
- Skip：本次结束并进入下一轮
- 不操作 >= 5 分钟：进入 idle，work_time 不增长
- 恢复操作：回到 active，work_time 继续增长
- 若实现 Mute Today：启用后当天不再提醒，可撤销

9. 明确不做（防止范围膨胀）
- 不接 LLM
- 不做“观察+善意猜测”文案
- 不做情绪按钮/抽象信号
- 不做宠物动画细节
- 不做多模型配置、base_url/api_key UI
- 不做云同步

Deliverable
- 可运行的 macOS menu bar app
- 使用 cat.pdf 作为模板图标
- README：隐私约束、如何运行、如何测试（含把 interval 改小进行测试的方法）
