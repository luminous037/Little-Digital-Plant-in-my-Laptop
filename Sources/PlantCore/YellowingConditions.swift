import Foundation

/// Only these four duration thresholds may start a new yellow leaf.
public struct YellowingConditions: Codable, Equatable {
    public private(set) var wetHours = 0.0
    public private(set) var dryHours = 0.0
    public private(set) var openNightHours = 0.0
    public private(set) var overfedHours = 0.0
    public init() {}
    public mutating func observeSoil(_ moisture: Double) {
        if moisture < 90 { wetHours = 0 }
        if moisture > 10 { dryHours = 0 }
    }
    public mutating func observeWindow(_ open: Bool) {
        if !open { openNightHours = 0 }
    }
    public mutating func observeFertilizer(_ concentration: Double) {
        if concentration < 100 { overfedHours = 0 }
    }
    /// Reports a completed exposure period. Plant subdivides time so no interval spans multiple periods.
    @discardableResult public mutating func advance(hours: Double, moisture: Double, windowOpen: Bool, daylight: Bool, fertilizer: Double = 0) -> Bool {
        guard hours.isFinite, hours > 0 else { return false }
        observeSoil(moisture); observeWindow(windowOpen); observeFertilizer(fertilizer)
        let beforeWet = wetHours, beforeDry = dryHours, beforeNight = openNightHours, beforeOverfed = overfedHours
        if fertilizer >= 100 { overfedHours += hours }
        if moisture >= 90 { wetHours += hours }
        if moisture <= 10 { dryHours += hours }
        if windowOpen && !daylight { openNightHours += hours }
        func crossed(_ before: Double, _ after: Double, _ period: Double) -> Bool {
            floor((before + 1e-9) / period) < floor((after + 1e-9) / period)
        }
        return crossed(beforeWet,wetHours,24) || crossed(beforeDry,dryHours,24) || crossed(beforeNight,openNightHours,48) || crossed(beforeOverfed,overfedHours,24)
    }
    private enum CodingKeys: String, CodingKey { case wetHours, dryHours, openNightHours, overfedHours }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wetHours = try c.decodeIfPresent(Double.self, forKey: .wetHours) ?? 0
        dryHours = try c.decodeIfPresent(Double.self, forKey: .dryHours) ?? 0
        openNightHours = try c.decodeIfPresent(Double.self, forKey: .openNightHours) ?? 0
        overfedHours = try c.decodeIfPresent(Double.self, forKey: .overfedHours) ?? 0
    }
}
