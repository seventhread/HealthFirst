# HealthFirst

HealthFirst 是一款面向办公室人群的原生 macOS 健康微提醒工具。

它不把“通知已经弹过”当成任务完成：如果用户没有回应，提醒会先淡出、保留待处理状态，再由一个角色带着新的文字与动作回来。用户选择开始后，角色会留下来陪完相应秒数；升级保持克制，不使用羞辱、恐吓或情感绑架。

首版范围：

- 20-20-20 护眼提醒。
- 每 40 分钟一次的站立与轻活动提醒。
- 用户主动启用的盆底肌轻练习提醒，默认每日 3 次。
- 菜单栏入口、明显小窗、柔和遮罩，以及可选的全屏“认真模式”。
- 一个先做深的品牌角色：正式静态形象与完整 MVP 动作分镜已经确认；首版搭配四种纯文字风格。
- 文案、互动流程、角色皮肤彼此解耦，未来可以扩充角色而不改提醒逻辑。
- 完全本地、无账号、无遥测、免费开源。

当前已经进入原生 macOS 可运行原型阶段。详细定义见 [PRODUCT_SPEC.md](PRODUCT_SPEC.md)，完整流程见 [INTERACTION_STORYBOARD.md](INTERACTION_STORYBOARD.md)，角色设定见 [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md)，微互动巧思见 [MICROINTERACTION_CONCEPTS.md](MICROINTERACTION_CONCEPTS.md)，首批中文文案见 [COPY_LIBRARY_ZH.md](COPY_LIBRARY_ZH.md)。

## 已实现

- SwiftUI `MenuBarExtra` 菜单栏入口，不显示 Dock 图标。
- AppKit 非抢焦点提醒面板，以及用户主动开启的全屏认真模式。
- 护眼 20 秒、站立 60 秒、小动作 30 秒引导。
- 首次无回应后 3 分钟重试；再次无回应进入独立待处理队列，不阻塞其他提醒。
- 开始、稍后、跳过、提前结束、完成回执和全局暂停。
- 温柔、冷幽默、毒舌、极简四套文字风格；每类提醒均有多条首次与二次文案。
- 工作时段、日内小动作分布、VoiceOver 友好超时、Reduce Motion 和多屏重新定位。
- 纸片角色的完整动作语义与灰盒流程；正式位图角色已经覆盖平静、左右接牌、卷轴收牌、轻笑、转身、背面、折叠，以及站立流程的检查、举起、搬运和扶车姿势。
- 第一条正式动作纵切：角色从菜单栏织带登场，点击开始后主按钮视觉替身变成工作牌，从界面右侧交给夹手并收进卷轴。
- 固定三层提醒舞台：可拆装饰、角色与不可移动的安全操作坞彼此隔离。
- 三类专属陪伴视觉：护眼卷走卡片内容，站立在 60 秒内逐步拆框并组装 UI 小推车，小动作折好隐私信封并背身值班。
- 三类专属完成收尾：系好护眼软卷、把完成牌放到小推车上、为隐私信封封口。
- 站立 60 秒正式动作纵切：角色在 8/22/38/52 秒亲手把标题、背板和装饰轨组装成同一辆小推车，完成时放上勾牌并扶稳车身。
- 纯 Swift、注入时间的提醒状态机与单元测试。

正式角色采用透明位图关键姿势与原生 SwiftUI 道具的混合渲染，并已接入真实提醒状态；资源缺失时会逐姿势安全降级。登场、点击开始和站立拆框推车已经进入正式动作纵切；三种离场、二次返回、认真模式，以及护眼/安静练习中更完整的角色协作仍会继续从灰盒替换为正式动作。

## 开发运行

要求 macOS 13 或更高版本、Xcode 26.6 或兼容版本。

如果系统已经切换到完整 Xcode：

```bash
swift build
swift test
swift run HealthFirst
```

如果 `xcode-select -p` 仍显示 `/Library/Developer/CommandLineTools`，可先临时指定：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run HealthFirst
```

也可以永久切换：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 生成本地 App

开发脚本会生成带稳定 Bundle ID、`LSUIElement` 和 ad-hoc 签名的本地应用：

```bash
Scripts/build-app.sh
open .build-app/HealthFirst.app
```

产物位于 `.build-app/HealthFirst.app`。它适合本地开发与交互预览；登录时启动、正式 Developer ID 签名、公证与分发尚未接入。

Debug 构建还会在菜单栏里提供“动作实验室…”，可以直接切换全部角色动作、三类陪伴分层、完成收尾、进度与“减少动态效果”，不会触发或修改真实提醒。

## 许可证

本项目采用 [MIT License](LICENSE)。
