import Foundation
import PlantCore

final class PlantTests {
    func adopted() -> Plant { var p = Plant(matureLeafCount:6); p.adopted = true; return p }
    func stressed(_ hours: Double = 24) -> Plant {
        var p = adopted(); tend(&p,hours:hours,moisture:0)
        return p
    }
    /// Maintain the specified controlled conditions; ordinary simulation still dries naturally.
    func tend(_ p: inout Plant, hours: Double, moisture: Double = 45, fertilizer: Double = 28, air: Double = 70) {
        var left = hours
        while left > 0.000001 {
            p.moisture = moisture; p.fertilizer = fertilizer; p.air = air
            if fertilizer >= 100 { p.feed() }
            p.rootStress = 0; p.windowOpen = false
            let step = min(0.5,left); p.advance(hours:step,climate:Climate()); left -= step
        }
    }
    func sprout() -> (Plant,Int) {
        var p = stressed(24); let id = p.prunableLeafIDs.first!
        expect(p.pruneLeaf(id:id)); tend(&p,hours:0.1)
        expectEqual(p.leaves[id].phase,.green); expectEqual(p.leaves[id].maturity,0)
        return (p,id)
    }
    func testTwoLeafStartAndSequentialGrowth() throws {
        var p = Plant(); p.adopted = true
        expectEqual(p.leafCount,2); expectEqual(p.leaves.count,6)
        expectEqual(p.leaves.filter { $0.phase == .green && $0.maturity == 1 }.count,2)
        tend(&p,hours:0.1,fertilizer:0)
        expectEqual(p.leafCount,3); expectEqual(p.leaves[2].maturity,0)
        tend(&p,hours:24,fertilizer:0)
        expectEqual(p.leaves[2].maturity,0.5,accuracy:0.00001); expectEqual(p.leaves[3].phase,.empty)
        tend(&p,hours:12,moisture:20,fertilizer:0)
        expectEqual(p.leaves[2].maturity,0.5,accuracy:0.00001); expectEqual(p.leaves[3].phase,.empty)
        let saved = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(p))
        expectEqual(saved.leaves,p.leaves)
        tend(&p,hours:24,fertilizer:0)
        expectEqual(p.leaves[2].maturity,1); expectEqual(p.leaves[3].phase,.green); expectEqual(p.leaves[3].maturity,0)
        expectEqual(p.leaves[4].phase,.empty)
    }
    func testLegacyParallelGrowthBecomesSequential() throws {
        let data = Data(#"{"adopted":true,"leaves":[{"id":0,"phase":"green","maturity":1,"yellowHours":0},{"id":1,"phase":"green","maturity":1,"yellowHours":0},{"id":2,"phase":"green","maturity":0.6,"yellowHours":0},{"id":3,"phase":"green","maturity":0.3,"yellowHours":0},{"id":4,"phase":"empty","maturity":0,"yellowHours":0},{"id":5,"phase":"empty","maturity":0,"yellowHours":0}]}"#.utf8)
        var p = try JSONDecoder().decode(Plant.self,from:data)
        let old = p.leaves
        tend(&p,hours:6,fertilizer:0)
        expectGreater(p.leaves[2].maturity,old[2].maturity)
        expectEqual(p.leaves[3].maturity,old[3].maturity); expectEqual(p.leaves[4].phase,.empty)
        expectEqual(p.leafCount,4)
        let legacy = try JSONDecoder().decode(Plant.self,from:Data(#"{"adopted":true}"#.utf8))
        expectEqual(legacy.leafCount,6)
    }
    func testPlantNaming() throws {
        var plant = Plant()
        expectEqual(plant.name,"몬스테라"); expect(!plant.hasCustomName)
        expect(plant.rename(to:"  초록이 🌱  "))
        expectEqual(plant.name,"초록이 🌱"); expect(plant.hasCustomName)
        expect(!plant.rename(to:"  ")); expect(!plant.rename(to:String(repeating:"가",count:21)))
        expect(!plant.rename(to:"초록\n이")); expectEqual(plant.name,"초록이 🌱")
        var saved = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(plant))
        expectEqual(saved.name,"초록이 🌱"); expect(saved.hasCustomName)
        expect(saved.rename(to:"모스"))
        let customLegacyName = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(saved))
        expectEqual(customLegacyName.name,"모스"); expect(customLegacyName.hasCustomName)
        let legacy = try JSONDecoder().decode(Plant.self,from:Data(#"{"name":"모스"}"#.utf8))
        expectEqual(legacy.name,"몬스테라"); expect(!legacy.hasCustomName)
        let existing = try JSONDecoder().decode(Plant.self,from:Data(#"{"name":"우리 식물"}"#.utf8))
        expectEqual(existing.name,"우리 식물"); expect(existing.hasCustomName)
    }
    func testUnadoptedDoesNotAdvance() {
        var p = Plant(); p.water(); p.feed(); p.advance(hours:24,climate:Climate())
        expectEqual(p.ageHours,0); expectEqual(p.moisture,42); expectEqual(p.fertilizer,0)
        expectEqual(p.leafCount,2); expect(!p.pruneLeaf(id:0))
    }
    func testVentilationDriesSoilAndRelievesRoots() {
        var shut = adopted(); shut.moisture = 100; shut.air = 25
        var open = shut; open.windowOpen = true
        shut.advance(hours:12,climate:Climate()); open.advance(hours:12,climate:Climate())
        expectGreater(shut.rootStress,open.rootStress); expectLess(open.moisture,shut.moisture)
    }
    func testSequentialYellowing() {
        var p = stressed(24)
        expectEqual(p.prunableLeafIDs.count,1)
        let first = p.prunableLeafIDs
        tend(&p,hours:24,moisture:0)
        expectEqual(p.prunableLeafIDs.count,2); expect(first.isSubset(of:p.prunableLeafIDs))
        expectEqual(p.leaves.filter { $0.phase == .green }.count,4)
    }
    func testYellowIsIrreversibleAndWithers() {
        var p = stressed(24); let id = p.prunableLeafIDs.first!
        tend(&p,hours:23)
        expectEqual(p.leaves[id].phase,.yellow)
        tend(&p,hours:1)
        expectEqual(p.leaves[id].phase,.withered)
        tend(&p,hours:48)
        expectEqual(p.leaves[id].phase,.withered); expectEqual(p.leafCount,6)
        expectEqual(p.leaves.filter { $0.phase == .green }.count,5)
    }
    func testModerateFeedAndExcess() {
        var plain = adopted(); var fed = plain; fed.feed(); var excess = plain
        excess.feed(); excess.feed(); excess.feed()
        plain.advance(hours:8,climate:Climate()); fed.advance(hours:8,climate:Climate()); excess.advance(hours:8,climate:Climate())
        expectGreater(fed.growth,plain.growth); expectEqual(fed.prunableLeafIDs.count,0)
        expectEqual(excess.prunableLeafIDs.count,0)
    }
    func testPruningProtectsHealthyAndKeepsSlots() {
        var p = adopted(); expect(!p.pruneLeaf(id:0)); expect(!p.pruneLeaf(id:-1)); expect(!p.pruneLeaf(id:6))
        p = stressed(); let id = p.prunableLeafIDs.sorted().first!
        let others = p.leaves.filter { $0.id != id }
        expect(p.pruneLeaf(id:id)); expectEqual(p.leafCount,5)
        expectEqual(p.leaves[id].phase,.empty); expect(!p.pruneLeaf(id:id))
        expectEqual(p.leaves.filter { $0.id != id },others)
    }
    func testRegrowthAtSameSlotOverTwoDays() {
        var (p,id) = sprout()
        tend(&p,hours:24,fertilizer:0); expectEqual(p.leaves[id].maturity,0.5,accuracy:0.00001)
        expectEqual(p.leaves[id].id,id); expectEqual(p.leafCount,6)
        tend(&p,hours:24,fertilizer:0); expectEqual(p.leaves[id].maturity,1)
        expectEqual(p.leaves[id].phase,.green)
    }
    func testGrowthPausesAndResumes() {
        var (p,id) = sprout(); tend(&p,hours:6)
        let size = p.leaves[id].maturity
        tend(&p,hours:12,moisture:20); expectEqual(p.leaves[id].maturity,size)
        tend(&p,hours:12,air:30); expectEqual(p.leaves[id].maturity,size)
        tend(&p,hours:6); expectGreater(p.leaves[id].maturity,size)
        expectEqual(p.leaves[id].phase,.green)
    }
    func testSmallLeafDamagedByDryness() {
        var (p,id) = sprout(); tend(&p,hours:6)
        let size = p.leaves[id].maturity
        tend(&p,hours:24,moisture:0)
        expectEqual(p.leaves[id].phase,.yellow); expectEqual(p.leaves[id].maturity,size)
        tend(&p,hours:24); expectEqual(p.leaves[id].phase,.withered)
        expectEqual(p.leaves[id].maturity,size)
    }
    func testSmallLeafDamagedByOverwatering() {
        var (p,id) = sprout(); tend(&p,hours:6)
        let size = p.leaves[id].maturity
        tend(&p,hours:24,moisture:100)
        expectEqual(p.leaves[id].phase,.yellow); expectEqual(p.leaves[id].maturity,size)
        tend(&p,hours:24); expectEqual(p.leaves[id].phase,.withered)
        expectEqual(p.leaves[id].maturity,size)
    }
    func testAllPrunedAndMaximumSix() {
        var p = stressed(144); expectEqual(p.prunableLeafIDs.count,6)
        for id in 0..<6 { expect(p.pruneLeaf(id:id)) }
        expectEqual(p.leafCount,0); expectEqual(p.leaves.count,6)
        tend(&p,hours:0.1,fertilizer:0); expectEqual(p.leafCount,1)
        expectEqual(p.leaves.filter { $0.phase == .green && $0.maturity < 1 }.count,1)
        tend(&p,hours:48,fertilizer:0); expectEqual(p.leafCount,2)
        expectEqual(p.leaves.filter { $0.maturity == 1 }.count,1)
        tend(&p,hours:240,fertilizer:0); expect(p.leaves.allSatisfy { $0.maturity == 1 && $0.phase == .green })
        tend(&p,hours:24); expectEqual(p.leafCount,6)
        expectEqual(Set(p.leaves.map(\.id)),Set(0..<6))
    }
    func testNoSproutWithoutGoodConditions() {
        var p = stressed(24); let id = p.prunableLeafIDs.first!; expect(p.pruneLeaf(id:id))
        tend(&p,hours:6,moisture:20); expectEqual(p.leaves[id].phase,.empty)
        tend(&p,hours:6,air:20); expectEqual(p.leaves[id].phase,.empty)
        tend(&p,hours:6,moisture:0); expectEqual(p.leaves[id].phase,.empty)
        tend(&p,hours:0.1); expectEqual(p.leaves[id].phase,.green)
    }
    func testJumpConsistencyAndBounds() {
        var a = adopted(); a.windowOpen = true; a.water(); a.feed(); var b = a
        a.advance(hours:24,climate:Climate())
        for _ in 0..<24 { b.advance(hours:1,climate:Climate()) }
        expectEqual(a.moisture,b.moisture,accuracy:0.0001); expectEqual(a.health,b.health,accuracy:0.0001)
        for id in 0..<6 {
            expectEqual(a.leaves[id].phase,b.leaves[id].phase)
            expectEqual(a.leaves[id].maturity,b.leaves[id].maturity,accuracy:0.0001)
        }
        a.advance(hours:720,climate:Climate(temperature:2,daylight:false))
        for value in [a.moisture,a.health,a.growth,a.fertilizer,a.rootStress,a.yellowing,a.air] { expect((0...100).contains(value)) }
        expectEqual(a.leafCount,6); expect(a.leaves.allSatisfy { (0...1).contains($0.maturity) })
    }
    func testContinuousWatering() {
        var streamed = adopted(); streamed.moisture = 15
        var single = streamed; single.water()
        for _ in 0..<200 { streamed.water(amount:0.24) }
        expectEqual(streamed.moisture,single.moisture,accuracy:0.00001)
        let before = streamed.moisture
        for invalid in [Double.nan, Double.infinity, -10, 0] { streamed.water(amount:invalid) }
        expectEqual(streamed.moisture,before)
        streamed.water(amount:500); expectEqual(streamed.moisture,100)
        streamed.air = 15; streamed.advance(hours:12,climate:Climate())
        expectGreater(streamed.rootStress,10)
    }
    func testLifecyclePersistence() throws {
        var (p,id) = sprout(); tend(&p,hours:7)
        let data = try JSONEncoder().encode(p)
        var restored = try JSONDecoder().decode(Plant.self,from:data)
        expectEqual(restored.leaves,p.leaves); expectEqual(restored.moisture,p.moisture)
        tend(&p,hours:6); tend(&restored,hours:6)
        expectEqual(restored.leaves,p.leaves); expectGreater(restored.leaves[id].maturity,0)
        var dead = stressed(144)
        let reloaded = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(dead))
        expectEqual(dead.leaves,reloaded.leaves)
        expect(dead.pruneLeaf(id:0))
        let cut = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(dead))
        expectEqual(cut.leaves[0].phase,.empty)
    }
    func testExactWetThreshold() {
        var c = YellowingConditions()
        expect(!c.advance(hours:23.999,moisture:90,windowOpen:false,daylight:true))
        expect(c.advance(hours:0.001,moisture:90,windowOpen:false,daylight:true))
        expectEqual(c.wetHours,24,accuracy:0.000001)
        c.observeSoil(89.999); expectEqual(c.wetHours,0)
        expect(!c.advance(hours:23,moisture:100,windowOpen:false,daylight:true))
        c.observeSoil(50)
        expect(!c.advance(hours:1,moisture:100,windowOpen:false,daylight:true))
    }
    func testExactDryThreshold() {
        var c = YellowingConditions()
        expect(!c.advance(hours:23.999,moisture:10,windowOpen:false,daylight:true))
        expect(c.advance(hours:0.001,moisture:10,windowOpen:false,daylight:true))
        c.observeSoil(10.001); expectEqual(c.dryHours,0)
        expect(!c.advance(hours:23,moisture:0,windowOpen:false,daylight:true))
        c.observeSoil(50)
        expect(!c.advance(hours:1,moisture:0,windowOpen:false,daylight:true))
    }
    func testNightThresholdAndDayPause() {
        var c = YellowingConditions()
        expect(!c.advance(hours:23,moisture:45,windowOpen:true,daylight:false))
        expect(!c.advance(hours:24,moisture:45,windowOpen:true,daylight:true))
        expectEqual(c.openNightHours,23)
        expect(!c.advance(hours:24.999,moisture:45,windowOpen:true,daylight:false))
        expect(c.advance(hours:0.001,moisture:45,windowOpen:true,daylight:false))
        c.observeWindow(false); expectEqual(c.openNightHours,0)
        expect(!c.advance(hours:47,moisture:45,windowOpen:true,daylight:false))
    }
    func testNaturalDryingCannotFakeSustainedWetness() {
        var p = adopted(); p.moisture = 100
        p.advance(hours:24,climate:Climate())
        expectEqual(p.prunableLeafIDs.count,0); expectEqual(p.yellowingConditions.wetHours,0)
        // Starting at 10% does qualify for the complete 24 hours.
        p = adopted(); p.moisture = 10
        p.advance(hours:23.9,climate:Climate()); expectEqual(p.prunableLeafIDs.count,0)
        p.advance(hours:0.1,climate:Climate()); expectEqual(p.prunableLeafIDs.count,1)
    }
    func testOnlyListedConditionsCanYellow() {
        var p = adopted()
        for _ in 0..<96 {
            p.moisture = 45; p.fertilizer = 99; p.rootStress = 100
            p.advance(hours:0.5,climate:Climate(temperature:8))
        }
        expectEqual(p.prunableLeafIDs.count,0)
    }
    func testInstantCareResetsTimers() {
        var p = adopted(); tend(&p,hours:23,moisture:0)
        expectEqual(p.yellowingConditions.dryHours,23,accuracy:0.0001)
        p.water(amount:20); expectEqual(p.yellowingConditions.dryHours,0)
        var remaining = 47.9
        while remaining > 0.000001 {
            p.moisture = 45; p.windowOpen = true
            let dt = min(0.5,remaining)
            p.advance(hours:dt,climate:Climate(temperature:23,daylight:false)); remaining -= dt
        }
        expectEqual(p.prunableLeafIDs.count,0)
        p.windowOpen = false; p.windowOpen = true
        expectEqual(p.yellowingConditions.openNightHours,0)
        p.moisture = 45; p.advance(hours:0.1,climate:Climate(daylight:false))
        expectEqual(p.prunableLeafIDs.count,0)
    }
    func testExposurePersistenceAndOldStressMigration() throws {
        var p = adopted(); tend(&p,hours:23,moisture:100)
        var copy = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(p))
        expectEqual(copy.yellowingConditions,p.yellowingConditions)
        tend(&copy,hours:1,moisture:100); expectEqual(copy.prunableLeafIDs.count,1)
        let legacy = Data(#"{"adopted":true,"moisture":45,"leafStressHours":999,"yellowing":0}"#.utf8)
        var old = try JSONDecoder().decode(Plant.self,from:legacy)
        old.advance(hours:1,climate:Climate()); expectEqual(old.prunableLeafIDs.count,0)
    }
    func tendKeepingFertilizer(_ p: inout Plant, hours: Double) {
        var remaining = hours
        while remaining > 0.000001 {
            p.moisture = 45; p.air = 70; p.rootStress = 0; p.windowOpen = false
            let dt = min(0.5,remaining); p.advance(hours:dt,climate:Climate()); remaining -= dt
        }
    }
    func testZeroFertilizerIsSafeAndGrows() {
        var p = adopted(); tend(&p,hours:96,fertilizer:0)
        expect(p.leaves.allSatisfy { $0.phase == .green })
        var (young,id) = sprout(); tend(&young,hours:48,fertilizer:0)
        expectEqual(young.leaves[id].maturity,1)
        expect(young.leaves.allSatisfy { $0.phase == .green })
    }
    func testFertilizerSpeedsVisibleNewLeaves() {
        let (original,id) = sprout()
        var none = original, moderate = original, strong = original
        tend(&none,hours:12,fertilizer:0)
        tend(&moderate,hours:12,fertilizer:50)
        tend(&strong,hours:12,fertilizer:99)
        expectEqual(none.leaves[id].maturity,0.25,accuracy:0.0001)
        expectGreater(moderate.leaves[id].maturity,none.leaves[id].maturity)
        expectGreater(strong.leaves[id].maturity,moderate.leaves[id].maturity)
        expectEqual(strong.prunableLeafIDs.count,0)
        var p = adopted(); p.fertilizer = 0; expectEqual(p.leafGrowthMultiplier,1)
        p.fertilizer = 50; expectEqual(p.leafGrowthMultiplier,1.5)
        p.fertilizer = 100; expectEqual(p.leafGrowthMultiplier,2)
    }
    func testExactFertilizerThresholdAndReset() {
        var c = YellowingConditions()
        expect(!c.advance(hours:23.999,moisture:45,windowOpen:false,daylight:true,fertilizer:100))
        expect(c.advance(hours:0.001,moisture:45,windowOpen:false,daylight:true,fertilizer:100))
        expectEqual(c.overfedHours,24,accuracy:0.000001)
        c.observeFertilizer(99.999); expectEqual(c.overfedHours,0)
        expect(!c.advance(hours:48,moisture:45,windowOpen:false,daylight:true,fertilizer:99.999))
        expect(!c.advance(hours:48,moisture:45,windowOpen:false,daylight:true,fertilizer:0))
        expect(!c.advance(hours:23,moisture:45,windowOpen:false,daylight:true,fertilizer:100))
        c.observeFertilizer(50)
        expect(!c.advance(hours:1,moisture:45,windowOpen:false,daylight:true,fertilizer:100))
    }
    func testRealSlowReleaseOverdose() {
        var p = adopted(); for _ in 0..<4 { p.feed() }
        expectEqual(p.fertilizer,100)
        tendKeepingFertilizer(&p,hours:23.9)
        expectEqual(p.fertilizer,100); expectEqual(p.prunableLeafIDs.count,0)
        tendKeepingFertilizer(&p,hours:0.1)
        expectEqual(p.prunableLeafIDs.count,1)
        p.fertilizer = 99
        expectEqual(p.yellowingConditions.overfedHours,0)
        tendKeepingFertilizer(&p,hours:24)
        expectEqual(p.prunableLeafIDs.count,1)
    }
    func testMomentaryHundredDoesNotFakeExposure() {
        var p = adopted(); p.fertilizer = 100
        tendKeepingFertilizer(&p,hours:24)
        expectLess(p.fertilizer,100)
        expectEqual(p.yellowingConditions.overfedHours,0); expectEqual(p.prunableLeafIDs.count,0)
    }
    func testFertilizerPersistenceAndOldTimers() throws {
        var p = adopted(); for _ in 0..<4 { p.feed() }
        tendKeepingFertilizer(&p,hours:23)
        var restored = try JSONDecoder().decode(Plant.self,from:JSONEncoder().encode(p))
        expectEqual(restored.yellowingConditions,p.yellowingConditions)
        tendKeepingFertilizer(&restored,hours:1)
        expectEqual(restored.fertilizer,100); expectEqual(restored.prunableLeafIDs.count,1)
        let old = Data(#"{"wetHours":12,"dryHours":0,"openNightHours":33}"#.utf8)
        let c = try JSONDecoder().decode(YellowingConditions.self,from:old)
        expectEqual(c.wetHours,12); expectEqual(c.openNightHours,33); expectEqual(c.overfedHours,0)
    }
    func testSimultaneousThresholdsStaySequential() {
        var p = adopted(); for _ in 0..<4 { p.feed() }
        tend(&p,hours:24,moisture:100,fertilizer:100)
        expectEqual(p.prunableLeafIDs.count,1)
        expectEqual(p.leaves.filter { $0.phase == .green }.count,5)
    }
    func testLegacyPestsAreRemoved() throws {
        let old = Data(#"{"adopted":true,"moisture":45,"health":95,"pests":100}"#.utf8)
        var p = try JSONDecoder().decode(Plant.self,from:old)
        p.advance(hours:1,climate:Climate())
        expectGreater(p.health,95)
        let saved = try JSONSerialization.jsonObject(with:JSONEncoder().encode(p)) as! [String:Any]
        expect(saved["pests"] == nil)
    }
    func testLegacySaveMigration() throws {
        let data = Data(#"{"adopted":true,"moisture":51,"fertilizer":28,"yellowing":84,"ageHours":77}"#.utf8)
        let p = try JSONDecoder().decode(Plant.self,from:data)
        expect(p.adopted); expectEqual(p.moisture,51); expectEqual(p.ageHours,77)
        expectEqual(p.leaves.count,6); expectEqual(p.prunableLeafIDs.count,6)
        expectEqual(p.leaves.filter { $0.phase == .green }.count,0)
    }
}
func expect(_ condition: Bool, file: StaticString = #file, line: UInt = #line) { precondition(condition,"Check failed",file:file,line:line) }
func expectEqual<T: Equatable>(_ a: T,_ b: T,file: StaticString = #file,line: UInt = #line) { precondition(a == b,"Expected \(a) == \(b)",file:file,line:line) }
func expectEqual(_ a: Double,_ b: Double,accuracy: Double,file: StaticString = #file,line: UInt = #line) { precondition(abs(a-b) <= accuracy,"Values differ: \(a), \(b)",file:file,line:line) }
func expectGreater(_ a: Double,_ b: Double,file: StaticString = #file,line: UInt = #line) { precondition(a>b,"Expected \(a) > \(b)",file:file,line:line) }
func expectLess(_ a: Double,_ b: Double,file: StaticString = #file,line: UInt = #line) { precondition(a<b,"Expected \(a) < \(b)",file:file,line:line) }
let checks = PlantTests()
try checks.testPlantNaming()
try checks.testTwoLeafStartAndSequentialGrowth()
try checks.testLegacyParallelGrowthBecomesSequential()
checks.testUnadoptedDoesNotAdvance()
checks.testVentilationDriesSoilAndRelievesRoots()
checks.testSequentialYellowing()
checks.testYellowIsIrreversibleAndWithers()
checks.testModerateFeedAndExcess()
checks.testPruningProtectsHealthyAndKeepsSlots()
checks.testRegrowthAtSameSlotOverTwoDays()
checks.testGrowthPausesAndResumes()
checks.testSmallLeafDamagedByDryness()
checks.testSmallLeafDamagedByOverwatering()
checks.testAllPrunedAndMaximumSix()
checks.testNoSproutWithoutGoodConditions()
checks.testJumpConsistencyAndBounds()
checks.testContinuousWatering()
try checks.testLifecyclePersistence()
try checks.testLegacySaveMigration()
checks.testExactWetThreshold()
checks.testExactDryThreshold()
checks.testNightThresholdAndDayPause()
checks.testNaturalDryingCannotFakeSustainedWetness()
checks.testOnlyListedConditionsCanYellow()
checks.testInstantCareResetsTimers()
try checks.testExposurePersistenceAndOldStressMigration()
checks.testZeroFertilizerIsSafeAndGrows()
checks.testFertilizerSpeedsVisibleNewLeaves()
checks.testExactFertilizerThresholdAndReset()
checks.testRealSlowReleaseOverdose()
checks.testMomentaryHundredDoesNotFakeExposure()
try checks.testFertilizerPersistenceAndOldTimers()
checks.testSimultaneousThresholdsStaySequential()
try checks.testLegacyPestsAreRemoved()
print("PASS: 34 plant checks, including exact 24/48-hour exposure, inclusive thresholds, timer resets/persistence, no early yellowing, irreversible per-leaf lifecycle, pruning, 48-hour growth, pause/resume, small-leaf damage, six-slot limit and save migration")
