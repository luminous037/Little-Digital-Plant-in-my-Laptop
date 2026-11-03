import SwiftUI
import AppKit
import PlantCore

@main
struct LittlePlantApp: App {
    @StateObject private var store: GardenStore
    init() {
        let garden = GardenStore()
        if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_DOCS"] == "1" {
            garden.english = true
            garden.plant = Plant(matureLeafCount:6); garden.plant.adopted = true
        }
        if CommandLine.arguments.contains("--render-preview") {
            garden.plant.adopted = true
            if let preview = LeafPreview.make(ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] ?? "") { garden.plant = preview }
            if (ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] ?? "").hasPrefix("photo-") { garden.plant = Plant(); garden.plant.adopted = true }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "starter-plant" { garden.plant = Plant(); garden.plant.adopted = true }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "water" { garden.wateringMode = true }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "sky-rain" { garden.setPreset("rain") }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "sky-rain-night" { garden.setPreset("rain"); garden.climate.daylight = false }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "moonlight" { garden.setPreset("night") }
            if ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "cold" {
                garden.setPreset("night")
                garden.plant.windowOpen = true
                garden.plant.advance(hours: 24, climate: garden.climate)
            }

        }
        if CommandLine.arguments.contains("--render-preview") {
            DispatchQueue.main.async { PreviewCapture.open(store: garden) }
        }
        _store = StateObject(wrappedValue: garden)
        DispatchQueue.main.async {
            if let output = ProcessInfo.processInfo.environment["LITTLE_PLANT_ICONSET"] {
                do { try AppIconRenderer.export(to:URL(fileURLWithPath:output)) }
                catch { fputs("Icon export failed: \(error)\n",stderr) }
                NSApp.terminate(nil); return
            }
            if !CommandLine.arguments.contains("--render-preview") { StatusBarController.shared.install(store:garden) }
            garden.startWeatherAtLaunch()
        }
    }
    var body: some Scene {
        Settings { EmptyView() }
    }
}
