import SwiftUI
import AppKit
import CoreLocation
import PlantCore

@MainActor
final class GardenStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    let music = RoomMusic()
    let photos = PhotoLibrary.shared
    private let rainAudio = RainAmbience()
    private let thunderAudio = ThunderAmbience()
    var stormStart:Date? { thunderAudio.startDate }
    @Published var plant: Plant { didSet { rainAudio.updateWindow(open:plant.windowOpen); thunderAudio.updateWindow(open:plant.windowOpen) } }
    @Published var english: Bool { didSet { if !CommandLine.arguments.contains("--render-preview") { UserDefaults.standard.set(english, forKey: "english") } } }
    @Published var simulation = true
    @Published var running = false
    @Published private(set) var fertilizerPulse = 0
    @Published var wateringMode = false
    @Published var pruningMode = false
    @Published var climate = Climate() { didSet { rainAudio.updateWeather(raining:climate.rain,windowOpen:plant.windowOpen); thunderAudio.updateWeather(storm:climate.condition == .thunderstorm,windowOpen:plant.windowOpen) } }
    @Published var preset = "sun"
    @Published var locationLabel = ""
    @Published var weatherStatus = ""
    @Published var loading = false
    @Published var weatherDate: Date?
    @Published var noteKO = "작은 초록을 들일 준비가 되었나요?"
    @Published var noteEN = "A little green, a little everyday."
    private let location = CLLocationManager()
    private var timer: Timer?
    private var clock = PlantClock()
    private var advancesTime = !CommandLine.arguments.contains("--render-preview")
    private var sleepObservers: [NSObjectProtocol] = []
    private var lastWeatherAttempt = Date.distantPast
    private var liveClimate: Climate?
    private var liveLocation = ""
    private var lastCoordinate: CLLocationCoordinate2D?
    private var requestID = UUID()
    private var locationTimeout: Task<Void, Never>?
    private var startedWeather = false
    private var wantsLiveWeather = false
    private var awaitingAuthorization = false

    override init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey:"plant.v1"), let saved = try? JSONDecoder().decode(Plant.self,from:data) { plant = saved }
        else { var starter = Plant(); starter.adopted = true; plant = starter }
        english = defaults.bool(forKey: "english")
        super.init()
        rainAudio.updateWeather(raining:climate.rain,windowOpen:plant.windowOpen)
        if defaults.data(forKey:"plant.v1") == nil { save() }
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        if advancesTime {
            timer = Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            observeSystemSleep()
        }
    }
    private func observeSystemSleep() {
        guard sleepObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification,NSWorkspace.didWakeNotification] {
            sleepObservers.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            })
        }
    }
    func verifySleepProgression() async {
        let fixture = GardenStore()
        fixture.plant = Plant(); fixture.plant.adopted = true
        var expected = fixture.plant
        expected.advance(hours:12,climate:fixture.climate)
        fixture.clock = PlantClock(now:Date().addingTimeInterval(-8*3600))
        fixture.advancesTime = true
        fixture.observeSystemSleep()
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.didWakeNotification,object:nil)
        try? await Task.sleep(nanoseconds:150_000_000)
        precondition(abs(fixture.plant.ageHours-12) < 0.01,"Wake notification must apply all eight elapsed hours at 1.5x without opening a window")
        precondition(abs(fixture.plant.moisture-expected.moisture) < 0.05,"Wake catch-up must advance drying")
        let age = fixture.plant.ageHours
        fixture.tick(now:fixture.clock.lastUpdate)
        precondition(fixture.plant.ageHours == age,"Repeated wake/timer events must not replay elapsed time")
        // A care action must settle an otherwise unprocessed gap before changing the soil.
        fixture.plant = Plant(); fixture.plant.adopted = true
        fixture.clock = PlantClock(now:Date().addingTimeInterval(-8*3600))
        fixture.waterFromStream(10)
        precondition(abs(fixture.plant.moisture-(expected.moisture+10)) < 0.05,"Watering must occur after sleep drying, not before it")
        fixture.advancesTime = false
        fputs("PASS: native wake notification, hidden-window catch-up, 1.5x drying, duplicate wake guard and care-after-sleep ordering\n",stderr)
    }
    deinit {
        timer?.invalidate()
        for observer in sleepObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }
    /// Apply elapsed time under the previous environment before any care or weather change.
    private func settleTime(to now:Date = Date()) {
        guard advancesTime else { return }
        if clock.advance(to:now,plant:&plant,climate:climate) { save() }
    }
    func t(_ ko: String, _ en: String) -> String { english ? en : ko }
    func save() { guard !CommandLine.arguments.contains("--render-preview") else { return }; if let data = try? JSONEncoder().encode(plant) { UserDefaults.standard.set(data, forKey: "plant.v1") } }
    func message(_ ko: String, _ en: String) { noteKO = ko; noteEN = en; save() }
    func adopt() {
        clock = PlantClock()
        wateringMode = false; pruningMode = false
        plant = Plant(); plant.adopted = true
        message("몬스테라가 집에 왔어요. 첫날은 천천히 살펴봐요.", "Monstera is home. Take a moment to get acquainted.")
    }
    var plantDisplayName: String { plant.hasCustomName ? plant.name : t("몬스테라", "Monstera") }
    @discardableResult func renamePlant(_ name:String) -> Bool {
        guard plant.adopted, plant.rename(to:name) else { return false }
        save(); return true
    }
    func water() {
        guard plant.adopted else { return }
        pruningMode = false; wateringMode = true
    }
    func startPruning() {
        guard !plant.prunableLeafIDs.isEmpty else { return }
        wateringMode = false; pruningMode.toggle()
    }
    @discardableResult func pruneLeaf(_ id: Int) -> Bool {
        guard pruningMode else { return false }
        settleTime()
        guard plant.pruneLeaf(id:id) else { return false }
        if plant.prunableLeafIDs.isEmpty { pruningMode = false }
        message("상한 잎을 잘랐어요. 좋은 환경에서 그 자리에 새잎이 나요.", "Damaged leaf cut. Good care will sprout a replacement in its place.")
        return true
    }
    func waterFromStream(_ amount: Double) {
        guard plant.adopted, amount.isFinite, amount > 0 else { return }
        settleTime()
        let wasWet = plant.moisture > 30
        plant.water(amount: amount)
        noteKO = wasWet ? "흙이 이미 촉촉해요. 물을 멈추고 환기해 주세요." : "흙이 물을 머금고 있어요. 물을 준 뒤 잠깐 환기해요."
        noteEN = wasWet ? "The soil is already damp. Stop watering and ventilate." : "The soil is taking in water. Ventilate briefly afterwards."
        save()
    }
    func feed() {
        guard plant.adopted else { return }
        settleTime()
        plant.feed()
        fertilizerPulse += 1
        message(plant.fertilizer >= 100 ? "비료가 가득해요. 100%가 약 16시간 이어지면 잎이 노래져요." : "알비료를 줬어요. 새잎이 더 빠르게 자라요.", plant.fertilizer >= 100 ? "Fertilizer is full. Staying at 100% for about 16 hours yellows leaves." : "Fertilizer added. New leaves will grow faster.")
    }
    func toggleWindow() { settleTime(); plant.windowOpen.toggle(); if !plant.windowOpen { plant.openHours = 0 }; message(plant.windowOpen ? "창문을 열었어요. 오랫동안 열어두지 마세요." : "창문을 닫았어요.", plant.windowOpen ? "Window open. Remember to close it later." : "Window closed.") }
    func advance(_ hours: Double) { plant.advance(hours: hours, climate: climate); save() }
    func tick(now:Date = Date()) {
        // Last-known weather and the last window state apply during sleep; fetch fresh weather afterwards.
        settleTime(to:now)
        if !simulation, now.timeIntervalSince(lastWeatherAttempt) > 900 && !loading, let coordinate = lastCoordinate { fetch(coordinate) }
    }

    func setPreset(_ value: String) {
        settleTime()
        preset = value
        let sky:SimulationSky
        if value.hasPrefix("snow") { sky = .snow }
        else if value.hasPrefix("storm") { sky = .storm }
        else if value.hasPrefix("rain") { sky = .rain }
        else { sky = .clear }
        climate = sky.climate(daylight:!value.contains("night"))
    }
    func setSimulatedWeather(daylight:Bool,sky:SimulationSky) {
        setPreset(sky == .clear ? (daylight ? "sun" : "night") : sky.rawValue+(daylight ? "" : "-night"))
    }
    func setSimulatedWeather(daylight:Bool,rain:Bool) {
        setSimulatedWeather(daylight:daylight,sky:rain ? .rain : .clear)
    }
    func verifyWeatherCombinations() {
        let fixture = GardenStore()
        for day in [true,false] { for sky in SimulationSky.allCases {
            fixture.setSimulatedWeather(daylight:day,sky:sky)
            precondition(fixture.climate.daylight == day && fixture.climate.simulationSky == sky,"All eight simulation combinations must be selectable")
        } }
        fixture.setPreset("sun")
        fputs("PASS: clear/rain/snow/storm × day/night simulation combinations\n",stderr)
    }
    func startWeatherAtLaunch() {
        guard !startedWeather, !CommandLine.arguments.contains("--render-preview") else { return }
        startedWeather = true
        requestWeather()
    }
    func setMode(_ sim: Bool) {
        settleTime(); running = false
        if sim {
            wantsLiveWeather = false; awaitingAuthorization = false
            requestID = UUID(); locationTimeout?.cancel(); loading = false; weatherStatus = ""
            simulation = true; setPreset(preset)
        } else {
            wantsLiveWeather = true
            if LocationWeatherPolicy.action(for:location.authorizationStatus) == .locate, let cached = liveClimate {
                simulation = false; climate = cached; locationLabel = liveLocation; weatherStatus = "ok"
            } else { requestWeather() }
        }
    }
    func requestWeather() {
        guard !loading else { return }
        wantsLiveWeather = true; loading = true; weatherStatus = "locating"
        let id = UUID(); requestID = id
        Task { [weak self] in
            // Checking system-wide location services can block, so keep it off the UI thread.
            let enabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
            guard let self, self.loading, self.wantsLiveWeather, self.requestID == id else { return }
            guard enabled else { self.fail("permission"); return }
            switch LocationWeatherPolicy.action(for:self.location.authorizationStatus) {
            case .virtualWeather: self.fail("permission")
            case .askPermission:
                self.awaitingAuthorization = true
                NSApp.activate(ignoringOtherApps:true)
                self.location.requestWhenInUseAuthorization()
                // Do not time out while the person is still deciding in the system prompt.
            case .locate: self.beginLocationRequest()
            }
        }
    }
    private func beginLocationRequest() {
        guard wantsLiveWeather else { return }
        awaitingAuthorization = false; loading = true; weatherStatus = "locating"
        location.requestLocation()
        locationTimeout?.cancel()
        locationTimeout = Task { [weak self] in
            do { try await Task.sleep(nanoseconds:20_000_000_000) } catch { return }
            guard let self, self.loading else { return }
            self.fail("unavailable")
        }
    }
    private func authorizationChanged(_ status:CLAuthorizationStatus) {
        guard wantsLiveWeather else { return }
        switch LocationWeatherPolicy.action(for:status) {
        case .locate:
            if awaitingAuthorization || !loading { beginLocationRequest() }
        case .virtualWeather:
            liveClimate = nil; lastCoordinate = nil; liveLocation = ""; weatherDate = nil
            fail("permission")
        case .askPermission: break
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationChanged(self.location.authorizationStatus)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor [weak self] in
            guard let self, self.loading, self.wantsLiveWeather, !self.awaitingAuthorization else { return }
            self.lastCoordinate = coordinate; self.fetch(coordinate)
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self, self.loading, !self.awaitingAuthorization else { return }
            self.fail("unavailable")
        }
    }
    private func fail(_ reason: String) {
        settleTime()
        requestID = UUID(); loading = false; awaitingAuthorization = false
        weatherStatus = reason; lastWeatherAttempt = Date(); locationTimeout?.cancel()
        simulation = true; running = false; preset = "sun"; climate = Climate()
        locationLabel = t("가상 날씨", "Virtual weather")
    }
    func verifyWeatherFallback() {
        precondition(LocationWeatherPolicy.action(for:.notDetermined) == .askPermission)
        precondition(LocationWeatherPolicy.action(for:.denied) == .virtualWeather)
        precondition(LocationWeatherPolicy.action(for:.restricted) == .virtualWeather)
        precondition(LocationWeatherPolicy.action(for:.authorizedAlways) == .locate)
        if let whenInUse = CLAuthorizationStatus(rawValue:4) { precondition(LocationWeatherPolicy.action(for:whenInUse) == .locate) }
        let fixture = GardenStore()
        let age = fixture.plant.ageHours
        fixture.wantsLiveWeather = true; fixture.loading = true; fixture.awaitingAuthorization = true
        fixture.authorizationChanged(.denied)
        precondition(fixture.simulation && !fixture.loading && !fixture.awaitingAuthorization && fixture.weatherStatus == "permission")
        precondition(fixture.climate.temperature == 23 && !fixture.climate.rain && fixture.climate.daylight && fixture.plant.ageHours == age)
        fixture.simulation = false; fixture.loading = true; fixture.fail("network")
        precondition(fixture.simulation && fixture.climate == Climate() && !fixture.running)
        fixture.loading = true; fixture.wantsLiveWeather = true; fixture.setMode(true)
        precondition(!fixture.loading && !fixture.wantsLiveWeather,"Choosing simulation must cancel pending live requests")
        fputs("PASS: first-run authorization branches, denied/restricted virtual weather, 23-degree sunny fallback, network fallback, request cancellation\n",stderr)
    }
    private func fetch(_ coordinate: CLLocationCoordinate2D) {
        loading = true; lastWeatherAttempt = Date(); let id = UUID(); requestID = id
        Task {
            do {
                let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=temperature_2m,relative_humidity_2m,is_day,cloud_cover,precipitation,weather_code&timezone=auto")!
                var request = URLRequest(url: url); request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let updated = try JSONDecoder().decode(LiveWeatherReply.self, from:data).climate
                guard id == requestID else { return }
                liveClimate = updated; weatherDate = Date(); weatherStatus = "ok"; loading = false; locationTimeout?.cancel()
                liveLocation = String(format: "%.2f°, %.2f°", coordinate.latitude, coordinate.longitude)
                if wantsLiveWeather { settleTime(); simulation = false; running = false; climate = updated; locationLabel = liveLocation }
                // Reverse geocoding is cosmetic; weather remains usable if it fails.
                if let place = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)).first {
                    guard id == requestID else { return }
                    liveLocation = place.locality ?? place.administrativeArea ?? liveLocation
                    if !simulation { locationLabel = liveLocation }
                }
            } catch { if id == requestID { fail("network") } }
        }
    }
    var hasLiveWeather: Bool { liveClimate != nil }
    var advice: String {
        if plant.leaves.contains(where: { $0.phase == .withered }) { return t("마른 잎은 가위로 잘라 새잎 자리를 비워 주세요.", "Snip the dried leaves to make room for new growth.") }
        if plant.leaves.contains(where: { $0.phase == .yellow }) { return t("노란 잎은 돌아오지 않아요. 가위로 잘라 주세요.", "Yellow leaves cannot turn green. Snip them with scissors.") }
        if plant.fertilizer >= 100 { return t("비료 100%가 약 16시간 지속되면 과다 황변이 생겨요.", "Staying at 100% fertilizer for about 16 hours yellows a leaf.") }
        if plant.leaves.contains(where: { $0.phase == .green && $0.maturity < 1 }) {
            if !plant.canGrowLeaves(in: climate) { return t("새잎이 쉬고 있어요. 물·햇빛·통풍을 살펴봐요.", "New leaves paused. Check water, light and airflow.") }
            return plant.fertilizer > 0 ? t("비료 덕분에 새잎이 더 빠르게 자라고 있어요.", "Fertilizer is helping new leaves grow faster.") : t("새잎이 기본 속도로 자라고 있어요. 좋은 환경에서 약 32시간 걸려요.", "New leaves take about 32 hours of good conditions at the base growth rate.")
        }
        if plant.leaves.contains(where:{ $0.phase == .empty }) { return t("좋은 환경에서 새잎이 한 장씩 차례로 나요.", "Good care brings new leaves, one at a time.") }
        if plant.rootStress > 20 { return t("뿌리가 답답해요. 물주기를 쉬고 환기해 주세요.", "Roots need air. Pause watering and ventilate.") }
        if plant.windowOpen && !climate.daylight { return t("밤에는 창문을 닫아 주세요. 오래 열어두면 잎이 노래져요.", "Close the window at night. Prolonged night exposure yellows leaves.") }
        if plant.moisture < 25 { return t("흙이 거의 말랐어요. 물을 줄 시간이에요.", "The soil is almost dry. Time for a drink.") }
        if plant.moisture > 70 { return t("흙이 촉촉해요. 물 대신 잠깐 환기해 주세요.", "The soil is wet. A little airflow will help.") }
        return t("잘 지내고 있어요. 오늘도 천천히 자라는 중.", "Doing well. Growing a little, day by day.")
    }
}
