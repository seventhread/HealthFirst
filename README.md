# HealthFirst

[![CI](https://github.com/seventhread/HealthFirst/actions/workflows/ci.yml/badge.svg)](https://github.com/seventhread/HealthFirst/actions/workflows/ci.yml)

HealthFirst 是一款面向办公室人群的原生 macOS 健康微提醒工具。

它不把“通知已经弹过”当成任务完成：如果用户没有回应，提醒会先淡出、保留待处理状态，再由一个角色带着新的文字与动作回来。用户选择开始后，角色会留下来陪完相应秒数；升级保持克制，不使用羞辱、恐吓或情感绑架。

> [!WARNING]
> 项目目前仍是开发预览版，尚未提供经过 Apple Developer ID 签名和公证的正式安装包。`unsigned` 下载包只有 ad-hoc 签名，仅适合了解风险并愿意验证源码与校验值的测试者。

## 当前状态

- 最低系统版本：macOS 13。
- 当前经过验证的预览目标：Apple Silicon（M1 或更新）。
- Intel Mac 构建尚未验证，也没有提供 Universal 2 安装包。
- 完全本地运行：无账号、无广告、无遥测、无自有后端。
- 当前没有自动更新；请只从本仓库的 Releases 页面获取预览文件。
- 登录后自动启动已接入 macOS `SMAppService`；未签名预览包可能被系统拒绝注册，届时设置会自动回滚并给出提示。
- 可关闭的轻提示音只用于自动出现的首次、再次和认真模式提醒；手动预览与完成回执保持安静。
- 下一次提醒、间隔剩余时间、活动中的开始/稍后/再次/引导状态、待处理队列和全局暂停会在本机保存；引导倒计时在应用关闭期间冻结，并在重启时安全恢复。

源码可以公开审查和自行构建。面向普通用户的一键安装版仍需完成 Developer ID 签名、公证和更多干净系统测试；正式图标已接入本地构建流程。

## 主要功能

- 20-20-20 护眼提醒。
- 默认每 40 分钟一次的站立与轻活动提醒。
- 用户主动启用的小动作提醒。
- 菜单栏入口、明显小窗、柔和遮罩与可选全屏认真模式。
- 开始、稍后、跳过、提前结束、完成回执和全局暂停。
- 登录后自动启动、可关闭的轻提示音，以及关键提醒调度状态的本地恢复。
- 温柔、冷幽默、毒舌、极简四套纯文字风格。
- 单一品牌角色与护眼、站立、小动作专属陪伴动画。
- 工作时段、VoiceOver 友好超时、减少动态效果与多屏重新定位。

完整产品定义见 [PRODUCT_SPEC.md](PRODUCT_SPEC.md)，交互流程见 [INTERACTION_STORYBOARD.md](INTERACTION_STORYBOARD.md)，角色设定见 [CHARACTER_DESIGN.md](CHARACTER_DESIGN.md)，微互动见 [MICROINTERACTION_CONCEPTS.md](MICROINTERACTION_CONCEPTS.md)，中文文案见 [COPY_LIBRARY_ZH.md](COPY_LIBRARY_ZH.md)。

## 普通用户：安装测试预览

目前推荐普通用户等待正式签名版。若你愿意参与未签名预览测试：

1. 只从本仓库的 **Releases** 页面下载文件名带 `unsigned` 的 ZIP 和对应 `.sha256` 文件。
2. 在终端进入下载目录并核对文件，例如：

   ```bash
   shasum -a 256 -c HealthFirst-v0.1.0-unsigned-macos-apple-silicon.zip.sha256
   ```

3. 解压后把 `HealthFirst.app` 拖入“应用程序”。
4. 因为预览版没有 Apple 公证，macOS 可能阻止首次打开。确认下载来源和校验值后，可以在 Finder 中按住 Control 点击应用并选择“打开”，再确认系统提示。请不要使用来历不明的镜像或关闭系统整体安全保护。
5. HealthFirst 运行在菜单栏，不显示 Dock 图标；退出请使用菜单栏中的退出入口。

如果你不愿意绕过未公证应用的系统提示，请不要安装此预览包，改为等待正式签名版本。

## 卸载

1. 如果开启过“登录后自动启动”，先在 HealthFirst 设置中将它关闭。若系统仍显示该项目，请前往“系统设置 > 通用 > 登录项”关闭或移除 HealthFirst。
2. 从菜单栏退出 HealthFirst。
3. 从“应用程序”文件夹删除 `HealthFirst.app`。
4. 如需同时清除本机偏好，可运行：

   ```bash
   defaults delete app.healthfirst.macos
   ```

HealthFirst 不安装独立后台辅助进程。未签名预览包的登录项注册可能被 macOS 拒绝；设置界面会回滚开关并显示原因。

## 开发者：从源码运行

需要 macOS 13 或更高版本，以及支持 Swift tools 6.1 的完整 Xcode。

```bash
swift build
swift test
swift run HealthFirst
```

如果 `xcode-select -p` 仍指向 `/Library/Developer/CommandLineTools`，可以临时指定完整 Xcode：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run HealthFirst
```

或永久切换：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 构建本地 App

开发脚本会生成带稳定 Bundle ID、`LSUIElement` 和 ad-hoc 签名的本地 App：

```bash
Scripts/build-app.sh
open .build-app/HealthFirst.app
```

Debug 构建会在菜单栏提供“动作实验室…”，用于预览角色动作和陪伴分层，不会触发或修改真实提醒。

App 图标由 `assets/app-icon/HealthFirst-AppIcon-master-v2.png` 可复现生成。单独生成 `.icns` 可运行：

```bash
Scripts/make-app-icon.sh /tmp/HealthFirst.icns
```

## 打包未签名测试预览

下面的流程不需要 Apple Developer Program 账号。脚本会进行 Release 构建、确认 ad-hoc 签名、读取 `Support/HealthFirst-Info.plist` 中的版本、检测当前二进制架构，并在 `dist/` 生成 ZIP 与 SHA-256 文件：

```bash
Scripts/package-unsigned-preview.sh
```

脚本不会覆盖已有同名产物。生成文件必须以 `unsigned` 标记上传，并在 GitHub Release 中说明“未使用 Developer ID 签名、未公证、仅供测试”。完整流程见 [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)。

## 隐私与健康说明

HealthFirst 当前不收集或上传个人数据。设置保存在本机；详细说明与删除方式见 [PRIVACY.md](PRIVACY.md)。安全问题请按 [SECURITY.md](SECURITY.md) 报告。

HealthFirst 提供的是一般性的休息与活动提醒，不是医疗器械，也不能替代诊断、治疗或专业医疗建议。不同人的眼睛、肌肉和盆底健康状况不同；如果动作引起疼痛、不适、眩晕或其他异常，请停止并咨询合格的医疗专业人士。

## 许可证与素材

项目代码以及仓库内现有角色与视觉素材采用 [MIT License](LICENSE)。素材授权、AI 辅助生成和加工过程记录见 [assets/README.md](assets/README.md)。

版本变化记录见 [CHANGELOG.md](CHANGELOG.md)。
