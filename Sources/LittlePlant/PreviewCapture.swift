import AppKit
import SceneKit
import SwiftUI

/// Captures only this app's own view hierarchy; no screen-recording permission needed.
@MainActor
enum PreviewCapture {
    private static var started = false
    private static var previewWindow: NSWindow?
    static func open(store: GardenStore) {
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:420,height:436),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.isReleasedWhenClosed = false
        window.title = "Little Plant · Preview"
        window.contentView = NSHostingView(rootView:GardenView(store:store).frame(width:420))
        window.center(); window.makeKeyAndOrderFront(nil)
        previewWindow = window
        NSApp.activate(ignoringOtherApps:true)
        schedule()
    }
    static func schedule() {
        guard CommandLine.arguments.contains("--render-preview"), !started else { return }
        started = true
        let scenario = ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"]
        let delay: Double = scenario == "music-cycle" ? Double(RoomTrack.library.count)*4+4 : (["book-cover-cycle","photo-flow","photo-book-cycle"].contains(scenario ?? "") ? 6 : 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.frame.width >= 420 }),
                  let view = window.contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                fputs("Preview capture: no visible content window\n", stderr)
                NSApp.terminate(nil); return
            }
            func freezeScenes(_ child: NSView) {
                if let pixelRoom = child as? PixelRoomView {
                    pixelRoom.verifyHitTargets()
                } else if let scene = child as? SCNView {
                    let still = NSImageView(frame: scene.bounds)
                    still.image = scene.snapshot()
                    still.imageScaling = .scaleAxesIndependently
                    still.autoresizingMask = [.width, .height]
                    scene.addSubview(still)
                } else { child.subviews.forEach(freezeScenes) }
            }
            freezeScenes(view)
            view.displayIfNeeded()
            view.cacheDisplay(in: view.bounds, to: bitmap)
            var image = NSImage(size: view.bounds.size); image.addRepresentation(bitmap)
            if ["docs-weather","simulation-effects"].contains(scenario ?? "") {
                let windows = NSApp.windows.filter { $0.isVisible && $0.contentView != nil && $0.frame.width > 200 }
                var captures: [(NSRect,NSImage)] = []
                for window in windows {
                    guard let content = window.contentView, let rep = content.bitmapImageRepForCachingDisplay(in:content.bounds) else { continue }
                    content.cacheDisplay(in:content.bounds,to:rep)
                    let shot = NSImage(size:content.bounds.size); shot.addRepresentation(rep)
                    captures.append((window.convertToScreen(content.convert(content.bounds,to:nil)),shot))
                }
                let bounds = captures.reduce(NSRect.null) { $0.union($1.0) }
                image = NSImage(size:bounds.size); image.lockFocus()
                for (rect,shot) in captures.reversed() { shot.draw(in:rect.offsetBy(dx:-bounds.minX,dy:-bounds.minY)) }
                image.unlockFocus()
            }
            if let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]),
               let path = ProcessInfo.processInfo.environment["LITTLE_PLANT_PREVIEW"] {
                do { try png.write(to: URL(fileURLWithPath:path)); print("Preview saved: \(path)") }
                catch { fputs("Preview write failed: \(error)\n",stderr) }
            }
            NSApp.terminate(nil)
        }
    }
}
