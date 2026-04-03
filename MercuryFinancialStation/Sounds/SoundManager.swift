import Foundation
import AudioToolbox

enum SoundEffect: String, CaseIterable {
    case leverStep = "sfx_lever_step"
    case coilRotate = "sfx_coil_rotate"
    case pointClick = "sfx_point_click"
}

actor SoundManager {
    static let shared = SoundManager()

    private var sounds: [SoundEffect: SystemSoundID] = [:]
    private var isEnabled = true

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            stopAll()
        }
    }

    func preloadAllEffects() {
        for effect in SoundEffect.allCases {
            _ = soundID(for: effect)
        }
    }

    func play(_ effect: SoundEffect) {
        guard isEnabled else {
            return
        }

        guard let soundID = soundID(for: effect) else {
            return
        }
        AudioServicesPlaySystemSound(soundID)
    }

    func stopAll() {
        for soundID in sounds.values {
            AudioServicesDisposeSystemSoundID(soundID)
        }
        sounds.removeAll()
    }

    private func soundID(for effect: SoundEffect) -> SystemSoundID? {
        if let existing = sounds[effect] {
            return existing
        }

        guard let url = soundURL(for: effect) else {
            return nil
        }

        var soundID: SystemSoundID = 0
        let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        guard status == kAudioServicesNoError else {
            return nil
        }
        sounds[effect] = soundID
        return soundID
    }

    private func soundURL(for effect: SoundEffect) -> URL? {
        let extensions = ["wav", "caf", "aif", "aiff", "m4a", "mp3"]
        let subdirectories: [String?] = [nil, "Sounds", "helpers"]

        for fileExtension in extensions {
            for subdirectory in subdirectories {
                if let url = Bundle.main.url(
                    forResource: effect.rawValue,
                    withExtension: fileExtension,
                    subdirectory: subdirectory
                ) {
                    return url
                }
            }
        }
        return nil
    }
}
