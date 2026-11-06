import Foundation

/// Open-Meteo WMO codes describe conditions even when reported precipitation rounds to zero.
public enum WeatherCondition: String {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunderstorm
    public var bringsRain: Bool { self == .drizzle || self == .rain || self == .thunderstorm }

    public static func resolve(code:Int?, precipitation:Bool, cloud:Double) -> Self {
        switch code {
        case 51,53,55,56,57: return .drizzle
        case 61,63,65,66,67,80,81,82: return .rain
        case 95,96,99: return .thunderstorm
        case 71,73,75,77,85,86: return .snow
        default: break
        }
        if precipitation { return .rain }
        switch code {
        case 0,1: return .clear
        case 2: return .partlyCloudy
        case 3: return .cloudy
        case 45,48: return .fog
        default: return cloud >= 65 ? .cloudy : .clear
        }
    }
    public func symbol(daylight:Bool) -> String {
        switch self {
        case .clear: return daylight ? "sun.max" : "moon"
        case .partlyCloudy: return daylight ? "cloud.sun" : "cloud.moon"
        case .cloudy: return "cloud"
        case .fog: return "cloud.fog"
        case .drizzle: return "cloud.drizzle"
        case .rain: return "cloud.rain"
        case .snow: return "cloud.snow"
        case .thunderstorm: return "cloud.bolt.rain"
        }
    }
    public func label(english:Bool,daylight:Bool) -> String {
        switch self {
        case .clear: return daylight ? (english ? "CLEAR" : "맑음") : (english ? "NIGHT" : "밤")
        case .partlyCloudy: return english ? "PARTLY CLOUDY" : "구름 조금"
        case .cloudy: return english ? "CLOUDY" : "흐림"
        case .fog: return english ? "FOG" : "안개"
        case .drizzle: return english ? "DRIZZLE" : "이슬비"
        case .rain: return english ? "RAIN" : "비"
        case .snow: return english ? "SNOW" : "눈"
        case .thunderstorm: return english ? "THUNDERSTORM" : "뇌우"
        }
    }
}

/// Shared by the real network request and offline response tests.
public struct LiveWeatherReply: Decodable {
    private struct Current: Decodable {
        let temperature_2m:Double, relative_humidity_2m:Double, cloud_cover:Double, precipitation:Double
        let is_day:Int
        let weather_code:Int?
    }
    private let current:Current
    public var climate:Climate {
        Climate(temperature:current.temperature_2m,humidity:current.relative_humidity_2m,
                daylight:current.is_day == 1,cloud:current.cloud_cover,
                rain:current.precipitation > 0,weatherCode:current.weather_code)
    }
}
