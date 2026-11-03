import AppKit

/// A bundled, quiet paper rustle; retain playback for the full page turn.
@MainActor
enum BookPageSound {
    private static let sound: NSSound? = {
        guard let url = Bundle.main.url(forResource:"page-turn",withExtension:"wav",subdirectory:"Sounds")
                ?? Bundle.module.url(forResource:"page-turn",withExtension:"wav") else { return nil }
        let sound = NSSound(contentsOf:url,byReference:false)
        sound?.volume = 0.55
        return sound
    }()
    private static let closingSound: NSSound? = {
        guard let url = Bundle.main.url(forResource:"book-close",withExtension:"wav",subdirectory:"Sounds")
                ?? Bundle.module.url(forResource:"book-close",withExtension:"wav") else { return nil }
        let sound = NSSound(contentsOf:url,byReference:false); sound?.volume = 0.7
        return sound
    }()
    static func applyVolumes() {
        sound?.volume = AudioSettings.shared.effectsGain(0.55)
        closingSound?.volume = AudioSettings.shared.effectsGain(0.7)
    }
    static func playClose() { applyVolumes(); sound?.stop(); closingSound?.stop(); closingSound?.play() }
    static func verify() {
        precondition(closingSound != nil && (closingSound?.duration ?? 0) > 0.2,"Bundled cover thud must decode")
        precondition(sound != nil && (sound?.duration ?? 0) > 0.5, "Bundled paper sound must decode")
    }
    static func play() { applyVolumes(); sound?.stop(); sound?.play() }
    static func stop() { sound?.stop(); closingSound?.stop() }
}
