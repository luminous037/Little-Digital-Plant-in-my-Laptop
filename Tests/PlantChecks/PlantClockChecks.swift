import Foundation
import PlantCore

func checkPlantClock() throws {
    let base = Date(timeIntervalSince1970:1_700_000_000)
    func plant() -> Plant { var p = Plant(); p.adopted = true; return p }
    func compare(_ a:Plant,_ b:Plant) {
        for (x,y) in [(a.ageHours,b.ageHours),(a.moisture,b.moisture),(a.fertilizer,b.fertilizer),
                      (a.air,b.air),(a.rootStress,b.rootStress),(a.growth,b.growth),
                      (a.health,b.health),(a.openHours,b.openHours),
                      (a.yellowingConditions.dryHours,b.yellowingConditions.dryHours),
                      (a.yellowingConditions.openNightHours,b.yellowingConditions.openNightHours)] {
            expectEqual(x,y,accuracy:0.000001)
        }
        for (x,y) in zip(a.leaves,b.leaves) {
            expectEqual(x.phase,y.phase)
            expectEqual(x.maturity,y.maturity,accuracy:0.000001)
            expectEqual(x.yellowHours,y.yellowHours,accuracy:0.000001)
        }
    }
    // Every time-dependent effect must match 1.5 simulation hours per real hour.
    var actual = plant(); actual.moisture = 66; actual.fertilizer = 50
    actual.air = 40; actual.rootStress = 40; actual.windowOpen = true
    var expected = actual, clock = PlantClock(now:base)
    let climate = Climate()
    expected.advance(hours:3,climate:climate)
    expect(clock.advance(to:base.addingTimeInterval(2*3600),plant:&actual,climate:climate))
    compare(actual,expected)
    expectEqual(actual.ageHours,3,accuracy:0.000001)

    // One suspended eight-hour interval must equal eight awake one-hour intervals.
    var slept = plant(), awake = slept
    var sleepingClock = PlantClock(now:base), awakeClock = PlantClock(now:base)
    sleepingClock.advance(to:base.addingTimeInterval(8*3600),plant:&slept,climate:climate)
    for hour in 1...8 { awakeClock.advance(to:base.addingTimeInterval(Double(hour)*3600),plant:&awake,climate:climate) }
    compare(slept,awake)
    expectEqual(slept.ageHours,12,accuracy:0.000001)
    let age = slept.ageHours
    expect(!sleepingClock.advance(to:base.addingTimeInterval(8*3600),plant:&slept,climate:climate))
    expect(!sleepingClock.advance(to:base.addingTimeInterval(7*3600),plant:&slept,climate:climate))
    expectEqual(slept.ageHours,age)
    sleepingClock.advance(to:base.addingTimeInterval(9*3600),plant:&slept,climate:climate)
    expectEqual(slept.ageHours,13.5,accuracy:0.000001)

    // Dryness and overdose now reach their 24-simulation-hour threshold in 16 real hours.
    var dry = plant(); dry.moisture = 0
    var dryClock = PlantClock(now:base)
    dryClock.advance(to:base.addingTimeInterval(15.99*3600),plant:&dry,climate:climate)
    expectEqual(dry.prunableLeafIDs.count,0)
    dryClock.advance(to:base.addingTimeInterval(16*3600),plant:&dry,climate:climate)
    expectEqual(dry.prunableLeafIDs.count,1)
    var overfed = plant(); for _ in 0..<4 { overfed.feed() }
    var overfedClock = PlantClock(now:base)
    overfedClock.advance(to:base.addingTimeInterval(16*3600),plant:&overfed,climate:climate)
    expectEqual(overfed.yellowingConditions.overfedHours,24,accuracy:0.000001)
    expectEqual(overfed.prunableLeafIDs.count,1)
    var night = plant(); night.windowOpen = true
    var nightClock = PlantClock(now:base)
    nightClock.advance(to:base.addingTimeInterval(32*3600),plant:&night,climate:Climate(temperature:8,daylight:false))
    expectEqual(night.yellowingConditions.openNightHours,48,accuracy:0.000001)

    // Preserve the entire gap even when it exceeds Plant.advance's per-call safety bound.
    var longSleep = plant(), longClock = PlantClock(now:base)
    longClock.advance(to:base.addingTimeInterval(31*24*3600),plant:&longSleep,climate:climate)
    expectEqual(longSleep.ageHours,31*24*1.5,accuracy:0.000001)

    // No backdating a newly adopted plant or accepting invalid wall-clock readings.
    var fresh = Plant(), freshClock = PlantClock(now:base)
    expect(!freshClock.advance(to:base.addingTimeInterval(3600),plant:&fresh,climate:climate))
    fresh.adopted = true
    freshClock.advance(to:base.addingTimeInterval(7200),plant:&fresh,climate:climate)
    expectEqual(fresh.ageHours,1.5,accuracy:0.000001)
    expect(!freshClock.advance(to:Date(timeIntervalSince1970:.infinity),plant:&fresh,climate:climate))
    let restored = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(fresh))
    compare(fresh,restored)
    print("PASS: 1.5x plant clock, full sleep catch-up, duplicate/backward-clock protection, 16/32-hour damage thresholds, >30-day gaps and saved-state compatibility")
}
