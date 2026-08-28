import Foundation
import HealthFirstCore

/// The user-selectable writing style used by reminder cards.
///
/// English raw values are intentionally stable so a setting can be persisted
/// without tying storage to the localized display name.
enum ReminderCopyTone: String, CaseIterable, Codable, Identifiable, Sendable {
    case gentle
    case dryHumor
    case sharp
    case minimal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle:
            "温柔"
        case .dryHumor:
            "冷幽默"
        case .sharp:
            "毒舌"
        case .minimal:
            "极简"
        }
    }
}

struct ReminderActionLabels: Equatable, Sendable {
    let start: String
    let snooze: String
    let skip: String
    let endEarly: String
}

struct ReminderPromptCopy: Equatable, Sendable {
    let kind: ReminderKind
    let stage: ReminderPresentationStage
    let tone: ReminderCopyTone
    let eyebrow: String
    let title: String
    let message: String
    let actions: ReminderActionLabels
}

enum ReminderReceiptOutcome: Equatable, Sendable {
    case completed
    case snoozed(delay: TimeInterval)
    case skipped
}

struct ReminderReceiptCopy: Equatable, Sendable {
    let title: String
    let message: String
    let dismissButton: String
}

/// Selects fresh-feeling copy without introducing randomness into rendering.
/// The same reminder UUID (or integer seed) always produces the same result.
enum ReminderCopy {
    static let defaultSnoozeDelay: TimeInterval = 3 * 60

    static func prompt(
        for kind: ReminderKind,
        stage: ReminderPresentationStage,
        tone: ReminderCopyTone,
        reminderID: UUID,
        guideDuration: TimeInterval? = nil,
        snoozeDelay: TimeInterval = defaultSnoozeDelay
    ) -> ReminderPromptCopy {
        prompt(
            for: kind,
            stage: stage,
            tone: tone,
            seed: stableSeed(reminderID.uuidString),
            guideDuration: guideDuration,
            snoozeDelay: snoozeDelay
        )
    }

    static func prompt(
        for kind: ReminderKind,
        stage: ReminderPresentationStage,
        tone: ReminderCopyTone,
        seed: UInt64,
        guideDuration: TimeInterval? = nil,
        snoozeDelay: TimeInterval = defaultSnoozeDelay
    ) -> ReminderPromptCopy {
        let pool = promptPool(for: kind, tone: tone)
        let candidates = stage == .first ? pool.first : pool.followUp
        let salt = stableSeed("\(kind.rawValue)|\(stage.rawValue)|\(tone.rawValue)")
        let index = Int(mixed(seed ^ salt) % UInt64(candidates.count))
        let selected = candidates[index]
        let resolvedDuration = resolvedGuideDuration(guideDuration, for: kind)

        return ReminderPromptCopy(
            kind: kind,
            stage: stage,
            tone: tone,
            eyebrow: eyebrow(for: stage),
            title: applyingGuideDuration(
                to: selected.title,
                kind: kind,
                duration: resolvedDuration
            ),
            message: applyingGuideDuration(
                to: selected.message,
                kind: kind,
                duration: resolvedDuration
            ),
            actions: actionLabels(
                for: kind,
                tone: tone,
                guideDuration: resolvedDuration,
                snoozeDelay: snoozeDelay
            )
        )
    }

    static func actionLabels(
        for kind: ReminderKind,
        tone: ReminderCopyTone,
        guideDuration: TimeInterval? = nil,
        snoozeDelay: TimeInterval = defaultSnoozeDelay
    ) -> ReminderActionLabels {
        let duration = durationText(
            resolvedGuideDuration(guideDuration, for: kind)
        )
        let later = durationText(snoozeDelay)
        let snooze = "\(later)后提醒"

        let task: String = switch kind {
        case .eye:
            "望远 \(duration)"
        case .standing:
            "起身 \(duration)"
        case .quietPractice:
            "做 \(duration)小动作"
        }

        switch tone {
        case .gentle:
            return ReminderActionLabels(
                start: "好，\(task)",
                snooze: snooze,
                skip: "这次先跳过",
                endEarly: "先到这里"
            )
        case .dryHumor:
            return ReminderActionLabels(
                start: "批准，\(task)",
                snooze: snooze,
                skip: "本次放过我",
                endEarly: "提前收工"
            )
        case .sharp:
            return ReminderActionLabels(
                start: "现在\(task)",
                snooze: snooze,
                skip: "本次跳过",
                endEarly: "提前结束"
            )
        case .minimal:
            return ReminderActionLabels(
                start: "开始 · \(duration)",
                snooze: snooze,
                skip: "跳过",
                endEarly: "结束"
            )
        }
    }

    static func receipt(
        for kind: ReminderKind,
        outcome: ReminderReceiptOutcome,
        tone: ReminderCopyTone,
        guideDuration: TimeInterval? = nil
    ) -> ReminderReceiptCopy {
        switch outcome {
        case .completed:
            return completionReceipt(
                for: kind,
                tone: tone,
                guideDuration: guideDuration
            )
        case .snoozed(let delay):
            return snoozeReceipt(delay: delay, tone: tone)
        case .skipped:
            return skipReceipt(tone: tone)
        }
    }
}

private extension ReminderCopy {
    struct Prompt: Sendable {
        let title: String
        let message: String
    }

    struct PromptPool: Sendable {
        let first: [Prompt]
        let followUp: [Prompt]
    }

    static func eyebrow(for stage: ReminderPresentationStage) -> String {
        switch stage {
        case .first:
            "健康小提醒"
        case .followUp:
            "再提醒一次"
        case .serious:
            "认真模式"
        }
    }

    static func promptPool(
        for kind: ReminderKind,
        tone: ReminderCopyTone
    ) -> PromptPool {
        switch (kind, tone) {
        case (.eye, .gentle):
            PromptPool(
                first: [
                    Prompt(
                        title: "借一小块远方",
                        message: "看向窗外或房间尽头 20 秒，让视线轻轻换个焦点。"
                    ),
                    Prompt(
                        title: "给眼睛一段空白",
                        message: "从屏幕上抬头，看远处 20 秒。工作先在这里等你。"
                    ),
                    Prompt(
                        title: "远处正在营业",
                        message: "找一个远一点的物体，看它 20 秒，再慢慢回来。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "那片远方还留着",
                        message: "刚才可能正忙。现在抬头看远处 20 秒，就好。"
                    ),
                    Prompt(
                        title: "再给眼睛一次机会",
                        message: "不用离开座位，换个远焦点停留 20 秒。"
                    ),
                    Prompt(
                        title: "这次一起望远",
                        message: "屏幕可以等一会儿。我们只去远处待 20 秒。"
                    ),
                ]
            )

        case (.eye, .dryHumor):
            PromptPool(
                first: [
                    Prompt(
                        title: "眼睛申请远程办公",
                        message: "办公地点：20 米外。申请时长：20 秒。是否批准？"
                    ),
                    Prompt(
                        title: "焦距需要换个频道",
                        message: "本节目插播 20 秒远景，广告之后继续盯屏幕。"
                    ),
                    Prompt(
                        title: "远方没有掉线",
                        message: "连接它 20 秒，无需密码，也不用开摄像头。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "远程申请再次提交",
                        message: "你的眼睛补齐了材料：只要看远处 20 秒。"
                    ),
                    Prompt(
                        title: "系统仍检测到屏幕很近",
                        message: "建议切换至“远方”页面 20 秒，然后自动返回。"
                    ),
                    Prompt(
                        title: "第二次插播",
                        message: "剧情没变：抬头，看远处，20 秒后继续。"
                    ),
                ]
            )

        case (.eye, .sharp):
            PromptPool(
                first: [
                    Prompt(
                        title: "别把屏幕盯出答案",
                        message: "这行字不会自己写完。先看远处 20 秒。"
                    ),
                    Prompt(
                        title: "你的焦距卡在工位了",
                        message: "抬头，选个远处目标。20 秒，不耽误你继续厉害。"
                    ),
                    Prompt(
                        title: "近距离够久了",
                        message: "把目光送远一点，20 秒后再回来处理屏幕。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "嗯，屏幕还在",
                        message: "所以现在可以放心看远处 20 秒了。"
                    ),
                    Prompt(
                        title: "这不是弹窗，是台阶",
                        message: "迈过去很简单：抬头，看远处 20 秒。"
                    ),
                    Prompt(
                        title: "再忙也有 20 秒",
                        message: "不用完成世界，只要把视线从屏幕移开。"
                    ),
                ]
            )

        case (.eye, .minimal):
            PromptPool(
                first: [
                    Prompt(title: "看远处", message: "停留 20 秒。"),
                    Prompt(title: "换个焦点", message: "望向房间尽头或窗外 20 秒。"),
                    Prompt(title: "视线休息", message: "离开屏幕，看远处 20 秒。"),
                ],
                followUp: [
                    Prompt(title: "再次提醒", message: "现在看远处 20 秒。"),
                    Prompt(title: "该望远了", message: "抬头，停留 20 秒。"),
                    Prompt(title: "暂停近看", message: "远焦点，20 秒。"),
                ]
            )

        case (.standing, .gentle):
            PromptPool(
                first: [
                    Prompt(
                        title: "让身体换个姿势",
                        message: "站起来 60 秒，伸伸腿，也让椅子休息一下。"
                    ),
                    Prompt(
                        title: "起来透一口气",
                        message: "离开座位 60 秒。走两步、伸个懒腰，都可以。"
                    ),
                    Prompt(
                        title: "给自己一分钟",
                        message: "慢慢站起来，舒展一下。回来时工作还在。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "那一分钟还在等你",
                        message: "刚才可能走不开。现在起身 60 秒，我陪你。"
                    ),
                    Prompt(
                        title: "再邀请你站一会儿",
                        message: "不用走远，离开椅子 60 秒就很好。"
                    ),
                    Prompt(
                        title: "换个高度再继续",
                        message: "站起来舒展 60 秒，再坐下也不迟。"
                    ),
                ]
            )

        case (.standing, .dryHumor):
            PromptPool(
                first: [
                    Prompt(
                        title: "椅子申请独处",
                        message: "它只需要 60 秒。你可以顺便站起来活动一下。"
                    ),
                    Prompt(
                        title: "工位高度测试",
                        message: "请切换到站立视角 60 秒，看看世界有没有更新。"
                    ),
                    Prompt(
                        title: "腿部系统待唤醒",
                        message: "启动方式：站起来。预计耗时：60 秒。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "椅子再次提交申请",
                        message: "审批流程很短：站起来 60 秒就算通过。"
                    ),
                    Prompt(
                        title: "站立视角仍未解锁",
                        message: "只差 60 秒体验时间，随时可以开始。"
                    ),
                    Prompt(
                        title: "腿部系统发来重试",
                        message: "没有报错，只是在等你站起来一分钟。"
                    ),
                ]
            )

        case (.standing, .sharp):
            PromptPool(
                first: [
                    Prompt(
                        title: "椅子不是你的固定资产",
                        message: "先站起来 60 秒，再回来继续占用它。"
                    ),
                    Prompt(
                        title: "腿还没下班",
                        message: "让它们工作一分钟：起身、伸展、走两步。"
                    ),
                    Prompt(
                        title: "别和椅背融为一体",
                        message: "站起来 60 秒，很快，也很体面。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "椅子赢了第一回合",
                        message: "第二回合简单一点：你只要站 60 秒。"
                    ),
                    Prompt(
                        title: "你还在坐，我还在提醒",
                        message: "我们都省点时间：现在起身一分钟。"
                    ),
                    Prompt(
                        title: "这件事不用排期",
                        message: "站起来 60 秒，做完就关单。"
                    ),
                ]
            )

        case (.standing, .minimal):
            PromptPool(
                first: [
                    Prompt(title: "站起来", message: "活动 60 秒。"),
                    Prompt(title: "离开座位", message: "伸展或走动 1 分钟。"),
                    Prompt(title: "换个姿势", message: "站立 60 秒。"),
                ],
                followUp: [
                    Prompt(title: "再次提醒", message: "现在站立 60 秒。"),
                    Prompt(title: "该起身了", message: "离开座位 1 分钟。"),
                    Prompt(title: "短暂站立", message: "60 秒，然后继续。"),
                ]
            )

        case (.quietPractice, .gentle):
            PromptPool(
                first: [
                    Prompt(
                        title: "留 30 秒给小动作",
                        message: "不用离开工位，安静完成一轮就好。"
                    ),
                    Prompt(
                        title: "现在适合做个小动作",
                        message: "放松呼吸，用 30 秒照顾一下自己。"
                    ),
                    Prompt(
                        title: "一段安静的小练习",
                        message: "准备好就开始，30 秒里只需要关注这个小动作。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "小动作还为你留着",
                        message: "刚才可能不方便。现在用 30 秒安静完成它。"
                    ),
                    Prompt(
                        title: "再留半分钟给自己",
                        message: "无需起身，做一轮小动作就可以继续。"
                    ),
                    Prompt(
                        title: "这次我陪你做完",
                        message: "准备好后开始，安静专注 30 秒。"
                    ),
                ]
            )

        case (.quietPractice, .dryHumor):
            PromptPool(
                first: [
                    Prompt(
                        title: "一项无需开会的小动作",
                        message: "不拉群、不共享屏幕，30 秒就能结束。"
                    ),
                    Prompt(
                        title: "隐形待办出现了",
                        message: "只有你看得见：安静做个 30 秒小动作。"
                    ),
                    Prompt(
                        title: "工位秘密任务",
                        message: "任务很小，动静更小。30 秒后自动结案。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "秘密任务再次出现",
                        message: "放心，周围没人收到通知。用 30 秒完成小动作。"
                    ),
                    Prompt(
                        title: "隐形待办还没勾选",
                        message: "它不催日报，只需要一轮 30 秒小动作。"
                    ),
                    Prompt(
                        title: "这场会只有你参加",
                        message: "议程：做个小动作。预计 30 秒散会。"
                    ),
                ]
            )

        case (.quietPractice, .sharp):
            PromptPool(
                first: [
                    Prompt(
                        title: "这件小事别再排到明天",
                        message: "现在做个 30 秒小动作，待办立刻少一项。"
                    ),
                    Prompt(
                        title: "你有 30 秒，对吧",
                        message: "不用起身，不必解释。安静做一轮小动作。"
                    ),
                    Prompt(
                        title: "别等完美时机",
                        message: "此刻就够了。用 30 秒完成一个小动作。"
                    ),
                ],
                followUp: [
                    Prompt(
                        title: "小动作不会自己完成",
                        message: "好消息是，它只占 30 秒。现在开始。"
                    ),
                    Prompt(
                        title: "第二次就别留悬念了",
                        message: "安静做一轮小动作，30 秒后各忙各的。"
                    ),
                    Prompt(
                        title: "不用再找空档",
                        message: "这个空档已经来了：30 秒，小动作，开始。"
                    ),
                ]
            )

        case (.quietPractice, .minimal):
            PromptPool(
                first: [
                    Prompt(title: "小动作", message: "安静练习 30 秒。"),
                    Prompt(title: "开始练习", message: "专注小动作 30 秒。"),
                    Prompt(title: "留半分钟", message: "完成一轮小动作。"),
                ],
                followUp: [
                    Prompt(title: "再次提醒", message: "现在做 30 秒小动作。"),
                    Prompt(title: "小动作时间", message: "安静完成一轮。"),
                    Prompt(title: "短暂练习", message: "30 秒，然后继续。"),
                ]
            )
        }
    }

    static func completionReceipt(
        for kind: ReminderKind,
        tone: ReminderCopyTone,
        guideDuration: TimeInterval? = nil
    ) -> ReminderReceiptCopy {
        let baseMessage: String = switch (kind, tone) {
        case (.eye, .gentle): "眼睛收到了这 20 秒的远方。"
        case (.eye, .dryHumor): "已与屏幕短暂解除绑定。"
        case (.eye, .sharp): "看吧，20 秒真的放得下。"
        case (.eye, .minimal): "望远完成。"
        case (.standing, .gentle): "这一分钟，身体好好收下了。"
        case (.standing, .dryHumor): "椅子的独处申请已办结。"
        case (.standing, .sharp): "这就对了，腿也该有点戏份。"
        case (.standing, .minimal): "站立完成。"
        case (.quietPractice, .gentle): "这一轮小动作完成得刚刚好。"
        case (.quietPractice, .dryHumor): "秘密任务完成，无人被打扰。"
        case (.quietPractice, .sharp): "小事已完成，不留给明天。"
        case (.quietPractice, .minimal): "练习完成。"
        }

        let title: String = switch tone {
        case .gentle: "完成啦"
        case .dryHumor: "顺利结案"
        case .sharp: "这就对了"
        case .minimal: "已完成"
        }

        return ReminderReceiptCopy(
            title: title,
            message: applyingGuideDuration(
                to: baseMessage,
                kind: kind,
                duration: resolvedGuideDuration(guideDuration, for: kind)
            ),
            dismissButton: "好"
        )
    }

    static func snoozeReceipt(
        delay: TimeInterval,
        tone: ReminderCopyTone
    ) -> ReminderReceiptCopy {
        let delayText = durationText(delay)

        switch tone {
        case .gentle:
            return ReminderReceiptCopy(
                title: "好，先忙手边的",
                message: "我会在 \(delayText)后轻轻回来。",
                dismissButton: "知道了"
            )
        case .dryHumor:
            return ReminderReceiptCopy(
                title: "延期申请已批准",
                message: "有效期 \(delayText)，到点重新出现。",
                dismissButton: "成交"
            )
        case .sharp:
            return ReminderReceiptCopy(
                title: "给你 \(delayText)",
                message: "时间到了我会回来，这次说定了。",
                dismissButton: "说定了"
            )
        case .minimal:
            return ReminderReceiptCopy(
                title: "已稍后提醒",
                message: "\(delayText)后再次出现。",
                dismissButton: "好"
            )
        }
    }

    static func skipReceipt(tone: ReminderCopyTone) -> ReminderReceiptCopy {
        switch tone {
        case .gentle:
            return ReminderReceiptCopy(
                title: "好，这次先跳过",
                message: "下一次提醒再见，照顾好自己的节奏。",
                dismissButton: "好"
            )
        case .dryHumor:
            return ReminderReceiptCopy(
                title: "本次已放行",
                message: "提醒收起道具，下一场再见。",
                dismissButton: "退场吧"
            )
        case .sharp:
            return ReminderReceiptCopy(
                title: "行，这次跳过",
                message: "我记的是结果，不记仇。下一次见。",
                dismissButton: "知道了"
            )
        case .minimal:
            return ReminderReceiptCopy(
                title: "已跳过",
                message: "等待下一次提醒。",
                dismissButton: "关闭"
            )
        }
    }

    static func durationText(_ duration: TimeInterval) -> String {
        let roundedSeconds = max(0, Int(duration.rounded()))
        if roundedSeconds >= 60, roundedSeconds.isMultiple(of: 60) {
            return "\(roundedSeconds / 60) 分钟"
        }
        return "\(roundedSeconds) 秒"
    }

    static func resolvedGuideDuration(
        _ duration: TimeInterval?,
        for kind: ReminderKind
    ) -> TimeInterval {
        guard let duration, duration.isFinite, duration > 0 else {
            return kind.guideDuration
        }
        return duration
    }

    static func applyingGuideDuration(
        to text: String,
        kind: ReminderKind,
        duration: TimeInterval
    ) -> String {
        let replacement = durationText(duration)
        let tokens: [String] = switch kind {
        case .eye:
            ["20 秒"]
        case .standing:
            ["60 秒", "1 分钟", "一分钟"]
        case .quietPractice:
            ["30 秒", "半分钟"]
        }

        return tokens.reduce(text) { result, token in
            result.replacingOccurrences(of: token, with: replacement)
        }
    }

    /// FNV-1a gives us a stable seed unlike Swift's intentionally randomized
    /// `hashValue` implementation.
    static func stableSeed(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    static func mixed(_ value: UInt64) -> UInt64 {
        var result = value &+ 0x9E37_79B9_7F4A_7C15
        result = (result ^ (result >> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result >> 27)) &* 0x94D0_49BB_1331_11EB
        return result ^ (result >> 31)
    }
}
