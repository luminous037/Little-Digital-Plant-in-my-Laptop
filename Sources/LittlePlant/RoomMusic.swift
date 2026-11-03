import AppKit
import AVFoundation

struct RoomTrack: Identifiable {
    let id: String
    let title: String
    let file: String
    var fileExtension = "mp3"
    enum Palette { case sage, lavender, yellow }
    let palette: Palette
    static let library = [
        RoomTrack(id:"cozy-room",title:"my cozy room",file:"my cozy room",palette:.sage),
        RoomTrack(id:"dreamy-mode",title:"Moonlit Notes",file:"Moonlit Notes",fileExtension:"m4a",palette:.lavender),
        RoomTrack(id:"tomato-farm",title:"Apricot Afternoon",file:"Apricot Afternoon",fileExtension:"m4a",palette:.yellow)
    ]
}

@MainActor
final class RoomMusic: ObservableObject {
    enum Phase { case shelf, album, disc, inserting, loaded, returning }
    @Published private(set) var phase: Phase = .shelf
    @Published private(set) var playing = false
    @Published private(set) var error: String?
    @Published private(set) var track = RoomTrack.library[0]
    private(set) var transitionStart = Date()
    private var player: AVAudioPlayer?
    private var transit: Task<Void,Never>?
    private var volumeObserver: NSObjectProtocol?
    init() {
        volumeObserver = NotificationCenter.default.addObserver(forName:.plantAudioChanged,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.applyVolume() }
        }
    }
    private func applyVolume() {
        player?.volume = AudioSettings.shared.musicGain
        click?.volume = AudioSettings.shared.effectsGain(0.6)
    }
    private let click: NSSound? = {
        let url = Bundle.main.url(forResource:"player-click",withExtension:"wav",subdirectory:"Sounds") ?? Bundle.module.url(forResource:"player-click",withExtension:"wav")
        return url.flatMap { NSSound(contentsOf:$0,byReference:false) }
    }()
    var presenting: Bool { phase == .album || phase == .disc }
    var flying: Bool { phase == .inserting || phase == .returning }
    func selectAlbum(id:String? = nil) {
        guard phase == .shelf else { return }
        let selected = RoomTrack.library.first { $0.id == (id ?? track.id) }
        guard let selected else { return }
        if selected.id != track.id {
            player?.stop(); player = nil; playing = false; error = nil
            track = selected
        }
        phase = .album
    }
    func selectPresented() {
        switch phase {
        case .album: phase = .disc
        case .disc: move(to:.inserting,then:.loaded)
        default: break
        }
    }
    func dismissAlbum() { if presenting { phase = .shelf } }
    func eject() {
        guard phase == .loaded, !playing else { return }
        player?.stop(); player?.currentTime = 0
        move(to:.returning,then:.shelf)
    }
    private func move(to phase:Phase,then destination:Phase) {
        transitionStart = Date(); self.phase = phase
        transit = Task { @MainActor in
            do { try await Task.sleep(nanoseconds:1_800_000_000) } catch { return }
            self.phase = destination
        }
    }
    func pullCord() {
        applyVolume(); click?.stop(); click?.play()
        guard phase == .loaded else { return }
        if playing { player?.pause(); playing = false; return }
        do {
            if player == nil {
                guard let url = Bundle.main.url(forResource:track.file,withExtension:track.fileExtension,subdirectory:"Music") ?? Bundle.module.url(forResource:track.file,withExtension:track.fileExtension) else { throw CocoaError(.fileNoSuchFile) }
                player = try AVAudioPlayer(contentsOf:url)
                player?.numberOfLoops = -1; player?.volume = AudioSettings.shared.musicGain; player?.prepareToPlay()
            }
            playing = player?.play() == true
            if !playing { throw CocoaError(.fileReadUnknown) }
            error = nil
        } catch { self.error = "음원을 재생할 수 없습니다. / Unable to play audio."; playing = false }
    }
    func verifyWorkflow() async {
        for selected in RoomTrack.library {
            precondition(phase == .shelf)
            selectAlbum(id:selected.id); precondition(phase == .album && track.id == selected.id)
            verifyAudio()
            selectPresented(); precondition(phase == .disc)
            selectPresented(); precondition(phase == .inserting)
            do { try await Task.sleep(nanoseconds:2_000_000_000) } catch { return }
            precondition(phase == .loaded && !playing,"Insertion must finish paused")
            pullCord(); precondition(playing && error == nil,"Pull must play the selected track")
            precondition(player?.url?.lastPathComponent == selected.file+"."+selected.fileExtension,"Changing CDs must change the actual audio file")
            let other = RoomTrack.library.first { $0.id != selected.id }!
            selectAlbum(id:other.id)
            precondition(track.id == selected.id && phase == .loaded,"Only one CD can occupy the player")
            eject(); precondition(phase == .loaded,"A spinning disc must not eject")
            pullCord(); precondition(!playing,"Second pull must pause")
            eject(); precondition(phase == .returning)
            do { try await Task.sleep(nanoseconds:2_000_000_000) } catch { return }
            precondition(phase == .shelf && !playing,"Disc must return to its own album")
        }
        fputs("PASS: all three CDs select/extract/insert/play/pause/return, correct MP3 switching and occupied-player guard\n",stderr)
    }
    func verifyLiveVolumes() {
        let audio = AudioSettings.shared
        let saved = (audio.musicVolume,audio.effectsVolume,audio.muted)
        defer {
            audio.musicVolume = saved.0; audio.effectsVolume = saved.1; audio.muted = saved.2
            player?.stop(); player = nil; applyVolume()
        }
        guard let url = Bundle.main.url(forResource:track.file,withExtension:track.fileExtension,subdirectory:"Music") ?? Bundle.module.url(forResource:track.file,withExtension:track.fileExtension) else { preconditionFailure("Missing audio") }
        player = try! AVAudioPlayer(contentsOf:url)
        audio.muted = false; audio.musicVolume = 0.23; audio.effectsVolume = 0.4
        applyVolume()
        precondition(abs((player?.volume ?? -1)-0.23)<0.001 && abs((click?.volume ?? -1)-0.24)<0.001)
        audio.muted = true; applyVolume()
        precondition(player?.volume == 0 && click?.volume == 0,"Mute must silence both channels")
        fputs("PASS: live music/effect volume and global mute applied to audio players\n",stderr)
    }
    func verifyAudio() {
        guard let url = Bundle.main.url(forResource:track.file,withExtension:track.fileExtension,subdirectory:"Music") ?? Bundle.module.url(forResource:track.file,withExtension:track.fileExtension),
              let test = try? AVAudioPlayer(contentsOf:url) else { preconditionFailure("Bundled music must decode") }
        precondition(test.duration > 1 && click != nil,"Track and mechanical click must be bundled")
    }
    deinit { if let volumeObserver { NotificationCenter.default.removeObserver(volumeObserver) }; transit?.cancel(); player?.stop() }
}
