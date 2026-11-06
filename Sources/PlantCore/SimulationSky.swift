import Foundation

public enum SimulationSky: String, CaseIterable {
    case clear, rain, snow, storm
    public func climate(daylight:Bool) -> Climate {
        switch self {
        case .clear: return daylight ? Climate() : Climate(temperature:8,humidity:65,daylight:false,cloud:20)
        case .rain: return Climate(temperature:daylight ? 18 : 12,humidity:daylight ? 88 : 92,daylight:daylight,cloud:95,rain:true,weatherCode:61)
        case .snow: return Climate(temperature:daylight ? -1 : -4,humidity:88,daylight:daylight,cloud:95,weatherCode:73)
        case .storm: return Climate(temperature:daylight ? 19 : 13,humidity:94,daylight:daylight,cloud:100,weatherCode:95)
        }
    }
}
extension Climate {
    public var simulationSky:SimulationSky {
        switch condition {
        case .snow: return .snow
        case .thunderstorm: return .storm
        case .rain,.drizzle: return .rain
        default: return .clear
        }
    }
}

/// A shared timeline keeps the visible lightning and its delayed sound in sync.
public enum StormTimeline {
    public struct Sample {
        public let strike:Int
        public let flash:Double
        public let thunderReady:Bool
    }
    private static let periods = [14.0,20.0,17.0,23.0]
    public static func sample(elapsed:Double) -> Sample {
        guard elapsed.isFinite, elapsed >= 0, elapsed < 1e12 else { return Sample(strike:-1,flash:0,thunderReady:false) }
        let total = periods.reduce(0,+)
        var phase = elapsed.truncatingRemainder(dividingBy:total)
        var index = Int(floor(elapsed/total))*periods.count
        for duration in periods {
            if phase < duration { break }
            phase -= duration; index += 1
        }
        let since = phase-(2.0+Double(index%3)*0.25)
        let flash:Double
        switch since {
        case 0..<0.16: flash = 0.85*(1-since/0.16)
        case 0.24..<0.48: flash = 1-(since-0.24)/0.24
        case 0.48..<0.75: flash = 0.12*(1-(since-0.48)/0.27)
        default: flash = 0
        }
        return Sample(strike:index,flash:flash,thunderReady:(1.2..<2.0).contains(since))
    }
}
