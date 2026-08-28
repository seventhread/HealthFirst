# HealthFirst 发布检查清单

这份清单区分“公开源码”“未签名测试预览”和未来的“正式签名发行版”。勾选项应由实际执行者确认，不应只因为 CI 通过就默认完成。

## 1. 公开源码前

- [ ] 审阅 `git status` 与完整 diff，只提交预期文件。
- [ ] 确认仓库中没有密码、Token、证书、私钥、keychain、设备日志或个人路径。
- [ ] 确认 `LICENSE`、`PRIVACY.md`、`SECURITY.md` 和 `CHANGELOG.md` 内容仍准确。
- [x] 按 [assets/README.md](assets/README.md) 记录并人工确认角色素材来源与 MIT 分发授权（2026-08-28）。
- [ ] 确认 README 的已实现功能与已知限制没有过度承诺。
- [ ] 运行 `swift test`。
- [ ] 运行 `Scripts/build-app.sh release` 并进行基本启动测试。
- [ ] 运行 `Scripts/make-app-icon.sh /tmp/HealthFirst.icns`，确认 `.icns` 可生成，并检查 Finder、菜单栏与系统设置中的图标表现。
- [ ] 确认 GitHub Actions CI 通过。

## 2. 未签名测试预览

- [ ] 在 `Support/HealthFirst-Info.plist` 中更新 `CFBundleShortVersionString` 与 `CFBundleVersion`。
- [ ] 确认当前 Bundle ID `app.healthfirst.macos` 是准备长期使用的标识。
- [ ] 运行 `Scripts/package-unsigned-preview.sh`。
- [ ] 确认文件名包含 `unsigned`，Release 标题与说明也明确标注“未签名、未公证、仅供测试”。
- [ ] 用新建 macOS 用户或另一台测试机解压、启动并完成护眼、站立、小动作、暂停和退出冒烟测试。
- [ ] 测试“登录后自动启动”的开启、系统授权、关闭和失败回滚；记录未签名构建是否被当前 macOS 拒绝注册。
- [ ] 用随包生成的 `.sha256` 文件执行 `shasum -a 256 -c <文件名>.sha256`。
- [ ] 记录构建机器架构；当前只将 Apple Silicon 视为已验证目标。
- [ ] 先创建 GitHub Release 草稿，人工复核文件与说明后再发布。

## 3. 获得 Apple Developer Program 资格后

- [ ] 创建并妥善保存 Developer ID Application 证书，绝不提交到仓库。
- [ ] 启用 Hardened Runtime，并使用安全时间戳完成内到外签名。
- [ ] 验证 entitlements 与应用实际能力一致。
- [ ] 构建并测试计划支持的架构；若提供 Universal 2，分别验证 `arm64` 与 `x86_64`。
- [ ] 在浅色、深色和常见 Finder 尺寸下人工检查正式 App 图标。
- [ ] 使用 `notarytool` 提交 Apple 公证，等待成功结果。
- [ ] 对 `.app` 或 DMG 执行 `stapler`，再验证 Gatekeeper 评估结果。
- [ ] 生成 DMG/ZIP 与 SHA-256，并在干净系统上完成安装、升级、卸载测试。
- [ ] 将 GitHub Release 从草稿发布，并同步更新 README 与 `CHANGELOG.md`。

## 4. 每次发布都要检查

- [ ] 健康提示不冒充医疗建议，不承诺治疗或预防疾病。
- [ ] 隐私说明与应用当前的网络、存储和系统权限行为一致。
- [ ] Release notes 列出主要变化、系统要求、支持架构、已知问题与回退方式。
- [ ] 安装包只上传到本项目官方 GitHub Releases，并保留校验文件。
