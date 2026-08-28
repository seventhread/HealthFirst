import AppKit
import HealthFirstCore

enum ReminderSoundPolicy {
    static func shouldPlay(
        isEnabled: Bool,
        userInitiated: Bool,
        state: ReminderState?
    ) -> Bool {
        guard isEnabled, !userInitiated, let state else { return false }

        return switch state {
        case .firstPresented, .followUpPresented, .seriousPresented:
            true
        default:
            false
        }
    }
}

/// Plays a quiet built-in macOS sound. There is deliberately no alert-beep
/// fallback: if the named system sounds are unavailable, silence is kinder
/// than substituting the user's potentially loud warning sound.
@MainActor
final class ReminderSoundPlayer {
    private let sound: NSSound?

    init() {
        sound = NSSound(named: NSSound.Name("Pop"))
            ?? NSSound(named: NSSound.Name("Tink"))
    }

    func play() {
        sound?.stop()
        sound?.play()
    }
}
