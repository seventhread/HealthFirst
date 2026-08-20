# HealthFirst 产品规格（MVP）

版本：0.4  
日期：2026-08-19  
状态：产品定义与交互原型

## 1. 产品定位

HealthFirst 是一款面向办公室人群的原生 macOS 菜单栏应用。它帮助用户在长时间屏幕工作中完成短暂、明确、可确认的健康动作。

核心承诺：

> 有礼貌，但不会轻易放弃。

产品不以“发送通知数”为成功标准，而以一次提醒是否获得了清晰响应为标准。没有点击只表示“未知”，不等于用户懒惰或拒绝。

## 2. 已确认的产品决策

- 首版平台：仅 macOS，最低目标 macOS 13。
- 用户：日常长时间使用电脑的办公室人群。
- 分发：免费开源；建议采用 MIT License，正式建项时确认。
- 运行方式：菜单栏常驻，默认不显示 Dock 图标。
- 数据：完全本地，无账号、无广告、无遥测、无远程文案生成。
- 默认呈现：明显的小窗；必要时使用柔和遮罩。
- 认真模式：用户主动开启后，第三阶段允许全屏提醒；始终保留紧急跳过。
- 先流程、后形象：灰盒流程验证已经完成，正式主角的静态方向与完整 MVP 提醒动作已经确认。
- 文案、互动协议、角色皮肤彼此分离；MVP 不提供角色选择，文字语气可以独立选择。
- 首版不做语音，只做文字、角色动作与道具；提示音只保留可关闭的系统级选项。

## 3. 首版提醒

### 3.1 护眼

- 默认开启。
- 连续屏幕会话 20 分钟后提醒。
- 引导时长 20 秒。
- 引导内容：把目光移到约 6 米外，暂时离开屏幕。
- 完整倒计时结束后才记录完成。
- 锁屏或休眠达到 20 秒，可作为一次自然护眼休息并重置尚未开始的本轮；若用户已经进入 20 秒护眼引导，则冻结引导并在返回后继续，避免后台直接替用户确认完成。
- 文案只承诺帮助缓解长时间近距离用眼的不适，不宣传防近视或永久保护视力。

### 3.2 站立与活动

- 默认开启。
- 每 40 分钟活跃工作时间提醒一次。
- 默认引导 60 秒，建议起身、走几步或舒展身体，而不是长时间原地站立。
- 40 分钟是产品体验默认值，不是医学标准；用户可在 20–120 分钟间调整。
- 完整倒计时结束后才记录完成。

### 3.3 盆底肌轻练习

- 默认关闭，必须由用户主动了解并启用。
- 开启后默认每日 3 次，在用户确认的工作时段内均匀安排，建议相隔至少 2 小时。
- 对外通知统一使用“小动作时间”“安静练习”或“隐形任务”，不显示具体身体部位。
- 跨天未完成提醒直接过期，不追补、不堆积。
- 不暗示治疗效果；疼痛、不适、盆底过度紧张或正在接受相关诊疗时，应停止并咨询专业人士。
- 首版不尝试自动判断动作是否正确，也不通过传感器宣称用户已经完成。

## 4. 提醒状态机

默认模式最多主动出现两次：

```text
scheduled
  → firstPresented（右上角明显小窗，约 8 秒）
      → guided → completed
      → snoozed → scheduled
      → skipped → missed
      → noResponse → retryPending
  → followupPresented（3 分钟后，新文字与新动作，约 12 秒）
      → guided → completed
      → snoozed
      → skipped → missed
      → noResponse → pendingInMenuBar
```

规则：

- 第一次没有回应：小窗淡出，但实例仍然待处理。
- 3 分钟后第二次出现，必须使用不同文案和不同动作/道具。
- 第二次仍没有回应：不继续重复弹窗；菜单栏图标显示待处理书签。
- 用户主动选择“稍后”不算忽略，也不升级语气。
- 用户主动“跳过”后结束本轮，下一轮重新计时。
- 用户选择“开始”后，角色留在引导界面陪完 20/30/60 秒；倒计时结束才记录完成。
- “稍后”“跳过”和无回应都使用中性退场动作，不能表现受伤、失望或责备。
- 同一提醒只保留一个实例，禁止在系统通知中心堆积副本。
- 同一句或同一梗当天不重复；同一文案至少间隔 5 次使用。

认真模式在默认流程上增加第三阶段：

```text
followup noResponse
  → softOverlay
      → guided → completed
      → emergencySkip → missed
```

- 认真模式可使用全屏柔和遮罩，但不锁定键盘鼠标。
- 不采用逃跑按钮、强制输入羞耻短句或惩罚性摩擦。
- 第三阶段仍不回应后结束本轮，不无限升级。

## 5. 单角色互动协议

MVP 先把一个角色做深，不把“可选三个角色”当作首发卖点。设计顺序与当前进度为：

1. 冻结提醒状态、用户选择和重试规则。
2. 先定义角色与 UI 的小巧思：折叠、归档、拆框、卷起和隐私收纳。
3. 用无品牌含义的灰盒轮廓跑通所有分支，验证陪伴感和打扰度（已完成）。
4. 只设计一个正式角色，先确认静态轮廓、比例、性格与道具系统（已完成）。
5. 形象冻结后再为它设计关键姿势和正式动作，不让动作草图掩盖形象问题（进行中）。
6. 最后把正式皮肤接回已经验证的互动协议。

正式主角是一位浅薰衣草灰色的“界面整理员”，以右上橙色折角、橙色织带卷轴、夹手和短工作靴构成识别锚点。表情只保留平静与轻微微笑，幽默主要来自动作。完整定义与关键帧见 [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md)。

### 5.1 核心体验

- 角色从菜单栏附近进入，像是在对用户说话，而不是作为卡片里的装饰图标。
- 角色只说一件事：现在做什么、需要多久。
- 用户可以选择 `开始`、`稍后` 或 `本次跳过`；按钮文案稳定，不跟着角色耍花样。
- 选择 `开始`：角色确认后留下，陪伴 20/30/60 秒；动作弱化，避免用户继续盯屏。
- 选择 `稍后`：角色中性回应约定的返回时间，然后退场。
- 选择 `本次跳过`：角色平静收尾，不追问原因、不表现失落。
- 没有回应：角色做一次轻量退场动作并淡出；约 3 分钟后换台词和动作回来。
- 第二次仍无回应：角色退回菜单栏，本轮不再主动追逐；认真模式除外。
- 完成：只播放一次 0.5–1 秒的克制正反馈，然后关闭。

### 5.2 语义动作

角色皮肤必须表达以下语义，不得自行改写业务状态：

| 动作 | 用途 | 视觉上限 |
|---|---|---|
| `enterFirst` | 首次进入并邀请 | 入场后立即可操作，不遮挡当前点击区 |
| `enterFollowup` | 带着“再次提醒”上下文返回 | 换动作或道具，不变得愤怒 |
| `awaitResponse` | 等待用户选择 | 不循环弹跳或持续索取注意力 |
| `acknowledgeStart` | 确认开始并转入引导 | 最迟 400 ms 后进入倒计时 |
| `acknowledgeSnooze` | 确认稍后 | 600 ms 内中性退场 |
| `acknowledgeSkip` | 确认本次跳过 | 500 ms 内中性退场 |
| `exitNoResponse` | 无回应时淡出 | 400 ms 内完成；不使用悲伤、受伤或责备表情 |
| `guide(kind)` | 陪伴动作进行 | 极简、低动态，不要求看屏幕 |
| `complete` | 完成反馈 | 单次、0.5–1 秒、可立即收起 |
| `emergencyExit` | 紧急跳过认真模式 | 200 ms 内先撤掉遮罩 |

动画是渐进增强：业务状态不等待动画完成。动作缺失、损坏或超时时，按“通用动作 → 静态角色 → 无角色”的顺序降级，文案、按钮和倒计时仍必须可用。

微互动的完整时间轴与边界见 `MICROINTERACTION_CONCEPTS.md`；正式角色形象与动作语言见 `CHARACTER_DESIGN.md`。

## 6. 文字风格

用户可独立选择：

- 温柔：承认用户当下可能不方便，提供轻松邀请。
- 冷幽默：用办公室公文、系统提示和荒诞比喻制造笑点。
- 毒舌：吐槽屏幕、椅子、会议和待办；不攻击用户本人。
- 极简：只传达动作、时长和当前状态。

趣味性只放在标题和正文。操作按钮保持稳定：

- 首次：`开始 20/30/60 秒`、`稍后 3 分钟`、`本次跳过`。
- 二次：`现在开始`、`稍后 10 分钟`、`本次跳过`。
- 认真模式：`现在开始`、`紧急跳过`。

内容安全红线：

- 不做身体羞辱、年龄羞辱或意志力羞辱。
- 不使用疾病恐吓或夸大健康收益。
- 不让宠物因用户忽略而受伤、哭泣或挨饿。
- 不使用失败红叉、连续打卡归零或公开排行榜。
- 毒舌文字必须把吐槽目标标记为 `screen`、`chair` 或 `work_context`，不能标记为 `self`。

## 7. 三个核心界面

### 7.1 首次启动

- 一页完成最小初始化：护眼 20/20、站立 40/60、工作时段与开机启动。
- 盆底肌必须由用户主动了解并启用，默认每日 3 次。
- 允许选择温柔、冷幽默、毒舌或极简文字；可随时在设置里更改。
- MVP 不展示角色选择，避免让尚未验证的外观抢在核心流程之前。

### 7.2 菜单栏 Popover

- 提醒运行状态与下一个 deadline。
- 下次护眼、站立和小动作时间。
- 快捷操作：现在休息、暂停 30 分钟/1 小时/今天、打开设置。
- 待处理提醒只显示一个状态点，不堆叠数字压力。

### 7.3 提醒小窗 / 遮罩

- 角色独立出现在对话气泡旁，通过动作和一句话发出邀请，而不是被塞成卡片插画。
- 第一次提供开始、稍后和本次跳过；第二次保持按钮位置稳定，只更换正文、动作或道具。
- 柔和遮罩将工作内容降为背景，但不制造闪烁。
- 认真模式只由用户主动开启。
- 点击“开始”后，角色转入低动态陪伴状态；倒计时完成后给 0.5–1 秒正反馈。

设置作为标准 macOS Settings 窗口提供，不塞进菜单栏小面板。

## 8. 上下文与冲突规则

- 同一时间最多展示一个提醒。
- 两类提醒在 5 分钟内到期时可以合并为一次“双份小休息”。
- 引导进行中暂停其他提醒计时。
- 锁屏、休眠、唤醒和系统时间改变后重新计算 deadline，禁止醒来后提醒风暴。
- 首版不请求摄像头、麦克风、屏幕录制、辅助功能或输入监控权限。
- 首版只用无敏感权限的会话信息处理睡眠、锁屏和系统勿扰；无法可靠判断会议时，优先允许用户快速暂停。
- 多屏默认在鼠标当前所在屏幕显示；后续可选主屏或所有屏幕。

## 9. 隐私与无障碍

- 无账号、无广告、无遥测、无主动网络请求。
- 不记录按键、鼠标坐标、窗口标题、截图或正在使用的 App。
- 设置保存在 `UserDefaults`；简要活动历史保存在本地 Application Support。
- 提供一键清空活动历史。
- 支持深浅色、VoiceOver、Full Keyboard Access、Increase Contrast、Reduce Transparency 和 Reduce Motion。
- 装饰动画播放一次，控制在 0.3–1.5 秒，不循环、不闪烁。
- Reduce Motion 下用淡入淡出、颜色变化或静态道具替代弹跳、缩放和横向飞入。
- 自动淡出不是唯一入口；菜单栏始终保留待处理状态。

## 10. 技术架构

首版采用 SwiftUI + AppKit：

```text
ReminderCore
  ReminderPolicy
  ReminderInstance
  ReminderStateMachine
  ReminderCoordinator
  ClockProtocol

Presentation
  MenuBarController (NSStatusItem)
  MenuPopoverController (NSPopover + SwiftUI)
  PromptPanelController (NSPanel + SwiftUI)
  OverlayWindowManager (每个 NSScreen 一个窗口)
  NotificationService (系统通知只做兜底)

Content
  ContentPack
  ContentPackValidator
  ContentSelector

Character
  InteractionProtocol
  CharacterRenderer
  CharacterSkinManifest
  CharacterAssetRegistry

System
  SessionMonitor
  LoginItemService (SMAppService)
  SettingsStore
  ActivityHistoryStore
```

领域层使用可注入 `ClockProtocol`。业务只安排下一个 deadline；界面倒计时使用 `TimelineView`，不让多个每秒 Timer 驱动业务逻辑。

三层边界：

- `ContentPack` 只负责文案、语气、可访问文本和重复控制。
- `InteractionProtocol` 把提醒状态与用户选择映射为语义动作，不依赖具体形象。
- `CharacterSkinManifest` 只声明本地动作资产、配色、布局参数、静态降级和 Reduce Motion 替代。

角色皮肤不能包含文案、按钮标签、提醒频率或重试规则，也不能执行代码或联网。更换文案或皮肤都不能改变业务 deadline。禁用 `CharacterRenderer` 后，完整提醒流程仍然可操作。

## 11. MVP 不做

- Windows/Linux、手机端或 Apple Watch。
- AI 在线生成文案。
- 账号、云同步、社交排行榜。
- 自动识别用户是否真正站立或正确完成动作。
- 强制锁定键盘鼠标。
- 复杂统计、连续打卡和宠物养成经济系统。
- 多角色选择、在线皮肤商店或皮肤下载。
- 喝水、冥想等额外提醒；它们以后复用同一提醒协议扩展。

## 12. 首版验收标准

- 菜单栏应用启动后无 Dock 图标。
- 护眼 20/20 与站立 40/60 默认生效；盆底肌默认关闭。
- 忽略首次提醒后，卡片淡出且 3 分钟后使用不同文字与动作重新出现。
- 第二次仍未回应后只保留菜单栏待处理状态，默认不继续弹。
- 点击“开始”后角色切换到陪伴动作；点击本身不记完成，完整倒计时结束后才记完成。
- “稍后”“无回应”“主动跳过”“完整完成”分别记录。
- 睡眠、锁屏、唤醒、重启、跨天和显示器拔插不产生重复提醒。
- 正式角色动作覆盖首次、二次、遮罩、开始、稍后、跳过、无回应、引导、完成和紧急退出。
- 禁用角色渲染，或动作资源缺失、损坏、超时时，所有提醒仍可用纯文字完成。
- 更换 `ContentPack` 不改变动作语义与 deadline；更换皮肤不改变文案、按钮和状态迁移。
- 每个动作都有 Reduce Motion 或静态降级；快速双击只产生一次状态迁移。
- 支持键盘、VoiceOver、深浅色和 Reduce Motion。
- 空闲 CPU 目标低于 0.5%，内存目标低于 100 MB，冷启动至菜单栏可用目标低于 1 秒。
- 使用网络检查确认发布版无主动外连。

## 13. 实施顺序

1. 冻结提醒状态机、用户选择语义与自动返回上限。
2. 定义角色语义动作接口、转场时限和降级规则。
3. 完成退场、拆框、卷起和隐私收纳的语义微互动，并冻结互动协议。
4. 扩充并验证首批中文 `ContentPack`。
5. 沿已冻结的单一正式主角方向，补齐陪伴、再次返回、完成和紧急退出关键姿势。
6. 建立 Swift Package 和纯 Swift 状态机，使用假时钟完成单元测试。
7. 接入 NSStatusItem、NSPopover、NSPanel、设置与正式角色皮肤。
8. 完成睡眠/锁屏、多屏、Reduce Motion 和通知兜底验证。
9. 签名、notarization、干净账户安装测试后发布首个 GitHub Release。

## 14. 健康与设计参考

- [American Academy of Ophthalmology：Eye Strain](https://www.aao.org/eye-health/diseases/what-is-eye-strain)
- [CDC/NIOSH：Reduce the Health Risks from Sedentary Work](https://www.cdc.gov/niosh/docs/wp-solutions/2017-131/)
- [NIDDK：Kegel Exercises](https://www.niddk.nih.gov/health-information/urologic-diseases/kegel-exercises)
- [Mayo Clinic：Kegel exercises](https://www.mayoclinic.org/healthy-lifestyle/womens-health/in-depth/kegel-exercises/art-20045283)
- [Apple Human Interface Guidelines：Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications)
- [Apple Accessibility：Reduced Motion](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/)
