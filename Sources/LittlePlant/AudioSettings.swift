import Foundation
import Combine

extension Notification.Name {
    static let plantAudioChanged = Notification.Name("LittlePlant.audioChanged")
}

@MainActor
final class AudioSettings: ObservableObject {
    static let shared = AudioSettings()
    @Published var musicVolume: Double { didSet { save() } }
    @Published var effectsVolume: Double { didSet { save() } }
    @Published var rainEnabled: Bool { didSet { save() } }
    @Published var muted: Bool { didSet { save() } }
    private let defaults: UserDefaults
    private let notify: Bool
    init(defaults:UserDefaults = .standard,notify:Bool = true) {
        self.defaults = defaults; self.notify = notify
        musicVolume = Self.bounded(defaults.object(forKey:"audio.music") as? Double ?? 0.45)
        effectsVolume = Self.bounded(defaults.object(forKey:"audio.effects") as? Double ?? 1)
        rainEnabled = defaults.object(forKey:"audio.rainEnabled") as? Bool ?? true
        muted = defaults.bool(forKey:"audio.muted")
    }
    private static func bounded(_ value:Double) -> Double { value.isFinite ? min(1,max(0,value)) : 0 }
    var musicGain: Float { muted ? 0 : Float(Self.bounded(musicVolume)) }
    func effectsGain(_ base:Float) -> Float { muted ? 0 : base * Float(Self.bounded(effectsVolume)) }
    private func save() {
        defaults.set(Self.bounded(musicVolume),forKey:"audio.music")
        defaults.set(Self.bounded(effectsVolume),forKey:"audio.effects")
        defaults.set(muted,forKey:"audio.muted")
        defaults.set(rainEnabled,forKey:"audio.rainEnabled")
        if notify {
            BookPageSound.applyVolumes()
            NotificationCenter.default.post(name:.plantAudioChanged,object:self)
        }
    }
    static func verifyStorage() {
        let name = "LittlePlant.AudioChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let settings = AudioSettings(defaults:defaults,notify:false)
        precondition(settings.musicGain == 0.45 && settings.effectsGain(0.7) == 0.7)
        settings.musicVolume = 0.23; settings.effectsVolume = 0.4; settings.muted = true; settings.rainEnabled = false
        let restored = AudioSettings(defaults:defaults,notify:false)
        precondition(!restored.rainEnabled && restored.muted && restored.musicGain == 0 && restored.effectsGain(0.7) == 0)
        restored.muted = false
        precondition(abs(restored.musicGain-0.23)<0.001 && abs(restored.effectsGain(0.7)-0.28)<0.001,"Unmute must restore independent volumes")
        restored.musicVolume = 2; restored.effectsVolume = -1
        precondition(restored.musicGain == 1 && restored.effectsGain(0.7) == 0,"Volumes must stay bounded")
        fputs("PASS: separate audio gains, mute/unmute restoration, settings persistence and bounds\n",stderr)
    }
}
