import Foundation

public struct Climate: Codable, Equatable {
    public var temperature: Double
    public var humidity: Double
    public var daylight: Bool
    public var cloud: Double
    public var rain: Bool
    public init(temperature: Double = 23, humidity: Double = 55, daylight: Bool = true, cloud: Double = 15, rain: Bool = false) {
        self.temperature = temperature; self.humidity = humidity; self.daylight = daylight; self.cloud = cloud; self.rain = rain
    }
    public var sunlight: Double { daylight ? max(12, 85 - cloud * 0.65) : 0 }
}

/// Accelerated game rules. Six persistent slots keep pruning and replacement deterministic.
public struct Plant: Codable {
    public var adopted = false
    public var name = "몬스테라"
    public private(set) var hasCustomName = false
    public var moisture = 42.0 {
        didSet { yellowingConditions.observeSoil(moisture) }
    }
    public var health = 95.0
    public var growth = 0.0
    public var fertilizer = 0.0 {
        didSet {
            yellowingConditions.observeFertilizer(fertilizer)
            if fertilizer < 100 { fertilizerExcess = 0 }
        }
    }
    /// Slow-release pellets above saturation keep the displayed concentration at 100% until consumed.
    private var fertilizerExcess = 0.0
    public var rootStress = 0.0
    /// Aggregate retained for old saves; rendering uses each leaf's irreversible phase.
    public private(set) var yellowing = 0.0
    public var air = 65.0
    public var windowOpen = false {
        didSet {
            yellowingConditions.observeWindow(windowOpen)
            if !windowOpen { openHours = 0 }
        }
    }
    public var openHours = 0.0
    public var ageHours = 0.0
    public private(set) var leaves = (0..<6).map { Leaf(id: $0) }
    public private(set) var yellowingConditions = YellowingConditions()
    public var leafCount: Int { leaves.filter(\.isPresent).count }
    public var prunableLeafIDs: Set<Int> { Set(leaves.filter(\.canPrune).map(\.id)) }
    public init(matureLeafCount:Int = 2) {
        let count = min(6,max(0,matureLeafCount))
        for id in leaves.indices where id >= count {
            leaves[id].phase = .empty; leaves[id].maturity = 0
        }
    }

    public static func normalizedName(_ raw:String) -> String? {
        let name = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 20,
              !name.unicodeScalars.contains(where:{ $0.value < 32 || $0.value == 127 || CharacterSet.newlines.contains($0) }) else { return nil }
        return name
    }
    @discardableResult public mutating func rename(to raw:String) -> Bool {
        guard let clean = Self.normalizedName(raw) else { return false }
        name = clean; hasCustomName = true
        return true
    }
    public mutating func water(amount: Double = 48) {
        guard adopted, amount.isFinite, amount > 0 else { return }
        moisture = min(100, moisture + amount)
    }
    public mutating func feed() {
        guard adopted else { return }
        let total = fertilizer + 28
        fertilizer = min(100, total)
        fertilizerExcess = min(28, fertilizerExcess + max(0, total - 100))
    }
    @discardableResult public mutating func pruneLeaf(id: Int) -> Bool {
        guard adopted, leaves.indices.contains(id), leaves[id].canPrune else { return false }
        leaves[id].phase = .empty
        leaves[id].maturity = 0
        leaves[id].yellowHours = 0
        updateYellowing()
        return true
    }
    public func canGrowLeaves(in climate: Climate) -> Bool {
        (25...70).contains(moisture)
            && air >= 55 && rootStress <= 25 && climate.sunlight > 10
            && !(windowOpen && climate.temperature < 15)
    }
    public var leafGrowthMultiplier: Double { 1 + clamp(fertilizer) / 100 }
    public mutating func advance(hours: Double, climate: Climate) {
        guard adopted, hours.isFinite, hours > 0 else { return }
        var remaining = min(hours, 24 * 30)
        while remaining > 0.000001 {
            let dt = min(0.1, remaining); remaining -= dt
            ageHours += dt
            openHours = windowOpen ? openHours + dt : 0
            air = clamp(air + (windowOpen ? 12 : -2.2) * dt)
            let drying = (windowOpen ? 2.5 : 1.1) * (1.25 - climate.humidity / 200) + climate.sunlight / 150
            let startFertilizer = fertilizer, startExcess = fertilizerExcess
            let consumption = 0.16
            func fertilizerAt(_ time: Double) -> Double {
                clamp(startFertilizer - max(0, consumption*time-startExcess))
            }
            let startMoisture = moisture
            let endMoisture = clamp(moisture - drying * dt)
            // Split at exact threshold crossings: time below 90% must not count as wet time.
            var boundaries = [0.0, dt]
            if drying > 0 {
                for threshold in [90.0, 10.0] {
                    let crossing = (startMoisture-threshold) / drying
                    if crossing > 0 && crossing < dt { boundaries.append(crossing) }
                }
            }
            let saturationEnd = startExcess / consumption
            if startFertilizer >= 100 && saturationEnd > 0 && saturationEnd < dt { boundaries.append(saturationEnd) }
            boundaries.sort()
            var yellowDue = false
            for index in 1..<boundaries.count {
                let a = boundaries[index-1], b = boundaries[index]
                let sample = clamp(startMoisture-drying*(a+b)/2)
                let due = yellowingConditions.advance(hours:b-a,moisture:sample,windowOpen:windowOpen,daylight:climate.daylight,fertilizer:fertilizerAt((a+b)/2))
                yellowDue = yellowDue || due
            }
            moisture = endMoisture
            fertilizerExcess = max(0,startExcess-consumption*dt)
            fertilizer = fertilizerAt(dt)
            let wet = moisture > 73 && air < 55
            rootStress = clamp(rootStress + (wet ? 2.4 : -1.2) * dt)
            if yellowDue {
                let order = [5, 2, 3, 0, 1, 4]
                let candidates = order.filter { leaves[$0].phase == .green }
                if let id = candidates.min(by: { leaves[$0].maturity < leaves[$1].maturity }) {
                    leaves[id].phase = .yellow
                    leaves[id].yellowHours = 0
                }
            }
            let good = canGrowLeaves(in: climate)
            for id in leaves.indices where leaves[id].phase == .yellow {
                leaves[id].yellowHours += dt
                if leaves[id].yellowHours >= 24 { leaves[id].phase = .withered }
            }
            if good {
                // Finish the most advanced existing shoot first, including old multi-shoot saves.
                let growing = leaves.indices.filter { leaves[$0].phase == .green && leaves[$0].maturity < 1 }
                let active = growing.sorted {
                    leaves[$0].maturity == leaves[$1].maturity ? $0 < $1 : leaves[$0].maturity > leaves[$1].maturity
                }.first
                if let id = active {
                    leaves[id].maturity = min(1,leaves[id].maturity+dt*leafGrowthMultiplier/48)
                    if leaves[id].maturity > 1-0.000000001 { leaves[id].maturity = 1 }
                }
                // A paused green shoot blocks new buds. Start the next only after it matures.
                if !leaves.contains(where:{ $0.phase == .green && $0.maturity < 1 }),
                   let id = leaves.firstIndex(where:{ $0.phase == .empty }) {
                    leaves[id].phase = .green; leaves[id].maturity = 0
                }
            }
            updateYellowing()
            let damage = (moisture < 12 ? 1.7 : 0) + (rootStress > 35 ? 1.5 : 0) + yellowing / 100
            health = clamp(health + (damage > 0.15 ? -damage : 0.45) * dt)
            if moisture > 18 && moisture < 74 && health > 45 && climate.sunlight > 10 {
                growth = min(100, growth + (0.16 * leafGrowthMultiplier) * climate.sunlight / 65 * dt)
            }
        }
    }
    private mutating func updateYellowing() {
        yellowing = leaves.reduce(0) { $0 + $1.yellowFraction } / 6 * 100
    }

    private enum CodingKeys: String, CodingKey {
        case adopted, name, hasCustomName, moisture, health, growth, fertilizer, fertilizerExcess, rootStress, yellowing
        case air, windowOpen, openHours, ageHours, leaves, yellowingConditions
    }
    public init(from decoder: Decoder) throws {
        // Saves predating per-leaf state represented a full six-leaf plant.
        self.init(matureLeafCount:6)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        adopted = try c.decodeIfPresent(Bool.self, forKey: .adopted) ?? adopted
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? name
        hasCustomName = try c.decodeIfPresent(Bool.self,forKey:.hasCustomName) ?? !["모스","Moss","몬스테라","Monstera"].contains(name)
        if !hasCustomName || name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            name = "몬스테라"; hasCustomName = false
        }
        moisture = try c.decodeIfPresent(Double.self, forKey: .moisture) ?? moisture
        health = try c.decodeIfPresent(Double.self, forKey: .health) ?? health
        growth = try c.decodeIfPresent(Double.self, forKey: .growth) ?? growth
        fertilizer = try c.decodeIfPresent(Double.self, forKey: .fertilizer) ?? fertilizer
        fertilizerExcess = fertilizer >= 100 ? min(28,max(0,try c.decodeIfPresent(Double.self, forKey: .fertilizerExcess) ?? 0)) : 0
        rootStress = try c.decodeIfPresent(Double.self, forKey: .rootStress) ?? rootStress
        air = try c.decodeIfPresent(Double.self, forKey: .air) ?? air
        windowOpen = try c.decodeIfPresent(Bool.self, forKey: .windowOpen) ?? windowOpen
        openHours = try c.decodeIfPresent(Double.self, forKey: .openHours) ?? openHours
        ageHours = try c.decodeIfPresent(Double.self, forKey: .ageHours) ?? ageHours
        yellowingConditions = try c.decodeIfPresent(YellowingConditions.self, forKey: .yellowingConditions) ?? YellowingConditions()
        yellowingConditions.observeSoil(moisture)
        yellowingConditions.observeWindow(windowOpen)
        yellowingConditions.observeFertilizer(fertilizer)
        if let saved = try c.decodeIfPresent([Leaf].self, forKey: .leaves) {
            for id in leaves.indices {
                if let leaf = saved.first(where: { $0.id == id }) {
                    leaves[id].phase = leaf.phase
                    leaves[id].maturity = min(1, max(0, leaf.maturity))
                    leaves[id].yellowHours = max(0, leaf.yellowHours)
                }
            }
        } else {
            // Previous versions tinted all six leaves together. Preserve existing damage without healing any leaf.
            let legacy = try c.decodeIfPresent(Double.self, forKey: .yellowing) ?? 0
            if legacy > 0 {
                for id in leaves.indices {
                    leaves[id].phase = .yellow
                    leaves[id].yellowHours = min(23, legacy / 100 * 24)
                }
            }
        }
        updateYellowing()
    }
}
private func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
