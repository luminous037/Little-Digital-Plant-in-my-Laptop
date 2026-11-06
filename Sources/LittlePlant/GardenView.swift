import SwiftUI
import PlantCore

private let graphite = Color(red: 0.39, green: 0.42, blue: 0.43)
private let mint = Color(red: 0.31, green: 0.85, blue: 0.65)
private enum Tray: String, Identifiable { case care, weather, settings, adopt; var id: String { rawValue } }

/// The room is the home screen. Everything else lives in the four HOME-style tiles.
struct GardenView: View {
    @ObservedObject var store: GardenStore
    @ObservedObject private var music: RoomMusic
    @ObservedObject private var photos: PhotoLibrary
    @StateObject private var camera = RoomCamera()
    init(store:GardenStore) { self.store = store; self.music = store.music; self.photos = store.photos }
    @State private var tray: Tray?
    @State private var showCare = false
    @State private var showBook = false
    @State private var showPhotoBook = false
    @State private var pendingPhoto: PhotoDraft?
    @State private var photoBusy = false
    @State private var photoFlash = 0.0
    @State private var photoScale = 0.7
    @State private var photoOffset = CGSize(width:0,height:30)
    @State private var photoOpacity = 0.0
    @State private var photoAngle = -4.0
    @State private var captureTask: Task<Void,Never>?
    @State private var reset = false
    @State private var guide = false
    @State private var feedback: String?
    @State private var editingName = false
    @State private var nameDraft = ""
    @FocusState private var nameFocused: Bool
    private func t(_ ko: String, _ en: String) -> String { store.t(ko, en) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Spacer()
                ForEach(0..<5) { _ in Capsule().fill(Color.black.opacity(0.14)).frame(width: 3, height: 3) }
                Spacer()
            }.frame(height: 15).overlay(alignment: .trailing) {
                Circle().fill(store.simulation || store.loading ? Color(red: 0.85, green: 0.68, blue: 0.28) : (store.hasLiveWeather ? mint : .red))
                    .frame(width: 4, height: 4).shadow(color: mint.opacity(0.3), radius: 2).padding(.trailing, 17)
                    .accessibilityLabel(store.simulation ? t("시뮬레이션", "Simulation") : t("실시간 날씨", "Live weather"))
            }
            ZStack(alignment: .bottom) {
                RoomScene(plant: store.plant, climate: store.climate,
                          wateringMode: store.wateringMode, pruningMode: store.pruningMode, onPruneLeaf: store.pruneLeaf, onSoilWater: store.waterFromStream, onWateringEnd: store.save,
                          onBackgroundTap: { showCare = false },
                          onWindowTap: { if store.plant.adopted { perform("wind", store.toggleWindow) } },
                          onPlantTap: openCare, onBookTap: openBook, interactionsEnabled: !showBook && !showPhotoBook && pendingPhoto == nil && !photoBusy, music:music, onAlbumTap:openAlbum, skyHour:store.simulation ? (store.climate.daylight ? 8 : 22) : Calendar.autoupdatingCurrent.component(.hour,from:Date()), fertilizerPulse:store.fertilizerPulse, hasPhotoAlbum:photos.hasAlbum, onPhotoAlbumTap:openPhotoBook, camera:camera, stormEpoch:store.stormStart)
                    .help(store.pruningMode ? t("노랗거나 마른 잎을 눌러 잘라 주세요.", "Click a yellow or dried leaf to snip it.") : (store.wateringMode ? t("물뿌리개를 잡고 흙 위로 드래그하세요.", "Grab the can and drag its spray over the soil.") : t("식물·창문·책·CD를 눌러 보세요. 플레이어 줄을 클릭해 주세요.", "Click the plant, window, book or CD. Click the player cord.")))
                    .accessibilityLabel(t("식물과 창문, 책장", "Plant, window and bookshelf"))
                    .accessibilityAction(named:Text("my cozy room")) { openAlbum("cozy-room") }
                    .accessibilityAction(named:Text("Pillowcase Moon")) { openAlbum("dreamy-mode") }
                    .accessibilityAction(named:Text("Starlight Through the Blinds")) { openAlbum("tomato-farm") }
                    .accessibilityAction(named:Text(t("플레이어 줄 클릭", "Click player cord"))) { music.pullCord() }
                    .accessibilityAction(named:Text(t("정지한 CD 꺼내기", "Return stopped CD"))) { music.eject() }
                    .accessibilityAction(named:Text(t("사진 앨범 열기", "Open photo album"))) { if photos.hasAlbum { openPhotoBook() } }
                    .accessibilityAction(named:Text(t("돌봄 책 열기", "Open care book"))) { openBook() }
                    .accessibilityAction(named: Text(t("창문 열고 닫기", "Toggle window"))) { if store.plant.adopted { perform("wind", store.toggleWindow) } }
                    .accessibilityAction(named: Text(t("식물 돌보기", "Care for plant"))) { openCare() }
                if !store.plant.adopted {
                    Button { tray = .adopt } label: { Image(systemName: "leaf.arrow.triangle.circlepath").font(.system(size: 22, weight: .medium)).foregroundStyle(Color(red: 0.38, green: 0.64, blue: 0.30)).frame(width: 52, height: 38) }
                        .buttonStyle(PlasticButton()).help(t("몬스테라 입양하기", "Adopt a monstera"))
                        .accessibilityLabel(t("몬스테라 입양하기", "Adopt a monstera")).padding(.bottom, 14)
                }
                if let feedback {
                    Image(systemName: feedback).font(.system(size: 25, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(graphite.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
                        .padding(.bottom, 20).allowsHitTesting(false).transition(.opacity)
                }
            }
            .frame(height: 322)
            .clipped()
            .overlay(alignment: .topLeading) {
                digitalReadout.padding(14).allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Button { showCare = false; tray = tray == .settings ? nil : .settings } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(graphite.gradient)
                            .shadow(color: .white, radius: 0, y: 1)
                            .frame(width: 28, height: 28).contentShape(Rectangle())
                    }
                    .buttonStyle(PlasticButton())
                    .help(t("설정", "Settings")).accessibilityLabel(t("설정", "Settings"))
                    .popover(isPresented:settingsPresented,attachmentAnchor:.rect(.bounds),arrowEdge:.top) {
                        panel(.settings).frame(width:286).padding(16).background(Color(white:0.95))
                            .foregroundStyle(graphite).preferredColorScheme(.light)
                    }
                    if !store.plant.prunableLeafIDs.isEmpty {
                        Button { showCare = false; store.startPruning() } label: {
                            Image(systemName: "scissors").font(.system(size: 16)).modifier(HUDOutline())
                                .frame(width: 28, height: 28)
                                .background(store.pruningMode ? Color.black.opacity(0.22) : .clear, in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain)
                            .help(t("가위: 노랗거나 마른 잎을 선택하세요", "Scissors: select a yellow or dried leaf"))
                            .accessibilityLabel(t("가위로 잎 자르기", "Prune damaged leaves"))
                    }
                }.padding(8)
            }
            .overlay(alignment: .bottomTrailing) {
                if showCare && store.plant.adopted {
                    careBubble.frame(width: 264).padding(8).transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .bottomLeading)))
                }
            }
            .overlay(alignment: .bottom) {
                if store.wateringMode {
                    HStack {
                        Label("\(Int(store.plant.moisture))%", systemImage: "drop.fill")
                            .font(.custom(RetroFonts.clock, size: 14)).modifier(HUDOutline()).allowsHitTesting(false)
                        Spacer()
                        Button { store.wateringMode = false } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 20)).modifier(HUDOutline())
                        }.buttonStyle(.plain).help(t("물뿌리개 치우기 · Esc", "Put away watering can · Esc")).accessibilityLabel(t("물뿌리개 치우기", "Put away watering can"))
                    }.padding(12)
                } else if store.pruningMode {
                    HStack {
                        Label(t("자를 잎을 클릭", "Click a damaged leaf"), systemImage: "scissors")
                            .font(.system(size: 10)).modifier(HUDOutline()).allowsHitTesting(false)
                        Spacer()
                        Button { store.pruningMode = false } label: {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 20)).modifier(HUDOutline())
                        }.buttonStyle(.plain).accessibilityLabel(t("가위 치우기", "Put away scissors"))
                    }.padding(12)
                }
            }
            .overlay(Rectangle().strokeBorder(Color(white: 0.58), lineWidth: 1))
            .overlay(Rectangle().strokeBorder(.white.opacity(0.7), lineWidth: 1).padding(1))
            .padding(.horizontal, 10)
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.66), .white, Color(white: 0.88)], startPoint: .top, endPoint: .bottom)).frame(height: 5).padding(.top, 6)
            HStack(spacing: 30) {
                homeTile("leaf.fill", .green, .care, t("돌봄", "Care"))
                homeTile(weatherSymbol, .cyan, .weather, t("날씨", "Weather"))
                Button(action:takePhoto) {
                    Image(systemName:"camera.fill").font(.system(size:27,weight:.regular)).foregroundStyle(Color.gray.gradient)
                        .shadow(color:.white,radius:0,y:1).frame(width:55,height:52)
                }.buttonStyle(PlasticButton()).help(t("사진 찍기", "Take photo")).accessibilityLabel(t("사진 찍기", "Take photo"))
                    .disabled(photoBusy || pendingPhoto != nil)
            }.frame(maxWidth: .infinity).padding(.vertical, 16).background(Color(white: 0.95))
        }
        .background(LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2))
        .foregroundStyle(graphite).preferredColorScheme(.light)
        .overlay {
            if showBook {
                ZStack {
                    Color.black.opacity(0.26).contentShape(Rectangle()).onTapGesture { closeBook() }
                    CareBookView(english:store.english,onClose:closeBook).onTapGesture {}
                        .transition(.opacity.combined(with:.scale(scale:0.92)))
                }.clipShape(RoundedRectangle(cornerRadius:12))
            } else if showPhotoBook {
                ZStack {
                    Color.black.opacity(0.26).contentShape(Rectangle()).onTapGesture { showPhotoBook = false }
                    CareBookView(english:store.english,onClose:{ showPhotoBook = false },isPhotoAlbum:true).onTapGesture {}
                }.clipShape(RoundedRectangle(cornerRadius:12))
            } else if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "audio-settings" {
                panel(.settings).frame(width:286).padding(16).background(Color(white:0.95),in:RoundedRectangle(cornerRadius:10)).shadow(radius:8)
            }
        }
        .overlay {
            GeometryReader { geometry in
                ZStack {
                    if let pendingPhoto {
                        Color.black.opacity(0.18).ignoresSafeArea()
                        Button { storePhoto(in:geometry.size) } label: {
                            Image(nsImage:PolaroidGraphic.card(scene:pendingPhoto.scene,record:pendingPhoto.record))
                                .interpolation(.none).resizable().scaledToFit().frame(width:240,height:264)
                                .shadow(color:.black.opacity(0.3),radius:9,x:3,y:6)
                        }.buttonStyle(.plain).disabled(photoBusy)
                            .scaleEffect(photoScale).rotationEffect(.degrees(photoAngle)).offset(photoOffset).opacity(photoOpacity)
                            .accessibilityLabel(t("사진을 앨범에 보관", "Store photo in album"))
                    }
                    Color.white.opacity(photoFlash).allowsHitTesting(false)
                }.frame(width:geometry.size.width,height:geometry.size.height)
            }.allowsHitTesting(pendingPhoto != nil)
        }
        .overlay(alignment:.top) {
            if let error = photos.error {
                HStack { Text(error).font(.system(size:10)); Button { photos.error = nil } label: { Image(systemName:"xmark") } }
                    .padding(9).background(.regularMaterial,in:RoundedRectangle(cornerRadius:8)).padding(12)
            }
        }
        .overlay(alignment:.bottom) {
            if music.presenting {
                Button { music.dismissAlbum() } label: {
                    Image(systemName:"xmark.circle.fill").font(.system(size:20)).modifier(HUDOutline())
                }.buttonStyle(.plain).padding(.bottom,90).accessibilityLabel(t("앨범 내려놓기", "Put album away"))
            }
            if let error = music.error { Text(error).font(.system(size:10)).padding(8).background(.regularMaterial) }
        }
        .onExitCommand {
            if editingName { cancelNameEdit() }
            else if pendingPhoto != nil && !photoBusy { pendingPhoto = nil }
            else { music.dismissAlbum(); showPhotoBook = false; showBook = false; store.wateringMode = false; store.pruningMode = false; showCare = false; tray = nil }
        }
        .onDisappear { captureTask?.cancel(); pendingPhoto = nil; photoBusy = false; photoFlash = 0 }
        .onChange(of:showCare) { visible in if !visible { cancelNameEdit() } }
        .task {
            guard CommandLine.arguments.contains("--render-preview") else { return }
            let scenario = ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"]
            if ["photo-card","photo-flow","photo-album","photo-album-open","photo-book-cycle","photo-enlarged"].contains(scenario ?? ""), let image = camera.capture() {
                try? PhotoLibrary.verify(scene:image)
                store.verifyWeatherCombinations()
                if scenario == "photo-card" { takePhoto() }
                if scenario == "photo-flow" {
                    let count = photos.entries.count
                    takePhoto()
                    try? await Task.sleep(nanoseconds:700_000_000)
                    precondition(pendingPhoto != nil,"Camera must reveal a card")
                    storePhoto(in:CGSize(width:420,height:432))
                    try? await Task.sleep(nanoseconds:1_300_000_000)
                    precondition(pendingPhoto == nil && photos.entries.count == count+1 && photos.hasAlbum,"Click must store the card and reveal the album book")
                    precondition(camera.albumPoint() != nil,"Photo album must appear on the shelf")
                    fputs("PASS: camera flash/card, photo save/fly-to-book and album creation\n",stderr)
                }
                if ["photo-album","photo-album-open","photo-book-cycle","photo-enlarged"].contains(scenario ?? "") {
                    for index in 0..<3 {
                        if let draft = try? PhotoLibrary.draft(scene:image,name:store.english ? "Monstera \(index+1)" : "몬스테라 \(index+1)",date:Date().addingTimeInterval(Double(index-2)*86400)) { _ = photos.save(draft) }
                    }
                    showPhotoBook = true
                }
            }
            if scenario == "docs-weather" { try? await Task.sleep(nanoseconds:350_000_000); tray = .weather }
            if scenario == "sleep-clock" { await store.verifySleepProgression() }
            if scenario == "photo-empty" { openPhotoBook() }
            if scenario == "fertilizer" { store.feed() }
            if scenario == "plant-name-edit" { showCare = true; startNameEdit() }
            if scenario == "plant-name-saved" { _ = store.renamePlant("초록이 🌱"); showCare = true }
            if scenario == "weather-effects" {
                store.verifyWeatherCombinations(); PixelSnowNode.verify(); LightningNode.verify(); ThunderAmbience.verify()
                store.setPreset("snow-night")
            }
            if scenario == "snow-day" { store.setPreset("snow") }
            if scenario == "snow-night" { store.setPreset("snow-night") }
            if scenario == "storm-flash" { store.setPreset("storm-night") }
            if scenario == "simulation-effects" { store.setPreset("storm"); try? await Task.sleep(nanoseconds:350_000_000); tray = .weather }
            if scenario == "drizzle-code" { store.climate = Climate(temperature:17,humidity:94,cloud:90,weatherCode:51) }
            if scenario == "rain-animation" { PixelRainNode.verify(); store.setPreset("rain") }
            if scenario == "rain-animation-night" { PixelRainNode.verify(); store.setPreset("rain-night") }
            if scenario == "pixel-sky" { PixelSky.verify() }
            if scenario == "rain-audio" { await RainAmbience.verify(); store.setPreset("rain") }
            if scenario == "weather-fallback" { store.verifyWeatherFallback() }
            if scenario == "audio-settings" {
                AudioSettings.verifyStorage()
                music.verifyLiveVolumes()
            }
            if scenario == "music-cycle" { await music.verifyWorkflow() }
            if scenario == "tomato-disc" { music.selectAlbum(id:"tomato-farm"); music.selectPresented() }
            if scenario == "dreamy-album" { music.selectAlbum(id:"dreamy-mode") }
            if scenario == "dreamy-disc" { music.selectAlbum(id:"dreamy-mode"); music.selectPresented() }
            if scenario == "dreamy-loaded" {
                music.selectAlbum(id:"dreamy-mode"); music.selectPresented(); music.selectPresented()
            }
            if scenario == "music-album" { music.selectAlbum() }
            if scenario == "music-disc" { music.selectAlbum(); music.selectPresented() }
            if scenario == "music-loaded" {
                music.selectAlbum(); music.selectPresented(); music.selectPresented()
            }
        }
        .onAppear {
            store.tick()
            if CommandLine.arguments.contains("--render-preview"), ["book", "book-cover-cycle", "book-closing", "book-opening", "book-opening-test", "book-open", "book-about", "book-turn", "book-curl", "book-curl-back"].contains(ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] ?? "") { showBook = true }
            if CommandLine.arguments.contains("--render-preview"), ["care", "leaf-fertilizer-zero", "plant-name-edit", "plant-name-saved"].contains(ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] ?? "") { showCare = true }
        }
        .popover(item: lowerTray, arrowEdge: .bottom) { selected in
            panel(selected).frame(width: 286).padding(16).background(Color(white: 0.95)).foregroundStyle(graphite).preferredColorScheme(.light)
        }
        .alert(t("새로 입양할까요?", "Start over?"), isPresented: $reset) {
            Button(t("취소", "Cancel"), role: .cancel) {}
            Button(t("새로 시작", "Start over"), role: .destructive) { store.running = false; store.wateringMode = false; store.pruningMode = false; showCare = false; store.plant = Plant(); store.save(); tray = nil }
        } message: { Text(t("현재 식물의 기록이 초기화됩니다.", "This resets your current plant.")) }
    }
    private func takePhoto() {
        guard !photoBusy, pendingPhoto == nil, !showBook, !showPhotoBook else { return }
        let date = Date(), name = store.plantDisplayName
        guard let image = camera.capture() else { photos.error = t("아직 사진을 찍을 수 없습니다.", "Camera is not ready yet."); return }
        guard let draft = try? PhotoLibrary.draft(scene:image,name:name,date:date) else { photos.error = t("사진을 만들지 못했습니다.", "Could not create photo."); return }
        showCare = false; tray = nil; music.dismissAlbum(); photoBusy = true
        photoFlash = 1
        withAnimation(.easeOut(duration:0.22)) { photoFlash = 0 }
        captureTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds:160_000_000) } catch { return }
            photoScale = 0.72; photoOffset = CGSize(width:0,height:35); photoOpacity = 0; photoAngle = -4
            pendingPhoto = draft
            withAnimation(.spring(response:0.5,dampingFraction:0.78)) {
                photoScale = 1; photoOffset = .zero; photoOpacity = 1; photoAngle = -2
            }
            photoBusy = false
        }
    }
    private func storePhoto(in size:CGSize) {
        guard !photoBusy, let draft = pendingPhoto else { return }
        guard photos.save(draft) else { return }
        photoBusy = true
        captureTask = Task { @MainActor in
            do { try await Task.sleep(nanoseconds:100_000_000) } catch { return }
            let point = camera.albumPoint() ?? CGPoint(x:0.84,y:0.80)
            let target = CGPoint(x:10+400*point.x,y:15+322*point.y)
            withAnimation(.easeInOut(duration:0.85)) {
                photoOffset = CGSize(width:target.x-size.width/2,height:target.y-size.height/2)
                photoScale = 0.08; photoAngle = -12; photoOpacity = 0
            }
            do { try await Task.sleep(nanoseconds:900_000_000) } catch { return }
            pendingPhoto = nil; photoBusy = false
        }
    }
    private func openPhotoBook() {
        guard photos.hasAlbum, pendingPhoto == nil, !photoBusy else { return }
        showCare = false; tray = nil; showBook = false
        store.wateringMode = false; store.pruningMode = false
        withAnimation(.easeOut(duration:0.2)) { showPhotoBook = true }
    }
    private var settingsPresented: Binding<Bool> {
        Binding(get:{ tray == .settings },set:{ presented in
            if presented { tray = .settings }
            else if tray == .settings { tray = nil }
        })
    }
    private var lowerTray: Binding<Tray?> {
        Binding(get:{ tray == .settings ? nil : tray },set:{ selected in
            if tray != .settings { tray = selected }
        })
    }
    private var digitalReadout: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 7) {
                Text(store.simulation || store.hasLiveWeather ? "\(Int(store.climate.temperature))°" : "--°")
                    .font(.custom(RetroFonts.temperature, size: 64))
                    .monospacedDigit()
                    .modifier(HUDOutline())
                Text(clockText(context.date))
                    .font(.custom(RetroFonts.clock, size: 14))
                    .monospacedDigit().modifier(HUDOutline())
                    .accessibilityLabel(context.date.formatted(date: .omitted, time: .standard))
                HStack(spacing: 5) {
                    Image(systemName: weatherSymbol)
                    Text(weatherReadout)
                    Text(store.simulation ? "SIM" : "LIVE").font(.system(size: 7, weight: .medium, design: .monospaced))
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8).modifier(HUDOutline())
            }
        }
    }
    private func clockText(_ date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        return String(format: "%02d:%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date), calendar.component(.second, from: date))
    }
    private var weatherSymbol: String {
        if !store.simulation && !store.hasLiveWeather { return store.loading ? "hourglass" : "cloud.slash" }
        return store.climate.condition.symbol(daylight:store.climate.daylight)
    }
    private var weatherReadout: String {
        guard store.simulation || store.hasLiveWeather else { return store.loading ? t("연결 중", "CONNECTING") : t("날씨 미연결", "OFFLINE") }
        return store.climate.condition.label(english:store.english,daylight:store.climate.daylight)
    }
    private func openAlbum(_ trackID:String = RoomTrack.library[0].id) {
        showCare = false; tray = nil; store.wateringMode = false; store.pruningMode = false
        music.selectAlbum(id:trackID)
    }
    private func openBook() {
        showCare = false; tray = nil; store.wateringMode = false; store.pruningMode = false
        withAnimation(.easeOut(duration:0.22)) { showBook = true }
    }
    private func closeBook() { withAnimation(.easeOut(duration:0.16)) { showBook = false } }
    private func openCare() {
        tray = nil
        if store.plant.adopted {
            store.wateringMode = false; store.pruningMode = false
            withAnimation(.easeOut(duration: 0.15)) { showCare.toggle() }
        } else { tray = .adopt }
    }
    private func beginWatering() {
        showCare = false; tray = nil; store.water()
    }
    private func beginFertilizing() {
        showCare = false; tray = nil; store.wateringMode = false; store.pruningMode = false
        store.feed()
    }
    private func startNameEdit() {
        nameDraft = store.plantDisplayName; editingName = true
    }
    private func cancelNameEdit() { editingName = false; nameFocused = false }
    private func saveNameEdit() {
        if nameDraft.trimmingCharacters(in:.whitespacesAndNewlines) == store.plantDisplayName { cancelNameEdit(); return }
        if store.renamePlant(nameDraft) { cancelNameEdit() }
    }
    private var nameHeader: some View {
        VStack(alignment:.leading,spacing:4) {
            if editingName {
                HStack(spacing:5) {
                    TextField(t("식물 이름", "Plant name"),text:$nameDraft)
                        .font(.custom(RetroFonts.clock,size:12)).textFieldStyle(.roundedBorder)
                        .focused($nameFocused).onAppear { nameFocused = true }.onSubmit(saveNameEdit)
                        .accessibilityLabel(t("식물 이름", "Plant name"))
                    Button(action:saveNameEdit) { Image(systemName:"checkmark").font(.system(size:12,weight:.medium)).frame(width:20,height:22) }
                        .buttonStyle(.plain).disabled(Plant.normalizedName(nameDraft) == nil)
                        .help(t("이름 저장", "Save name")).accessibilityLabel(t("이름 저장", "Save name"))
                    Button(action:cancelNameEdit) { Image(systemName:"xmark").font(.system(size:11)).frame(width:20,height:22) }
                        .buttonStyle(.plain).help(t("취소", "Cancel")).accessibilityLabel(t("이름 변경 취소", "Cancel renaming"))
                }
                if Plant.normalizedName(nameDraft) == nil {
                    Text(t("이름은 한 줄로 1~20자까지 입력해 주세요.", "Use a name of 1–20 characters on one line."))
                        .font(.system(size:9)).foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing:6) {
                    Text(store.plantDisplayName).font(.custom(RetroFonts.clock,size:14)).lineLimit(1).truncationMode(.tail)
                    Button(action:startNameEdit) {
                        Image(systemName:"pencil").font(.system(size:11)).frame(width:22,height:22)
                    }.buttonStyle(.plain).help(t("이름 바꾸기", "Rename plant")).accessibilityLabel(t("식물 이름 바꾸기", "Rename plant"))
                    Spacer(minLength:0)
                }
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    private var careBubble: some View {
        VStack(spacing: 10) {
            nameHeader
            HStack(spacing: 14) {
                careAction("drop.fill", .blue, t("물주기", "Water"), beginWatering)
                careAction("circle.grid.2x2.fill", .orange, t("비료주기", "Fertilize"), beginFertilizing)
            }
            HStack(spacing: 16) {
                gauge("drop", store.plant.moisture, (store.plant.moisture >= 90 || store.plant.moisture <= 10) ? .orange : .blue, t("흙 습기", "Soil moisture"))
                gauge("circle.grid.2x2", store.plant.fertilizer, store.plant.fertilizer >= 100 ? .orange : .green, t("비료 농도", "Fertilizer"))
            }
            Text(store.advice).font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.65).frame(maxWidth: .infinity, alignment: .leading)

        }
        .padding(.leading, 27).padding(.trailing, 13).padding(.vertical, 13)
        .background(SpeechBubble().fill(LinearGradient(colors: [.white, Color(white: 0.94)], startPoint: .top, endPoint: .bottom)))
        .overlay(SpeechBubble().strokeBorder(Color(white: 0.6), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 3, y: 2)
    }
    private func homeTile(_ symbol: String, _ color: Color, _ destination: Tray, _ title: String) -> some View {
        Button {
            if destination == .care { openCare() }
            else { showCare = false; tray = destination }
        } label: {
            Image(systemName: symbol).font(.system(size: 27, weight: .regular)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(color.gradient).shadow(color: .white, radius: 0, y: 1).frame(width: 55, height: 52)
        }.buttonStyle(PlasticButton()).help(title).accessibilityLabel(title)
            .overlay { if tray == destination || (destination == .care && showCare) { SelectionCorners().stroke(mint, style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(-5).allowsHitTesting(false) } }
    }
    private func perform(_ symbol: String, _ action: () -> Void) {
        action(); tray = nil; showCare = false
        withAnimation(.easeOut(duration: 0.12)) { feedback = symbol }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            if feedback == symbol { withAnimation { feedback = nil } }
        }
    }
    @ViewBuilder private func panel(_ selected: Tray) -> some View {
        switch selected {
        case .adopt:
            VStack(spacing: 16) {
                heading(t("몬스테라", "Monstera"), "leaf")
                Image(systemName: "leaf.fill").font(.system(size: 45)).foregroundStyle(.green.gradient).padding(8)
                Button(t("입양하기", "Adopt")) { store.adopt(); tray = nil }.buttonStyle(.borderedProminent).tint(Color(red: 0.35, green: 0.67, blue: 0.43))
            }
        case .care:
            careBubble
        case .weather:
            VStack(spacing: 14) {
                heading(t("날씨", "Weather"), "sun.max")
                Picker("", selection: Binding(get: { store.simulation }, set: { store.setMode($0) })) {
                    Text(t("시뮬레이션", "Simulation")).tag(true)
                    Text(t("내 위치", "My location")).tag(false)
                }.pickerStyle(.segmented).labelsHidden()
                if store.simulation {
                    if ["permission", "network", "unavailable"].contains(store.weatherStatus) {
                        Text(t("위치나 날씨를 사용할 수 없어 가상 날씨를 표시하고 있어요.", "Using virtual weather because location or weather is unavailable."))
                            .font(.system(size:11)).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                    }
                    Picker(t("시간", "Time"),selection:Binding(get:{store.climate.daylight},set:{store.setSimulatedWeather(daylight:$0,sky:store.climate.simulationSky)})) {
                        Text(t("낮", "Day")).tag(true)
                        Text(t("밤", "Night")).tag(false)
                    }.pickerStyle(.segmented)
                    Picker(t("하늘", "Sky"),selection:Binding(get:{store.climate.simulationSky},set:{store.setSimulatedWeather(daylight:store.climate.daylight,sky:$0)})) {
                        Text(t("맑음", "Clear")).tag(SimulationSky.clear)
                        Text(t("비", "Rain")).tag(SimulationSky.rain)
                        Text(t("눈", "Snow")).tag(SimulationSky.snow)
                        Text(t("뇌우", "Storm")).tag(SimulationSky.storm)
                    }.pickerStyle(.segmented)
                }
                if store.simulation || store.hasLiveWeather {
                    HStack { Text("\(Int(store.climate.temperature))°"); Spacer(); Image(systemName: "humidity"); Text("\(Int(store.climate.humidity))%") }.font(.system(size: 14, design: .rounded))
                }
                if !store.simulation {
                    HStack {
                        Text(store.locationLabel).font(.system(size: 12)); Spacer()
                        Button { store.requestWeather() } label: { Image(systemName: store.loading ? "hourglass" : "arrow.clockwise") }.disabled(store.loading).help(t("새로고침", "Refresh"))
                    }
                    Text(weatherMessage).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    if let date = store.weatherDate { Text(date.formatted(date: .omitted, time: .shortened)).font(.system(size: 10)).foregroundStyle(.secondary) }
                    Link("Open-Meteo", destination: URL(string: "https://open-meteo.com/")!).font(.system(size: 10))
                }
            }
        case .settings:
            VStack(alignment: .leading, spacing: 12) {
                heading(t("설정", "Settings"), "gearshape")
                HStack {
                    Button(store.english ? "한국어" : "English") { store.english.toggle() }
                    Spacer()
                    Button { guide.toggle() } label: { Image(systemName: "questionmark.circle") }.help(t("돌봄 가이드", "Care guide"))

                }.buttonStyle(.bordered)
                Divider()
                SoundSettingsView(english:store.english)
                if guide {
                    Text(t("흙 습기 90% 이상 또는 10% 이하가 연속 약 16시간 이어지면 잎이 노래져요. 창문을 열어둔 밤 시간이 누적 약 32시간이 되어도 노래져요. 창문을 닫으면 밤 시간 기록은 초기화돼요. 비료는 새잎을 빠르게 키워요. 0%여도 기본 속도로 자라며, 100%가 연속 약 16시간 유지되면 잎이 노래져요.", "Leaves yellow after about 16 continuous hours at soil moisture ≥90% or ≤10%, or about 32 accumulated night hours with the window open. Closing the window resets the night timer. Fertilizer speeds new leaves; 0% allows normal growth. Staying at 100% for about 16 hours yellows a leaf.")).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    Text(t("식물의 시간은 실제 시간보다 1.5배 빠르게 흐르며 잠자기 시간도 반영해요. 위치는 날씨 조회에만 사용하며 저장하지 않습니다.", "Plant time runs at 1.5× real time, including time spent asleep. Location is used only for weather and is not saved.")).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Divider()
                HStack {
                    Button(t("다시 입양", "Start over")) { reset = true }
                    Spacer()
                    Button(t("종료", "Quit")) { NSApp.terminate(nil) }
                }.buttonStyle(.borderless).font(.system(size: 11))
            }
        }
    }
    private func heading(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.system(size: 13, weight: .medium, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
    }
    private func careAction(_ icon: String, _ color: Color, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 22)).foregroundStyle(color.gradient)
                Text(title).font(.system(size: 10))
            }.frame(width: 90, height: 57)
        }.buttonStyle(PlasticButton()).accessibilityLabel(title)
    }
    private func tool(_ icon: String, _ color: Color, _ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color.gradient).frame(width: 48, height: 43) }
            .buttonStyle(PlasticButton()).help(title).accessibilityLabel(title)
    }
    private func weatherTile(_ icon: String, _ color: Color, _ preset: String, _ title: String) -> some View {
        tool(icon, color, title) { store.setPreset(preset) }
            .overlay { if store.preset == preset { SelectionCorners().stroke(mint, lineWidth: 2).padding(-4).allowsHitTesting(false) } }
    }
    private func gauge(_ icon: String, _ value: Double, _ color: Color, _ title: String) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) { Text(title); Spacer(minLength: 0); Text("\(Int(value))%").monospacedDigit() }.font(.system(size: 9))
            GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.08)); Capsule().fill(color.opacity(0.6)).frame(width: g.size.width * min(100, max(0, value)) / 100) } }.frame(height: 4)
        }.frame(maxWidth: .infinity).help(title).accessibilityLabel("\(title) \(Int(value))%")
    }
    private var weatherMessage: String {
        switch store.weatherStatus {
        case "locating": return t("위치 확인 중…", "Locating…")
        case "permission": return t("시스템 설정 → 개인정보 보호 및 보안 → 위치 서비스에서 허용해 주세요.", "Allow access in System Settings → Privacy & Security → Location Services.")
        case "network": return t("날씨 연결 실패. 연결을 확인하고 다시 시도해 주세요.", "Weather unavailable. Check your connection and retry.")
        case "unavailable": return t("위치를 찾지 못했어요. 위치 서비스를 확인해 주세요.", "Location unavailable. Check Location Services.")
        case "ok": return t("15분마다 갱신", "Refreshes every 15 minutes")
        default: return t("위치 권한을 허용해 주세요.", "Allow location access.")
        }
    }
}

private struct PlasticButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 9).fill(LinearGradient(colors: configuration.isPressed ? [Color(white: 0.77), Color(white: 0.92)] : [.white, Color(white: 0.91), Color(white: 0.81)], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color(white: 0.65), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(0.95), lineWidth: 1.5).padding(2))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.18), radius: 1, y: configuration.isPressed ? 0 : 2)
            .offset(y: configuration.isPressed ? 1 : 0)
    }
}
private struct SelectionCorners: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        for (x, y, dx, dy) in [(r.minX,r.minY,1.0,1.0),(r.maxX,r.minY,-1.0,1.0),(r.minX,r.maxY,1.0,-1.0),(r.maxX,r.maxY,-1.0,-1.0)] {
            p.move(to: CGPoint(x:x + 8 * dx,y:y)); p.addLine(to:CGPoint(x:x,y:y)); p.addLine(to:CGPoint(x:x,y:y + 8 * dy))
        }
        return p
    }
}

/// A crisp black outline keeps white HUD glyphs legible on the white wallpaper.
private struct HUDOutline: ViewModifier {
    func body(content: Content) -> some View {
        content.foregroundStyle(.white).background {
            ZStack {
                ForEach(0..<8) { index in
                    let angle = Double(index) * .pi / 4
                    content.foregroundStyle(.black)
                        .offset(x: cos(angle) * 0.85, y: sin(angle) * 0.85)
                }
            }.accessibilityHidden(true).allowsHitTesting(false)
        }
    }
}

private struct SpeechBubble: InsettableShape {
    var inset: CGFloat = 0
    func inset(by amount: CGFloat) -> some InsettableShape { var shape = self; shape.inset += amount; return shape }
    func path(in bounds: CGRect) -> Path {
        let r = bounds.insetBy(dx: inset, dy: inset)
        let x = r.minX + 14, right = r.maxX, top = r.minY, bottom = r.maxY, radius: CGFloat = 9
        let tail = top + r.height * 0.68
        return Path { p in
            p.move(to: CGPoint(x: x+radius, y: top))
            p.addLine(to: CGPoint(x: right-radius, y: top))
            p.addQuadCurve(to: CGPoint(x: right, y: top+radius), control: CGPoint(x: right,y: top))
            p.addLine(to: CGPoint(x: right,y: bottom-radius))
            p.addQuadCurve(to: CGPoint(x: right-radius,y: bottom), control: CGPoint(x: right,y: bottom))
            p.addLine(to: CGPoint(x: x+radius,y: bottom))
            p.addQuadCurve(to: CGPoint(x: x,y: bottom-radius), control: CGPoint(x:x,y:bottom))
            p.addLine(to: CGPoint(x:x,y:tail+9))
            p.addLine(to: CGPoint(x:r.minX,y:tail+15))
            p.addLine(to: CGPoint(x:x,y:tail-4))
            p.addLine(to: CGPoint(x:x,y:top+radius))
            p.addQuadCurve(to: CGPoint(x:x+radius,y:top), control:CGPoint(x:x,y:top))
            p.closeSubpath()
        }
    }
}
