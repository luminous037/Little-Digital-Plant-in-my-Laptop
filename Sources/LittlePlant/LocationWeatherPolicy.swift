import CoreLocation

/// Keep authorization decisions separate from GPS/network side effects.
enum LocationWeatherPolicy {
    enum Action { case askPermission, locate, virtualWeather }
    static func action(for status:CLAuthorizationStatus) -> Action {
        if status == .notDetermined { return .askPermission }
        // Raw value 4 also accepts When In Use on platforms reporting that authorization.
        if status == .authorizedAlways || status.rawValue == 4 { return .locate }
        return .virtualWeather
    }
}
