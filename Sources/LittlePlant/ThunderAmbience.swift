import Foundation
import AVFoundation
import PlantCore

/// Independent of the room view, so hiding the window does not interrupt weather audio.
@MainActor
final class ThunderAmbience {
    private let settings:AudioSettings
    private let runsTimer:Bool
    private var player:AVAudioPlayer?
    private var timer:Timer?
    private var observer:NSObjectProtocol?
    private var windowOpen = false
    private var lastStrike:Int?
    private(set) var startDate:Date?
    init(settings:AudioSettings? = nil,runsTimer:Bool = true) {
        self.settings = settings ?? .shared; self.runsTimer = runsTimer
        observer = NotificationCenter.default.addObserver(forName:.plantAudioChanged,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.applyVolume() }
        }
    }
    func updateWeather(storm:Bool,windowOpen:Bool) {
        self.windowOpen = windowOpen
        if storm, startDate == nil {
            startDate = Date(); lastStrike = nil
            if runsTimer {
                timer = Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
            }
        } else if !storm {
            startDate = nil; timer?.invalidate(); timer = nil; lastStrike = nil
            player?.stop(); player?.currentTime = 0
        }
        applyVolume()
    }
    func updateWindow(open:Bool) { windowOpen = open; applyVolume() }
    private var gain:Float { settings.effectsGain(windowOpen ? 0.65 : 0.32) }
    private func applyVolume() {
        if gain <= 0 { player?.stop() }
        else if player?.isPlaying == true { player?.setVolume(gain,fadeDuration:0.15) }
        else { player?.volume = gain }
    }
    private func tick(now:Date = Date()) {
        guard let startDate else { return }
        let sample = StormTimeline.sample(elapsed:now.timeIntervalSince(startDate))
        // Only the current sound window is eligible; never replay missed strikes after sleep.
        guard sample.thunderReady, sample.strike != lastStrike else { return }
        lastStrike = sample.strike
        guard gain > 0 else { return }
        if player == nil {
            let url = Bundle.main.url(forResource:"thunder",withExtension:"wav",subdirectory:"Sounds") ?? Bundle.module.url(forResource:"thunder",withExtension:"wav")
            player = url.flatMap { try? AVAudioPlayer(contentsOf:$0) }
            player?.prepareToPlay()
        }
        player?.stop(); player?.currentTime = 0; player?.volume = gain; player?.play()
    }
    static func verify() {
        let name = "LittlePlant.ThunderChecks."+UUID().uuidString
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let settings = AudioSettings(defaults:defaults,notify:false)
        let audio = ThunderAmbience(settings:settings,runsTimer:false)
        audio.updateWeather(storm:true,windowOpen:false)
        let epoch = audio.startDate!
        audio.tick(now:epoch.addingTimeInterval(2.3))
        precondition(audio.player == nil,"Thunder must wait until after lightning")
        audio.tick(now:epoch.addingTimeInterval(3.3))
        precondition(audio.player?.isPlaying == true && (audio.player?.duration ?? 0)>4)
        precondition(abs((audio.player?.volume ?? 0)-0.32)<0.001)
        settings.effectsVolume = 0.5; audio.applyVolume()
        audio.updateWindow(open:true)
        precondition(audio.lastStrike == 0)
        settings.muted = true; audio.applyVolume()
        precondition(audio.player?.isPlaying == false)
        audio.tick(now:epoch.addingTimeInterval(17.6))
        precondition(audio.lastStrike == 1 && audio.player?.isPlaying == false)
        settings.muted = false; audio.applyVolume()
        audio.tick(now:epoch.addingTimeInterval(17.6))
        precondition(audio.player?.isPlaying == false,"Unmuting must not replay a missed thunder")
        audio.updateWeather(storm:false,windowOpen:false)
        precondition(audio.startDate == nil && audio.player?.isPlaying == false)
        audio.updateWeather(storm:true,windowOpen:true)
        audio.tick(now:audio.startDate!.addingTimeInterval(3.3))
        precondition(audio.player?.isPlaying == true && abs((audio.player?.volume ?? 0)-0.325)<0.001)
        audio.updateWeather(storm:false,windowOpen:false)
        fputs("PASS: synthesized thunder decoding, lightning delay, one sound per strike, window/effects gains, mute, no stale replay and weather-change stop\n",stderr)
    }
    deinit {
        timer?.invalidate(); player?.stop()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }
}
