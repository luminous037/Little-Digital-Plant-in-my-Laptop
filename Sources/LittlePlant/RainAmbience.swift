import Foundation
import AVFoundation

/// Weather ambience is independent of the CD player and follows the effects channel.
@MainActor
final class RainAmbience {
    private let settings: AudioSettings
    private var raining = false
    private var windowOpen = false
    private var player: AVAudioPlayer?
    private var observer: NSObjectProtocol?
    init(settings:AudioSettings? = nil) {
        self.settings = settings ?? .shared
        observer = NotificationCenter.default.addObserver(forName:.plantAudioChanged,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.synchronize() }
        }
    }
    func updateWeather(raining:Bool,windowOpen:Bool? = nil) {
        self.raining = raining
        if let windowOpen { self.windowOpen = windowOpen }
        synchronize()
    }
    func updateWindow(open:Bool) {
        guard windowOpen != open else { return }
        windowOpen = open; synchronize()
    }
    private func synchronize() {
        guard raining else { player?.stop(); player?.currentTime = 0; return }
        let gain = settings.effectsGain(windowOpen ? 0.75 : 0.4)
        guard settings.rainEnabled, !settings.muted, gain > 0 else { player?.pause(); return }
        if player == nil {
            // The source waveform is amplified 2×, preserving both window gains without clamping at volume 1.
            let url = Bundle.main.url(forResource:"rain_sound_louder",withExtension:"m4a",subdirectory:"Sounds") ?? Bundle.module.url(forResource:"rain_sound_louder",withExtension:"m4a")
            player = url.flatMap { try? AVAudioPlayer(contentsOf:$0) }
            player?.numberOfLoops = -1; player?.prepareToPlay()
        }
        if player?.isPlaying == true { player?.setVolume(gain,fadeDuration:0.35) }
        else { player?.volume = gain; player?.play() }
    }
    static func verify() async {
        let name = "LittlePlant.RainChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName:name)!
        defer { defaults.removePersistentDomain(forName:name) }
        let settings = AudioSettings(defaults:defaults,notify:false)
        let rain = RainAmbience(settings:settings)
        defer { rain.updateWeather(raining:false) }
        rain.updateWeather(raining:true)
        precondition(rain.player?.isPlaying == true && rain.player?.numberOfLoops == -1 && (rain.player?.duration ?? 0)>1,"Rain audio must decode, play and loop")
        settings.rainEnabled = false; rain.synchronize()
        precondition(rain.player?.isPlaying == false,"Rain switch must stop ambience")
        settings.rainEnabled = true; rain.synchronize()
        precondition(rain.player?.isPlaying == true,"Rain switch must resume during rain")
        settings.muted = true; rain.synchronize()
        precondition(rain.player?.isPlaying == false,"Global mute must silence rain")
        settings.muted = false; settings.effectsVolume = 0; rain.synchronize()
        precondition(rain.player?.isPlaying == false,"Zero effects volume must silence rain")
        settings.effectsVolume = 0.5; rain.synchronize()
        precondition(rain.player?.isPlaying == true && abs((rain.player?.volume ?? -1)-0.2)<0.001,"Rain must follow effects volume")
        rain.updateWindow(open:true)
        do { try await Task.sleep(nanoseconds:450_000_000) } catch { return }
        precondition(rain.player?.isPlaying == true && abs((rain.player?.volume ?? -1)-0.375)<0.01,"Opening the window must smoothly increase rain volume")
        rain.updateWindow(open:false)
        do { try await Task.sleep(nanoseconds:450_000_000) } catch { return }
        precondition(abs((rain.player?.volume ?? -1)-0.2)<0.01,"Closing the window must restore the quieter volume")
        rain.updateWeather(raining:false)
        precondition(rain.player?.isPlaying == false && rain.player?.currentTime == 0,"Rain must stop when weather clears")
        rain.updateWindow(open:true)
        precondition(rain.player?.isPlaying == false,"An open window must not play rain in clear weather")
        rain.updateWeather(raining:true)
        precondition(abs((rain.player?.volume ?? -1)-0.375)<0.001,"New rain must use the current window state")
        fputs("PASS: doubled rain audio playback/loop, switch off/on, mute, effects volume, window open/close fades, clear-weather stop\n",stderr)
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) }; player?.stop() }
}
