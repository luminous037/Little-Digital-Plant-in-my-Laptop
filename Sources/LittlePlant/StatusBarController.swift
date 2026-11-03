import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private weak var store: GardenStore?

    func install(store: GardenStore) {
        guard item == nil else { return }
        self.store = store
        let status = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        item = status // Retain the item for the entire app lifetime.
        status.isVisible = true
        if let button = status.button {
            let icon = NSImage(systemSymbolName:"leaf.fill",accessibilityDescription:"Little Plant")
            icon?.size = NSSize(width:18,height:18); icon?.isTemplate = true
            button.image = icon
            if icon == nil { button.title = "🌱" }
            button.toolTip = "Little Plant · 작은 식물방"
            button.setAccessibilityLabel("Little Plant")
            button.target = self; button.action = #selector(handleClick)
            button.sendAction(on:[.leftMouseUp,.rightMouseUp])
        }
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width:420,height:432)
        popover.contentViewController = NSHostingController(rootView:GardenView(store:store).frame(width:420))
        if CommandLine.arguments.contains("--status-check") {
            DispatchQueue.main.asyncAfter(deadline:.now()+1) { self.verify() }
        }
    }
    @objc private func handleClick() {
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            guard let button = item?.button else { return }
            popover.close()
            contextMenu().popUp(positioning:nil,at:NSPoint(x:0,y:button.bounds.minY),in:button)
        } else { toggle() }
    }
    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        let quit = NSMenuItem(title:store?.english == true ? "Quit Little Plant" : "Little Plant 종료",action:#selector(quitApp),keyEquivalent:"q")
        quit.target = self; menu.addItem(quit)
        return menu
    }
    @objc private func quitApp() {
        store?.save()
        NSApp.terminate(nil)
    }
    private func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = item?.button {
            NSApp.activate(ignoringOtherApps:true)
            popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    private func verify() {
        precondition(item?.isVisible == true && item?.button?.image != nil,"Status icon must exist and be visible")
        let menu = contextMenu()
        precondition(menu.items.count == 1 && menu.items[0].action == #selector(quitApp) && menu.items[0].target === self,"Status context menu must expose the working quit action")
        item?.button?.performClick(nil)
        precondition(popover.isShown,"First status-button click must open the anchored popover")
        DispatchQueue.main.asyncAfter(deadline:.now()+0.6) {
            self.item?.button?.performClick(nil)
            DispatchQueue.main.asyncAfter(deadline:.now()+0.6) {
                precondition(!self.popover.isShown,"Second status-button click must hide the popover")
                fputs("PASS: retained visible status icon, first click opens anchored popover, second click closes it, context menu quit action\n",stderr)
                NSApp.terminate(nil)
            }
        }
    }
}
