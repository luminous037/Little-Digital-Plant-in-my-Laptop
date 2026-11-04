import Foundation

/// Converts elapsed wall time into plant time. A hidden UI or suspended timer never loses time.
/// Intentionally session-only: quitting the app still pauses the plant until the next launch.
public struct PlantClock {
    public static let rate = 1.5
    public private(set) var lastUpdate: Date
    public init(now: Date = Date()) { lastUpdate = now }

    @discardableResult
    public mutating func advance(to now: Date, plant: inout Plant, climate: Climate) -> Bool {
        let elapsed = now.timeIntervalSince(lastUpdate)
        guard elapsed.isFinite, elapsed > 0 else { return false }
        let hours = elapsed * Self.rate / 3600
        guard hours.isFinite else { return false }
        lastUpdate = now
        guard plant.adopted else { return false }
        // Plant.advance bounds each call to 30 simulation days; split longer gaps without dropping any.
        var remaining = hours
        while remaining > 0 {
            let step = min(remaining, 24 * 30)
            plant.advance(hours:step, climate:climate)
            remaining -= step
        }
        return true
    }
}
