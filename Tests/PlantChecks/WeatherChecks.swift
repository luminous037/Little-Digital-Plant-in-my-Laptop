import Foundation
import PlantCore

func checkWeatherConditions() throws {
    func decode(_ code:Int?,precipitation:Double = 0,daylight:Int = 1) throws -> Climate {
        var current:[String:Any] = ["temperature_2m":17,"relative_humidity_2m":94,"is_day":daylight,"cloud_cover":40,"precipitation":precipitation]
        if let code { current["weather_code"] = code }
        let data = try JSONSerialization.data(withJSONObject:["current":current])
        return try JSONDecoder().decode(LiveWeatherReply.self,from:data).climate
    }
    for code in [51,53,55,56,57] {
        let c = try decode(code)
        expect(c.rain && c.condition == .drizzle)
        expectEqual(c.condition.label(english:false,daylight:true),"이슬비")
        expectEqual(c.condition.symbol(daylight:true),"cloud.drizzle")
        let night = try decode(code,daylight:0)
        expect(night.rain && night.condition == .drizzle)
    }
    for code in [61,63,65,66,67,80,81,82,95,96,99] { expect(try decode(code).rain) }
    let cloudy = try decode(3)
    expectEqual(cloudy.condition,.cloudy)
    expectGreater(cloudy.skyCloudCover,65)
    expectEqual(try decode(2).condition,.partlyCloudy)
    expectEqual(try decode(45).condition,.fog)
    expectEqual(try decode(0).condition,.clear)
    let snow = try decode(73,precipitation:0.2)
    expect(!snow.rain && snow.condition == .snow)
    expect(try decode(nil,precipitation:0.1).rain)
    expect(try decode(999,precipitation:0.1).rain)
    expectEqual(try decode(nil).condition,.clear)
    expectEqual(Climate(cloud:65).condition,.cloudy)
    expect(Climate(rain:true).rain)
    let legacy = Data(#"{"temperature":23,"humidity":55,"daylight":true,"cloud":15,"rain":false}"#.utf8)
    expectEqual(try JSONDecoder().decode(Climate.self,from:legacy),Climate())
    print("PASS: WMO drizzle at zero precipitation, rain/thunderstorm codes, night drizzle, cloud/fog conditions, snow separation, legacy responses and shared UI labels/icons")
}

func checkWeatherEffectsTiming() {
    for day in [true,false] { for sky in SimulationSky.allCases {
        let climate = sky.climate(daylight:day)
        expectEqual(climate.daylight,day); expectEqual(climate.simulationSky,sky)
        expectEqual(climate.rain,sky == .rain || sky == .storm)
        if sky == .snow { expectEqual(climate.condition,.snow); expectLess(climate.temperature,0) }
        if sky == .storm { expectEqual(climate.condition,.thunderstorm) }
    } }
    expectEqual(StormTimeline.sample(elapsed:0).flash,0)
    expectGreater(StormTimeline.sample(elapsed:2.05).flash,0)
    expectGreater(StormTimeline.sample(elapsed:2.26).flash,0)
    expect(!StormTimeline.sample(elapsed:2.26).thunderReady)
    expect(StormTimeline.sample(elapsed:3.3).thunderReady)
    expectEqual(StormTimeline.sample(elapsed:3.3).flash,0)
    expect(!StormTimeline.sample(elapsed:10).thunderReady)
    expectEqual(StormTimeline.sample(elapsed:17.6).strike,1)
    expect(StormTimeline.sample(elapsed:17.6).thunderReady)
    for time in stride(from:0.0,to:250,by:0.1) {
        let sample = StormTimeline.sample(elapsed:time)
        expect((0...1).contains(sample.flash))
        expect(!sample.thunderReady || sample.flash == 0)
    }
    expectEqual(StormTimeline.sample(elapsed:-1).flash,0)
    expect(!StormTimeline.sample(elapsed:.infinity).thunderReady)
    print("PASS: all eight day/night sky presets, snow/rain separation, irregular lightning cycles, delayed thunder and bounded flash intensity")
}
