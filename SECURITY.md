# Security Policy

## Supported versions

HealthFirst 目前仍处于公开预览准备阶段。安全修复优先合入 `main`；在首个稳定版发布前，不承诺维护旧的预览构建。

| Version | Supported |
| --- | --- |
| `main` | Yes |
| 未签名预览包 | Best effort |

## Reporting a vulnerability

请优先使用 GitHub 仓库 **Security** 页面中的 **Report a vulnerability** 私密报告功能（如果该功能已启用）。报告中请包含：

- 受影响的版本或 commit；
- 可复现的最小步骤；
- 影响范围；
- 你已经尝试过的缓解方式。

如果私密报告功能尚未启用，请只创建一个不包含利用细节、密钥或个人信息的公开 Issue，请求维护者提供私密沟通方式。不要在公开 Issue 中发布可直接利用的漏洞细节。

维护者会尽力确认收到报告、评估影响并反馈修复进度，但当前项目由个人维护，暂不承诺固定响应时限。

## Release integrity

- 仓库不应包含 Developer ID 证书、私钥、keychain 或公证凭据。
- 当前 `unsigned` 预览包只有 ad-hoc 签名，没有 Apple Developer ID 签名或公证。
- 下载测试预览时，请核对与 Release 同时提供的 SHA-256 文件，并只从本仓库的 Releases 页面获取文件。
- 在正式签名、公证流程接入前，未签名包不应被描述为稳定版或面向所有用户的安全安装包。
