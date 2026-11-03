import Foundation
import PlantCore

/// Reproducible, isolated scenes for the screenshot harness. Never used during normal launch.
enum LeafPreview {
    static func make(_ scenario: String) -> Plant? {
        guard scenario.hasPrefix("leaf-") else { return nil }
        var p = Plant(matureLeafCount:6); p.adopted = true
        func maintain(_ hours: Double, moisture: Double = 45, fertilizer: Double = 28) {
            var remaining = hours
            while remaining > 0.000001 {
                p.moisture = moisture; p.fertilizer = fertilizer; p.air = 70
                p.rootStress = 0; p.windowOpen = false
                let dt = min(0.5,remaining); p.advance(hours:dt,climate:Climate()); remaining -= dt
            }
        }
        maintain(scenario == "leaf-empty" ? 144 : (scenario == "leaf-cut" ? 36 : (scenario == "leaf-yellow" ? 48 : 24)),moisture:0)
        switch scenario {
        case "leaf-withered": maintain(24)
        case "leaf-new", "leaf-paused", "leaf-small-yellow", "leaf-fertilizer-zero":
            for id in p.prunableLeafIDs { p.pruneLeaf(id:id) }
            maintain((scenario == "leaf-new" || scenario == "leaf-fertilizer-zero") ? 12 : 6, fertilizer: scenario == "leaf-fertilizer-zero" ? 0 : 28)
            if scenario == "leaf-paused" { maintain(12,moisture:20,fertilizer:0) }
            if scenario == "leaf-small-yellow" { maintain(24,moisture:100) }
        case "leaf-empty":
            for id in p.prunableLeafIDs { p.pruneLeaf(id:id) }
        default: break
        }
        p.windowOpen = false; p.moisture = scenario == "leaf-paused" ? 20 : 45; p.air = 70
        if scenario == "leaf-fertilizer-zero" { p.fertilizer = 0 }
        else if scenario != "leaf-paused" { p.fertilizer = 28 }
        return p
    }
}
