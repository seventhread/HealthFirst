# 角色与视觉素材说明

`assets/character/` 中的分镜、源图和运行时位图，以及 `assets/app-icon/` 中的 App 图标候选与母版，都是为 HealthFirst 制作的项目素材。

## 许可意图

除非某个文件旁另有明确说明，这些素材当前随本仓库一起按根目录 [MIT License](../LICENSE) 提供，允许在保留许可与版权声明的前提下使用、修改和再分发。

项目维护者已于 2026-08-28 明确确认并授权：本页列出的现有角色、动作、运行时位图与 App 图标均可随 HealthFirst 按 MIT License 公开分发。

## 来源记录

现有素材属于 HealthFirst 项目定制设计，其中部分位图经过 AI 辅助生成、抠图或编辑。早期角色图没有保留逐张提示词和完整加工日志；本页如实记录目前可确认的来源，不补写无法核实的过程。

若今后发现某个文件包含需要单独署名或限制再分发的第三方元素，应立即在文件旁增加独立许可说明，必要时从公开版本中移除。

| 路径 | 用途 | 当前来源状态 |
| --- | --- | --- |
| `character/*.png` | 角色设定与动作分镜 | 项目定制；维护者确认可按 MIT 分发，早期逐张生成记录未保留 |
| `character/source/*.png` | 编辑与姿势源图 | 项目定制并有 AI 辅助；维护者确认可按 MIT 分发 |
| `character/runtime/*.png` | 应用内实际加载的透明位图 | 由项目源图加工；维护者确认可按 MIT 分发 |
| `app-icon/HealthFirst-AppIcon-master-v1.png` | App 图标原始候选 | 2026-08-28 使用 Codex 内置 ImageGen，以 `character/runtime/mascot-neutral-v1.png` 为角色参考生成；提示意图见下文 |
| `app-icon/HealthFirst-AppIcon-master-v2.png` | 1024×1024 App 图标母版 | 由 v1 经 `Scripts/clean-app-icon.swift` 使用 AppKit/Core Graphics 确定性裁切与透明边缘清理；当前构建实际使用此文件 |

### App 图标生成记录

v1 的最终提示意图是：严格保留 HealthFirst 现有机器人角色的脸、紫灰色身体、橙色右上角与卷尺细节；将角色居中放入留有安全边距的暖灰紫色 macOS 风格圆角底板；不加入文字、水印、额外角色或新的品牌元素。ImageGen 原始输出的透明边缘不适合直接进入 `.icns`，因此没有直接用于构建。

v2 由仓库内的 `Scripts/clean-app-icon.swift` 从 v1 生成，清除了伪透明边缘并统一为 1024×1024 母版。该处理不重新绘制角色；作为参考输入的原始角色素材已包含在维护者上述 MIT 授权中。

提交新的视觉素材时，请同时更新这张表或在对应目录增加来源与许可文件。不要提交无法确认再分发权利的素材。
