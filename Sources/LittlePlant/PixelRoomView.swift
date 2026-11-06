import AppKit
import SceneKit
import Metal

/// A 256-pixel framebuffer, scaled without smoothing. Hover affects only scene nodes.
final class PixelRoomView: NSView {
    private let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    private let resolution = NSSize(width: 256, height: 208)
    private var frameImage: NSImage?
    private var pixelSky: PixelSkyNode?
    private let watering = WateringRig()
    private let musicRig = MusicRig()
    private weak var music: RoomMusic?
    private var onAlbumTap: (String) -> Void = { _ in }
    private var hoveredAlbumID: String?
    private var onCordPull: () -> Void = {}
    func configureMusic(_ music: RoomMusic?,onAlbumTap:@escaping (String) -> Void) {
        self.music = music; self.onAlbumTap = onAlbumTap
        self.onCordPull = { [weak music] in music?.pullCord() }
        if let music { musicRig.configure(music) }
    }
    private let fallingLeaves = FallingLeaves()
    private let fertilizer = FallingFertilizer()
    private var fertilizerPulse: Int?
    func receiveFertilizerPulse(_ pulse:Int) {
        if let previous = fertilizerPulse, pulse > previous { for _ in previous..<pulse { fertilizer.emit() } }
        fertilizerPulse = pulse
    }
    private var dragDepth: CGFloat = 0
    private var pruningMode = false
    private var prunableSlots: Set<Int> = []
    private var onPruneLeaf: (Int) -> Bool = { _ in false }
    private let scissorsCursor: NSCursor = {
        guard let image = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Scissors")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 19, weight: .regular)) else { return .crosshair }
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()
    private var timer: Timer?
    private var rain: PixelRainNode?
    private var snow:PixelSnowNode?
    private var lightning:LightningNode?
    private var epoch = Date()
    private var lastFrame = Date()
    private var tracking: NSTrackingArea?
    private var hoveredTarget: String?
    private var windowHover: CGFloat = 0
    private var plantBrushElapsed: Double?
    private let brushDuration = 0.85
    private var sashes: [(node: SCNNode, angle: CGFloat)] = []
    private var leaves: [(node: SCNNode, angles: SCNVector3)] = []
    var onBackgroundTap: () -> Void = {}
    var onWindowTap: () -> Void = {}
    var onPlantTap: () -> Void = {}
    var onBookTap: () -> Void = {}
    var onPhotoAlbumTap: () -> Void = {}
    private var photoBook: (node:SCNNode,z:CGFloat)?
    private var photoBookHover: CGFloat = 0
    private var interactionsEnabled = true
    private var book: (node: SCNNode, z: CGFloat)?
    private var bookHover: CGFloat = 0
    func setInteractionsEnabled(_ enabled: Bool) {
        interactionsEnabled = enabled
        if !enabled { musicRig.cancelCordAnimation(); hoveredTarget = nil; plantBrushElapsed = nil; watering.suspend() }
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    func setScene(_ scene: SCNScene) {
        renderer.scene = scene
        pixelSky = scene.rootNode.childNodes.compactMap { $0 as? PixelSkyNode }.first
        rain = scene.rootNode.childNodes.compactMap { $0 as? PixelRainNode }.first
        snow = scene.rootNode.childNodes.compactMap { $0 as? PixelSnowNode }.first
        lightning = scene.rootNode.childNodes.compactMap { $0 as? LightningNode }.first
        musicRig.attach(to:scene)
        watering.attach(to: scene)
        fallingLeaves.attach(to: scene)
        fertilizer.attach(to:scene)
        renderer.pointOfView = scene.rootNode.childNodes.first(where: { $0.camera != nil })
        sashes = scene.rootNode.childNodes.filter { $0.name == "window" && $0.geometry == nil }.map { ($0, $0.eulerAngles.y) }
        book = scene.rootNode.childNode(withName: "book", recursively: true).map { ($0, $0.position.z) }
        photoBook = scene.rootNode.childNode(withName:"photoAlbumBook",recursively:true).map { ($0,$0.position.z) }
        leaves = []
        scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "leaf" { self.leaves.append((node, node.eulerAngles)) }
        }
        epoch = Date(); lastFrame = epoch
        renderFrame()
    }
    func setWateringMode(_ enabled: Bool, onSoilWater: @escaping (Double) -> Void, onEnd: @escaping () -> Void) {
        watering.onSoilWater = onSoilWater; watering.onEnd = onEnd
        watering.setEnabled(enabled)
    }
    func setPruningMode(_ enabled: Bool, allowed: Set<Int>, onPrune: @escaping (Int) -> Bool) {
        pruningMode = enabled; prunableSlots = allowed; onPruneLeaf = onPrune
        if enabled { hoveredTarget = nil; plantBrushElapsed = nil }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate(); timer = nil
        if let window {
            window.acceptsMouseMovedEvents = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12, repeats: true) { [weak self] _ in
                guard let self else { return }
                guard self.window?.isVisible == true else {
                    self.cancelCordAnimation()
                    self.watering.suspend()
                    self.fallingLeaves.clear()
                    self.fertilizer.clear()
                    self.hoveredTarget = nil
                    self.plantBrushElapsed = nil
                    self.updateAffordances(time: 0, delta: 1)
                    return
                }
                self.renderFrame()
            }
        } else {
            musicRig.cancelCordAnimation()
            watering.suspend()
            fallingLeaves.clear()
            fertilizer.clear()
            hoveredTarget = nil
            plantBrushElapsed = nil
            updateAffordances(time: 0, delta: 1)
        }
    }
    private func cancelCordAnimation() { musicRig.cancelCordAnimation() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area); tracking = area
    }
    override func mouseEntered(with event: NSEvent) { trackPointer(event) }
    override func mouseMoved(with event: NSEvent) { trackPointer(event) }
    override func cursorUpdate(with event: NSEvent) { trackPointer(event) }
    override func mouseExited(with event: NSEvent) {
        hoveredTarget = nil
        NSCursor.arrow.set()
    }
    private func trackPointer(_ event: NSEvent) {
        guard interactionsEnabled, !watering.grabbed else { return }
        let p = convert(event.locationInWindow, from: nil)
        let musicTarget = hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height))
        if ["cdAlbum","cdDisc","cdCord"].contains(musicTarget ?? "") {
            hoveredTarget = musicTarget
            hoveredAlbumID = musicTarget == "cdAlbum" ? albumID(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)) : nil
            NSCursor.pointingHand.set(); return
        }
        if music?.presenting == true { hoveredTarget = nil; NSCursor.arrow.set(); return }
        if ["book","photoAlbumBook"].contains(hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)) ?? "") { hoveredTarget = hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)); NSCursor.pointingHand.set(); return }
        if pruningMode {
            hoveredTarget = nil
            let id = pruningTarget(x: p.x / max(1,bounds.width), y: p.y / max(1,bounds.height))
            (id.map { prunableSlots.contains($0) } == true ? scissorsCursor : NSCursor.operationNotAllowed).set()
            return
        }
        let target = bounds.contains(p) ? hitTarget(x: p.x / max(1, bounds.width), y: p.y / max(1, bounds.height)) : nil
        if target == "plant", hoveredTarget != "plant" { plantBrushElapsed = 0 }
        hoveredTarget = target
        (hoveredTarget == "wateringCan" ? NSCursor.openHand : (hoveredTarget == nil ? NSCursor.arrow : NSCursor.pointingHand)).set()
    }
    private func updateAffordances(time: Double, delta: Double) {
        let blend = CGFloat(min(1, max(0, delta) * 8))
        photoBookHover += ((hoveredTarget == "photoAlbumBook" ? 1 : 0)-photoBookHover)*blend
        if let photoBook { photoBook.node.position.z = photoBook.z+0.17*photoBookHover }
        bookHover += ((hoveredTarget == "book" ? 1 : 0) - bookHover) * blend
        if let book { book.node.position.z = book.z + 0.17 * bookHover }
        windowHover += ((hoveredTarget == "window" ? 1 : 0) - windowHover) * blend
        if let elapsed = plantBrushElapsed {
            let next = elapsed + max(0, delta)
            plantBrushElapsed = next < brushDuration ? next : nil
        }
        for sash in sashes {
            let direction: CGFloat = sash.node.position.x < 0 ? -1 : 1
            let peek: CGFloat = abs(sash.angle) > 0.5 ? 0.045 : 0.18
            sash.node.eulerAngles.y = sash.angle + direction * peek * windowHover
        }
        for (index, leaf) in leaves.enumerated() {
            var angles = leaf.angles
            if let elapsed = plantBrushElapsed {
                let progress = elapsed / brushDuration
                let envelope = sin(.pi * progress)
                let phase = progress * 2 * .pi - Double(index) * 0.16
                angles.z += CGFloat(sin(phase) * envelope) * 0.065
                angles.y += CGFloat(sin(phase * 0.8) * envelope) * 0.035
            }
            leaf.node.eulerAngles = angles
        }
    }
    private func renderFrame() {
        guard renderer.scene != nil else { return }
        let now = Date()
        pixelSky?.update(time:now.timeIntervalSinceReferenceDate)
        rain?.update(time:now.timeIntervalSinceReferenceDate)
        snow?.update(time:now.timeIntervalSinceReferenceDate)
        if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "storm-flash" {
            lightning?.update(elapsed:2.26)
        } else { lightning?.update(time:now.timeIntervalSinceReferenceDate) }
        let delta = min(0.2, now.timeIntervalSince(lastFrame))
        watering.update(delta)
        fallingLeaves.update(delta)
        fertilizer.update(delta)
        musicRig.hoveredAlbumID = hoveredTarget == "cdAlbum" ? hoveredAlbumID : nil
        musicRig.update(delta)
        updateAffordances(time: now.timeIntervalSince(epoch), delta: delta)
        lastFrame = now
        frameImage = renderer.snapshot(atTime: now.timeIntervalSince(epoch), with: resolution, antialiasingMode: .none)
        needsDisplay = true
    }
    func roomSnapshot() -> NSImage? {
        renderFrame()
        guard let frameImage else { return nil }
        let image = NSImage(size:bounds.size)
        image.lockFocusFlipped(true)
        NSGraphicsContext.current?.imageInterpolation = .none
        frameImage.draw(in:bounds,from:.zero,operation:.copy,fraction:1,respectFlipped:true,hints:nil)
        drawAlbumTitles()
        image.unlockFocus()
        return image
    }
    func photoAlbumPoint() -> CGPoint? {
        guard let photoBook else { return nil }
        let p = renderer.projectPoint(photoBook.node.worldPosition)
        return CGPoint(x:p.x/resolution.width,y:1-p.y/resolution.height)
    }
    private func drawAlbumTitles() {
        guard music != nil else { return }
        // Project vector-sharp lettering onto the same face as the low-resolution album art.
        for track in RoomTrack.library {
            let album = musicRig.albumNode(id:track.id)
            func point(_ x:CGFloat,_ y:CGFloat) -> CGPoint {
                let p = renderer.projectPoint(album.convertPosition(SCNVector3(x,y,0.027),to:nil))
                return CGPoint(x:p.x/resolution.width*bounds.width,y:(1-p.y/resolution.height)*bounds.height)
            }
            let origin = point(-0.14,0.14), right = point(0.14,0.14), down = point(-0.14,-0.14)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.transformStruct = NSAffineTransformStruct(m11:(right.x-origin.x)/256,m12:(right.y-origin.y)/256,m21:(down.x-origin.x)/256,m22:(down.y-origin.y)/256,tX:origin.x,tY:origin.y)
            transform.concat()
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
            let baseFont = NSFont(name:RetroFonts.clock,size:32) ?? NSFont.systemFont(ofSize:32)
            let width = (track.title as NSString).size(withAttributes:[.font:baseFont]).width
            let font = NSFont(name:RetroFonts.clock,size:32*min(1,240/max(1,width))) ?? baseFont
            let attrs: [NSAttributedString.Key:Any] = [.font:font,.foregroundColor:NSColor(white:0.09,alpha:1),.paragraphStyle:paragraph]
            (track.title as NSString).draw(in:NSRect(x:3,y:198,width:250,height:42),withAttributes:attrs)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 0.81, alpha: 1).setFill(); bounds.fill()
        NSGraphicsContext.current?.imageInterpolation = .none
        frameImage?.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        drawAlbumTitles()
    }
    override func mouseDown(with event: NSEvent) {
        guard interactionsEnabled else { return }
        let p = convert(event.locationInWindow, from: nil)
        let musicTarget = hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height))
        if musicTarget == "cdCord" { if musicRig.triggerCord() { onCordPull() }; NSCursor.pointingHand.set(); return }
        if musicTarget == "cdAlbum" || musicTarget == "cdDisc" { activate(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)); return }
        if music?.presenting == true { music?.dismissAlbum(); return }
        if ["book","photoAlbumBook"].contains(hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)) ?? "") { activate(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)); return }
        if pruningMode {
            if let id = pruningTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)), prunableSlots.contains(id) { cutLeaf(id) }
            return
        }
        if hitTarget(x:p.x/max(1,bounds.width),y:p.y/max(1,bounds.height)) == "wateringCan", watering.enabled {
            dragDepth = renderer.projectPoint(watering.can.position).z
            watering.grab(at: worldPoint(p)); hoveredTarget = nil; NSCursor.closedHand.set()
        } else { activate(x: p.x / max(1, bounds.width), y: p.y / max(1, bounds.height)) }
    }
    private func cutLeaf(_ id: Int) {
        guard let source = leaves.first(where: { ($0.node as? LeafSceneNode)?.slot == id })?.node else { return }
        // Capture the current world pose before the model's synchronous cut can replace the scene.
        let blade = FallingLeaves.snapshot(source)
        guard onPruneLeaf(id) else { return }
        source.isHidden = true
        leaves.removeAll { ($0.node as? LeafSceneNode)?.slot == id }
        prunableSlots.remove(id)
        fallingLeaves.add(blade)
        renderFrame()
    }
    override func mouseDragged(with event: NSEvent) {
        guard watering.grabbed else { return }
        let p = convert(event.locationInWindow, from:nil)
        watering.drag(to:worldPoint(p),inside:bounds.contains(p))
        NSCursor.closedHand.set()
    }
    override func mouseUp(with event: NSEvent) {
        if watering.grabbed { watering.finish(); NSCursor.openHand.set() }
    }
    private func worldPoint(_ point: NSPoint) -> SCNVector3 {
        renderer.unprojectPoint(SCNVector3(point.x/max(1,bounds.width)*resolution.width,(1-point.y/max(1,bounds.height))*resolution.height,dragDepth))
    }
    private func activate(x: CGFloat, y: CGFloat) {
        switch hitTarget(x: x, y: y) {
        case "window": onWindowTap()
        case "plant": onPlantTap()
        case "book": onBookTap()
        case "photoAlbumBook": onPhotoAlbumTap()
        case "cdAlbum":
            if let id = albumID(x:x,y:y) {
                if music?.phase == .shelf { onAlbumTap(id) }
                else if music?.phase == .album && music?.track.id == id { music?.selectPresented() }
            }
        case "cdDisc":
            if music?.phase == .disc { music?.selectPresented() } else { music?.eject() }
        default: onBackgroundTap()
        }
    }
    private func hitTarget(x: CGFloat, y: CGFloat) -> String? {
        let point = CGPoint(x: x * resolution.width, y: (1 - y) * resolution.height)
        for hit in renderer.hitTest(point, options: [.categoryBitMask: 1]) {
            var node: SCNNode? = hit.node
            while let current = node {
                if current.name == "window" || current.name == "plant" || current.name == "wateringCan" || current.name == "book" || current.name == "photoAlbumBook" || current.name == "cdAlbum" || current.name == "cdDisc" || current.name == "cdCord" { return current.name }
                node = current.parent
            }
        }
        return nil
    }
    private func albumID(x:CGFloat,y:CGFloat) -> String? {
        for hit in renderer.hitTest(CGPoint(x:x*resolution.width,y:(1-y)*resolution.height),options:[.categoryBitMask:1]) {
            var node: SCNNode? = hit.node
            while let current = node {
                if let album = current as? AlbumSceneNode { return album.trackID }
                node = current.parent
            }
        }
        return nil
    }
    private func leafSlot(x: CGFloat, y: CGFloat) -> Int? {
        let point = CGPoint(x: x * resolution.width, y: (1-y) * resolution.height)
        guard let hit = renderer.hitTest(point, options: [.categoryBitMask: 1]).first else { return nil }
        var node: SCNNode? = hit.node
        while let current = node {
            if let leaf = current as? LeafSceneNode { return leaf.slot }
            node = current.parent
        }
        return nil
    }
    private func pruningTarget(x: CGFloat, y: CGFloat) -> Int? {
        // Respect the frontmost healthy leaf; never cut a damaged leaf through it.
        if let id = leafSlot(x:x,y:y) { return prunableSlots.contains(id) ? id : nil }
        // Tiny curled seedlings remain selectable within four framebuffer pixels of their centre.
        var nearest: (id: Int, distance: CGFloat)?
        for entry in leaves {
            guard let leaf = entry.node as? LeafSceneNode, prunableSlots.contains(leaf.slot) else { continue }
            let point = renderer.projectPoint(leaf.convertPosition(SCNVector3(0,-0.4,0.025),to:nil))
            let distance = hypot(point.x-x*resolution.width,(resolution.height-point.y)-y*resolution.height)
            if distance <= 4 && (nearest == nil || distance < nearest!.distance) { nearest = (leaf.slot,distance) }
        }
        return nearest?.id
    }
    func verifyHitTargets() {
        let savedMusic = music, savedAlbumCallback = onAlbumTap
        let fixture = RoomMusic()
        configureMusic(fixture,onAlbumTap:{ fixture.selectAlbum(id:$0) })
        musicRig.update(1); renderFrame()
        defer {
            configureMusic(savedMusic,onAlbumTap:savedAlbumCallback)
            musicRig.update(1); renderFrame()
        }
        let savedInteractions = interactionsEnabled
        interactionsEnabled = true
        defer { setInteractionsEnabled(savedInteractions) }
        // Exercise real click dispatch without invoking game mutations or saving data.
        let savedWindow = onWindowTap, savedPlant = onPlantTap
        var windowActivated = false, plantActivated = false
        onWindowTap = { windowActivated = true }
        onPlantTap = { plantActivated = true }
        activate(x: 0.75, y: 0.25)
        activate(x: 0.35, y: 0.84)
        precondition(windowActivated && plantActivated, "Room clicks must match visible objects")
        windowActivated = false; plantActivated = false

        // Deliver view-coordinate mouse events, including the flipped AppKit origin.
        func hoverEvent(x: CGFloat, y: CGFloat) -> NSEvent {
            let location = convert(NSPoint(x: x * bounds.width, y: y * bounds.height), to: nil)
            return NSEvent.mouseEvent(with: .mouseMoved, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window!.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        }
        let savedCursor = NSCursor.current
        // A hover must move the right geometry, return to its true state, and never click.
        precondition(sashes.count == 2, "Expected interactive scene geometry")
        mouseMoved(with: hoverEvent(x: 0.75, y: 0.25))
        precondition(hoveredTarget == "window", "Mouse coordinates must identify the visible window")
        updateAffordances(time: 1, delta: 1)
        precondition(abs(sashes[0].node.eulerAngles.y - sashes[0].angle) > 0.02, "Window must peek on hover")
        mouseMoved(with: hoverEvent(x: 0.35, y: 0.84))
        precondition(hoveredTarget == "plant", "Mouse coordinates must identify the visible plant")
        updateAffordances(time: 1, delta: 0.2)
        precondition(abs(sashes[0].node.eulerAngles.y - sashes[0].angle) < 0.0001, "Window must restore its real state")
        precondition(leaves.isEmpty || leaves.contains { abs($0.node.eulerAngles.z - $0.angles.z) > 0.01 }, "Leaves must sway on hover")
        updateAffordances(time: 2, delta: 1)
        precondition(hoveredTarget == "plant" && plantBrushElapsed == nil, "Brush must finish while the pointer stays on the plant")
        mouseMoved(with: hoverEvent(x: 0.35, y: 0.84))
        updateAffordances(time: 2.2, delta: 0.2)
        precondition(plantBrushElapsed == nil && leaves.allSatisfy { abs($0.node.eulerAngles.z - $0.angles.z) < 0.0001 }, "Moving within the plant must not repeat the brush")
        mouseExited(with: hoverEvent(x: 0, y: 0))
        mouseMoved(with: hoverEvent(x: 0.35, y: 0.84))
        precondition(plantBrushElapsed != nil, "A fresh entry must trigger a new brush")
        mouseExited(with: hoverEvent(x: 0, y: 0))
        updateAffordances(time: 2, delta: 1)
        precondition(leaves.allSatisfy { abs($0.node.eulerAngles.z - $0.angles.z) < 0.0001 && abs($0.node.eulerAngles.y - $0.angles.y) < 0.0001 }, "Leaves must settle on exit")
        precondition(!windowActivated && !plantActivated, "Hover must not trigger gameplay")
        onWindowTap = savedWindow; onPlantTap = savedPlant
        savedCursor.set()
        verifyMusicHitTargets()
        verifyBookInteraction()
        verifyPhotoAlbumBook()
        verifyPruningSelection()
        verifyLeafFall()
        fertilizer.verify()
        WitheredLeaf.verify()
        watering.verify()
        verifyCanMouseEvents()
        if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "water" {
            watering.stagePreviewPour()
        }
        if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "leaf-cut" {
            stageCutPreview()
        }
        if CommandLine.arguments.contains("--render-preview"), ProcessInfo.processInfo.environment["LITTLE_PLANT_SCENARIO"] == "fertilizer" {
            fertilizer.emit(); fertilizer.update(0.65)
        }
        renderFrame()
        fputs("PASS: click dispatch, window peek, one-shot leaf brush, no repeat on sustained hover, re-entry, restoration, no gameplay on hover\n", stderr)
    }
    private func verifyMusicHitTargets() {
        guard music != nil else { preconditionFailure("Music model must be attached") }
        func event(_ type:NSEvent.EventType,_ point:NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with:type,location:convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        }
        func point(_ node:SCNNode,_ local:SCNVector3 = SCNVector3Zero) -> NSPoint {
            let p = renderer.projectPoint(node.convertPosition(local,to:nil))
            return NSPoint(x:p.x/resolution.width*bounds.width,y:(1-p.y/resolution.height)*bounds.height)
        }
        let savedCord = onCordPull
        var pulls = 0; onCordPull = { pulls += 1 }
        let grip = point(musicRig.cord,SCNVector3(0,-1.31,0.03))
        precondition(hitTarget(x:grip.x/bounds.width,y:grip.y/bounds.height) == "cdCord","Cord grip must be reachable")
        mouseDown(with:event(.leftMouseDown,grip)); mouseUp(with:event(.leftMouseUp,grip))
        precondition(pulls == 1,"One click must toggle playback exactly once")
        musicRig.update(0.12)
        precondition(musicRig.pull > 0,"Click must animate the cord down without dragging")
        mouseDown(with:event(.leftMouseDown,grip)); mouseUp(with:event(.leftMouseUp,grip))
        precondition(pulls == 1,"Repeated clicks during the pull must not double-toggle")
        musicRig.update(0.6)
        precondition(musicRig.pull == 0,"Cord must return automatically")
        onCordPull = savedCord
        for track in RoomTrack.library {
            let fixture = RoomMusic()
            configureMusic(fixture,onAlbumTap:{ fixture.selectAlbum(id:$0) })
            hoveredTarget = nil; musicRig.update(1); renderFrame()
            let selected = musicRig.albumNode(id:track.id)
            let albumPoint = point(selected,SCNVector3(0,0,0.03))
            precondition(hitTarget(x:albumPoint.x/bounds.width,y:albumPoint.y/bounds.height) == "cdAlbum","Each shelf album must be clickable")
            precondition(albumID(x:albumPoint.x/bounds.width,y:albumPoint.y/bounds.height) == track.id,"Hit must identify the correct album")
            mouseMoved(with:event(.mouseMoved,albumPoint)); renderFrame(); musicRig.update(1)
            precondition(selected.position.z > -0.60,"Each album must slide out independently")
            mouseDown(with:event(.leftMouseDown,albumPoint)); precondition(fixture.phase == .album && fixture.track.id == track.id)
            musicRig.update(1); renderFrame()
            let presented = point(selected,SCNVector3(0,0,0.03))
            mouseDown(with:event(.leftMouseDown,presented)); precondition(fixture.phase == .disc)
            musicRig.update(1); renderFrame()
            let cd = point(musicRig.disc,SCNVector3(0.13,0,0.01))
            mouseDown(with:event(.leftMouseDown,cd)); precondition(fixture.phase == .inserting && fixture.track.id == track.id)
        }
        // Restore a fresh shelf fixture before the existing room tests.
        let fresh = RoomMusic()
        configureMusic(fresh,onAlbumTap:{ fresh.selectAlbum(id:$0) })
        hoveredTarget = nil; musicRig.update(1)
        fputs("PASS: all album IDs/hover/hits, case extraction, CD insertion hit, cord click animation, automatic return, repeated-click guard\n",stderr)
    }
    private func verifyPhotoAlbumBook() {
        guard let photoBook else { return }
        let callback = onPhotoAlbumTap
        var opened = false; onPhotoAlbumTap = { opened = true }
        let projected = renderer.projectPoint(photoBook.node.convertPosition(SCNVector3(0,0,0.24),to:nil))
        let x = projected.x/resolution.width, y = 1-projected.y/resolution.height
        precondition(hitTarget(x:x,y:y) == "photoAlbumBook","White album book must be clickable beside the guide")
        activate(x:x,y:y); precondition(opened)
        hoveredTarget = "photoAlbumBook"; updateAffordances(time:0,delta:1)
        precondition(photoBook.node.position.z > photoBook.z+0.1,"Photo album must pull out on hover")
        hoveredTarget = nil; updateAffordances(time:0,delta:1)
        precondition(abs(photoBook.node.position.z-photoBook.z)<0.0001)
        onPhotoAlbumTap = callback
        fputs("PASS: shelf photo-album hit, opening callback, hover pull-out and return\n",stderr)
    }
    private func verifyBookInteraction() {
        guard let book else { preconditionFailure("Expected one book") }
        let enabled = watering.enabled, callback = onBookTap
        watering.setEnabled(false)
        let point = renderer.projectPoint(book.node.convertPosition(SCNVector3(0,0,0.24),to:nil))
        let x = point.x/resolution.width, y = 1-point.y/resolution.height
        precondition(hitTarget(x:x,y:y) == "book", "Visible book must be clickable")
        var opened = false
        onBookTap = { opened = true }
        activate(x:x,y:y)
        precondition(opened, "Book click must open guide")
        hoveredTarget = "book"; updateAffordances(time:0,delta:1)
        precondition(book.node.position.z > book.z+0.1, "Book must slide out on hover")
        hoveredTarget = nil; updateAffordances(time:0,delta:1)
        precondition(abs(book.node.position.z-book.z)<0.0001, "Book must return to shelf")
        onBookTap = callback
        watering.setEnabled(enabled)
        fputs("PASS: bookshelf book hit, opening, hover slide and return\n",stderr)
    }
    private func verifyPruningSelection() {
        guard !leaves.isEmpty else { return }
        let oldMode = pruningMode, oldAllowed = prunableSlots, oldCallback = onPruneLeaf
        var picked: (Int, CGPoint)?
        for y in stride(from: 0.15, through: 0.80, by: 0.04) {
            for x in stride(from: 0.15, through: 0.65, by: 0.04) {
                if let id = leafSlot(x:x,y:y) { picked = (id,CGPoint(x:x,y:y)); break }
            }
            if picked != nil { break }
        }
        guard let (id, point) = picked else { preconditionFailure("Expected a visible leaf") }
        let local = NSPoint(x:point.x*bounds.width,y:point.y*bounds.height)
        let click = NSEvent.mouseEvent(with:.leftMouseDown,location:convert(local,to:nil),modifierFlags:[],timestamp:0,windowNumber:window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        var cut: Int?
        setPruningMode(true,allowed:[],onPrune:{ cut = $0; return false })
        mouseDown(with:click); precondition(cut == nil,"Healthy leaves must be protected from scissors")
        setPruningMode(true,allowed:[id],onPrune:{ cut = $0; return false })
        mouseDown(with:click); precondition(cut == id,"Scissors must target the clicked leaf's slot")
        precondition(fallingLeaves.count == 0, "Rejected cuts must not animate")
        let originalLeaves = leaves
        let source = leaves.first { ($0.node as? LeafSceneNode)?.slot == id }!.node
        setPruningMode(true,allowed:[id],onPrune:{ cut = $0; return true })
        mouseDown(with:click)
        precondition(source.isHidden && leaves.count == originalLeaves.count-1 && fallingLeaves.count == 1, "Accepted cut must detach exactly one visual leaf")
        fallingLeaves.clear(); source.isHidden = false; leaves = originalLeaves
        setPruningMode(oldMode,allowed:oldAllowed,onPrune:oldCallback)
        renderFrame()
        fputs("PASS: individual leaf hit test, healthy-leaf protection, rejected/accepted cut animation\n",stderr)
    }
    private func verifyLeafFall() {
        guard let source = leaves.first?.node, let currentScene = renderer.scene else { return }
        let blade = FallingLeaves.snapshot(source)
        let expected = source.presentation.worldPosition
        fallingLeaves.add(blade)
        precondition(abs(blade.worldPosition.y-expected.y) < 0.0001 && abs(blade.worldPosition.x-expected.x) < 0.0001, "Cut blade must keep its world pose")
        precondition(blade.categoryBitMask == FallingLeaves.category, "Cut blade must not be a selectable leaf")
        fallingLeaves.update(0.40)
        precondition(blade.position.y < expected.y && blade.opacity > 0 && blade.opacity < 1, "Cut leaf must fall and fade")
        let y = blade.position.y, opacity = blade.opacity
        let nextScene = SCNScene()
        fallingLeaves.attach(to:nextScene)
        precondition(abs(blade.position.y-y) < 0.0001 && blade.opacity == opacity && blade.parent === nextScene.rootNode, "Scene refresh must preserve an ongoing fall")
        fallingLeaves.attach(to:currentScene)
        fallingLeaves.update(1)
        precondition(fallingLeaves.count == 0 && blade.parent == nil, "Faded leaves must be removed")
        fputs("PASS: cut leaf world pose, fall/fade, noninteractive ghost, scene-refresh continuity, cleanup\n",stderr)
    }
    private func stageCutPreview() {
        guard let id = prunableSlots.sorted().first else { return }
        let callback = onPruneLeaf
        onPruneLeaf = { _ in true } // Screenshot-only detached blade; never persist fixture data.
        cutLeaf(id)
        onPruneLeaf = callback
        fallingLeaves.update(0.40)
    }
    private func verifyCanMouseEvents() {
        let enabled = watering.enabled
        let callback = watering.onSoilWater, end = watering.onEnd
        let windowCallback = onWindowTap, plantCallback = onPlantTap
        watering.onSoilWater = { _ in }; watering.onEnd = {}
        onWindowTap = {}; onPlantTap = {}
        watering.setEnabled(true); renderFrame()
        let projected = renderer.projectPoint(watering.can.position)
        let start = NSPoint(x: projected.x / resolution.width * bounds.width, y: (1-projected.y/resolution.height)*bounds.height)
        func event(_ type: NSEvent.EventType, _ p: NSPoint) -> NSEvent {
            NSEvent.mouseEvent(with:type,location:convert(p,to:nil),modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window!.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
        }
        mouseDown(with:event(.leftMouseDown,start))
        precondition(watering.grabbed && !watering.pouring,"Clicking the rendered can must grab it without pouring")
        let before = watering.can.position
        let destination = NSPoint(x:start.x-55,y:start.y-35)
        mouseDragged(with:event(.leftMouseDragged,destination))
        precondition(watering.pouring && abs(watering.can.position.x-before.x) > 0.1,"Actual mouse drag must move the can and start pouring")
        mouseUp(with:event(.leftMouseUp,destination))
        precondition(!watering.grabbed && !watering.pouring,"Actual mouse release must stop pouring")
        watering.setEnabled(false)
        watering.onSoilWater = callback; watering.onEnd = end
        onWindowTap = windowCallback; onPlantTap = plantCallback
        if enabled { watering.setEnabled(true) }
        fputs("PASS: rendered can mouse hit, drag coordinates, mouse release\n",stderr)
    }
    deinit { timer?.invalidate() }
}
