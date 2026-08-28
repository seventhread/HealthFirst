# Changelog

本项目的重要变更记录在此文件中。格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

### Added

- 护眼、站立与小动作三类本地健康提醒。
- 菜单栏入口、互动提醒面板、陪伴倒计时与认真模式。
- 四种中文提醒文案风格与角色动作资源。
- 正式 App 图标母版、可复现 `.icns` 生成脚本与 App Bundle 集成。
- 基于 macOS `SMAppService` 的登录后自动启动设置、系统状态同步与失败回滚。
- 仅用于自动首次、再次和认真模式提醒的可关闭本机轻提示音；手动预览与完成回执保持静音。
- 下一次提醒、语义化间隔剩余时间、活动/稍后/再次/引导状态、待处理队列和全局暂停的本地持久化、禁用类型过滤与安全恢复。
- 被动完成气泡的自动收起、鼠标穿透，以及 VoiceOver 与“减少动态效果”下的专用行为。
- macOS CI：运行 Swift 测试并验证 Release App 构建。
- 不依赖 Apple 开发者证书的 ad-hoc 测试预览打包与 SHA-256 校验流程。
- 隐私、安全、素材许可与发布检查文档。

### Known limitations

- 尚未提供 Apple Developer ID 签名、公证或自动更新。
- 当前测试预览只验证 Apple Silicon；Intel Mac 构建尚未验证。
- 未签名预览包的登录项注册可能被 macOS 拒绝。

[Unreleased]: https://github.com/seventhread/HealthFirst/commits/main
