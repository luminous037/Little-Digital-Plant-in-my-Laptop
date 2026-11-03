import SwiftUI
import SceneKit
import PlantCore

struct RoomScene: NSViewRepresentable {
    var plant: Plant
    var climate: Climate
    var wateringMode = false
    var pruningMode = false
    var onPruneLeaf: (Int) -> Bool = { _ in false }
    var onSoilWater: (Double) -> Void = { _ in }
    var onWateringEnd: () -> Void = {}
    var onBackgroundTap: () -> Void = {}
    var onWindowTap: () -> Void = {}
    var onPlantTap: () -> Void = {}
    var onBookTap: () -> Void = {}
    var interactionsEnabled = true
    var music: RoomMusic? = nil
    var onAlbumTap: (String) -> Void = { _ in }
    var skyHour = 8
    var fertilizerPulse = 0
    var hasPhotoAlbum = false
    var onPhotoAlbumTap: () -> Void = {}
    var camera: RoomCamera? = nil
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var signature = "" }
    func makeNSView(context: Context) -> PixelRoomView { PixelRoomView() }
    func updateNSView(_ view: PixelRoomView, context: Context) {
        defer { view.receiveFertilizerPulse(fertilizerPulse) }
        view.onWindowTap = onWindowTap; view.onPlantTap = onPlantTap
        view.configureMusic(music,onAlbumTap:onAlbumTap)
        view.onPhotoAlbumTap = onPhotoAlbumTap
        camera?.capture = { [weak view] in view?.roomSnapshot() }
        camera?.albumPoint = { [weak view] in view?.photoAlbumPoint() }
        view.onBookTap = onBookTap; view.setInteractionsEnabled(interactionsEnabled)
        view.onBackgroundTap = onBackgroundTap
        view.setWateringMode(wateringMode, onSoilWater: onSoilWater, onEnd: onWateringEnd)
        view.setPruningMode(pruningMode, allowed: plant.prunableLeafIDs, onPrune: onPruneLeaf)
        let leafSignature = plant.leaves.map { "\($0.id):\($0.phase.rawValue):\(Int($0.maturity*48)):\(Int($0.yellowHours/2))" }.joined(separator: ",")
        let signature = "\(hasPhotoAlbum)-\(skyHour)-\(plant.windowOpen)-\(Int(plant.growth / 5))-\(Int(plant.yellowing / 8))-\(Int(plant.moisture / 10))-\(climate)-\(plant.adopted)-\(Int(plant.fertilizer / 10))-\(leafSignature)"
        guard signature != context.coordinator.signature else { return }
        context.coordinator.signature = signature
        view.setScene(makeRoom())
    }
    func makeRoom() -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode
        scene.background.contents = NSColor(white: 0.91, alpha: 1)
        func material(_ color: NSColor, _ surface: RetroTexture.Surface? = .plaster) -> SCNMaterial {
            let m = SCNMaterial()
            if let surface, color.alphaComponent >= 0.99 {
                m.diffuse.contents = RetroTexture.image(color, surface: surface)
            } else {
                m.diffuse.contents = color
            }
            m.diffuse.magnificationFilter = .nearest
            m.diffuse.minificationFilter = .nearest
            m.diffuse.mipFilter = .none
            m.lightingModel = .lambert; m.isDoubleSided = true
            return m
        }
        @discardableResult func box(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat, _ x: Float, _ y: Float, _ z: Float, _ color: NSColor, surface: RetroTexture.Surface? = .plaster, parent: SCNNode? = nil) -> SCNNode {
            let g = SCNBox(width: w, height: h, length: d, chamferRadius: 0)
            g.materials = [material(color, surface)]
            let n = SCNNode(geometry: g); n.position = SCNVector3(x,y,z); (parent ?? root).addChildNode(n); return n
        }
        let white = NSColor(white: 0.98, alpha: 1)
        let edge = NSColor(white: 0.68, alpha: 1)
        box(4.5, 0.12, 3.6, 0, -0.06, 0, NSColor(white: 0.78, alpha: 1))
        box(4.5, 3.7, 0.12, 0, 1.8, -1.5, white, surface: nil)
        box(0.1, 3.7, 3.1, -2.2, 1.8, 0, NSColor(white: 0.96, alpha: 1), surface: nil)
        box(4.4, 0.1, 0.09, 0, 0.08, -1.39, edge)
        // Fine floor joints preserve the early 3D room aesthetic.
        for i in -3...3 { box(0.012, 0.003, 3.4, Float(i) * 0.65, 0.005, 0, NSColor(white: 0.71, alpha: 1)) }
        root.addChildNode(PixelSkyNode(climate:climate,hour:skyHour))
        // Distant city blocks behind the window.
        for i in 0..<7 {
            box(0.19, CGFloat(0.2 + Double((i * 7) % 4) * 0.09), 0.02, Float(i) * 0.22 - 0.01, 1.52, -1.375, NSColor(white: climate.daylight ? 0.65 : 0.25, alpha: 1))
        }
        if !climate.daylight {
            let moon = SCNSphere(radius: 0.12); moon.segmentCount = 10; moon.materials = [material(NSColor(white: 0.95, alpha: 1))]
            let n = SCNNode(geometry: moon); n.position = SCNVector3(1.15,2.7,-1.35); root.addChildNode(n)
        }
        if climate.rain { root.addChildNode(PixelRainNode(daylight:climate.daylight)) }
        for x: Float in [-0.22, 1.52] { box(0.09, 1.9, 0.13, x, 2.22, -1.31, .white) }
        for y: Float in [1.30, 3.14] { box(1.83, 0.1, 0.17, 0.65, y, -1.30, .white) }
        box(2.04, 0.12, 0.42, 0.65, 1.26, -1.22, NSColor(white: 0.92, alpha: 1))
        // Two real hinged sashes, opening inward.
        for side in 0..<2 {
            let pivot = SCNNode(); pivot.name = "window"; pivot.position = SCNVector3(side == 0 ? -0.16 : 1.46, 2.22, -1.24); root.addChildNode(pivot)
            let cx: Float = side == 0 ? 0.405 : -0.405
            for y: Float in [-0.85, 0, 0.85] { box(0.81, 0.045, 0.045, cx, y, 0, .white, parent: pivot) }
            for x: Float in [0, cx * 2] { box(0.045, 1.74, 0.045, x, 0, 0, .white, parent: pivot) }
            let glass = box(0.77, 1.65, 0.012, cx, 0, 0, NSColor(white: 0.92, alpha: 0.12), parent: pivot)
            glass.geometry?.firstMaterial?.transparency = plant.windowOpen ? 0.04 : 0.15
            pivot.eulerAngles.y = plant.windowOpen ? (side == 0 ? -0.9 : 0.9) : 0
        }
        // Soft flattened shadow and faceted porcelain pot.
        let shadow = SCNCylinder(radius: 0.65, height: 0.005); shadow.radialSegmentCount = 24
        shadow.materials = [material(NSColor(white: 0.51, alpha: 0.24))]
        let shadowNode = SCNNode(geometry: shadow); shadowNode.position = SCNVector3(-0.65,0.015,0.25); shadowNode.scale = SCNVector3(1,1,0.6); root.addChildNode(shadowNode)
        let plantRoot = SCNNode(); plantRoot.name = "plant"; plantRoot.position = SCNVector3(-0.65,0,0.25); root.addChildNode(plantRoot)
        let pot = SCNCone(topRadius: 0.40, bottomRadius: 0.29, height: 0.62); pot.radialSegmentCount = 9
        pot.materials = [material(NSColor(white: 0.84, alpha: 1), .ceramic)]
        let potNode = SCNNode(geometry: pot); potNode.position.y = 0.32; plantRoot.addChildNode(potNode)
        let rim = SCNTorus(ringRadius: 0.38, pipeRadius: 0.045); rim.ringSegmentCount = 12; rim.pipeSegmentCount = 4; rim.materials = [material(.white)]
        let rimNode = SCNNode(geometry: rim); rimNode.position.y = 0.64; plantRoot.addChildNode(rimNode)
        let soil = SCNCylinder(radius: 0.35, height: 0.025); soil.radialSegmentCount = 12
        soil.materials = [material(NSColor(red: 0.22 - plant.moisture / 1500, green: 0.18 - plant.moisture / 1800, blue: 0.13, alpha: 1), .soil)]
        let soilNode = SCNNode(geometry: soil); soilNode.position.y = 0.625; plantRoot.addChildNode(soilNode)
        if plant.adopted {
            let scale: Float = 0.85
            let foliage = SCNNode(); foliage.name = "foliage"; foliage.position.y = 0.64; foliage.scale = SCNVector3(scale,scale,scale); plantRoot.addChildNode(foliage)
            func stem(_ start: SCNVector3, _ end: SCNVector3, radius: CGFloat, color: NSColor, parent: SCNNode) {
                let dx = end.x-start.x, dy = end.y-start.y, dz = end.z-start.z
                let length = CGFloat(sqrt(dx*dx+dy*dy+dz*dz))
                let g = SCNCylinder(radius: radius, height: length); g.radialSegmentCount = 6; g.materials = [material(color)]
                let n = SCNNode(geometry: g); n.position = SCNVector3((start.x+end.x)/2,(start.y+end.y)/2,(start.z+end.z)/2)
                n.look(at: end, up: SCNVector3(0,0,1), localFront: SCNVector3(0,1,0)); parent.addChildNode(n)
            }
            let tips: [(Float,Float,Float,Float,Float)] = [
                (-0.64,1.86,0.08,-0.78,0.84), (0.64,1.98,-0.04,0.64,0.93),
                (-0.76,1.20,0.30,-0.65,0.73), (0.72,1.13,0.38,0.55,0.72),
                (0.03,2.45,-0.16,-0.04,1.05), (-0.18,0.72,0.67,-0.35,0.60)
            ]
            for (i, tip) in tips.enumerated() {
                let state = plant.leaves[i]
                guard state.isPresent else { continue }
                let expansion = Float(0.15 + state.maturity * 0.85)
                let petiole = Float(0.28 + state.maturity * 0.72)
                let withered = state.phase == .withered
                let point = SCNVector3(tip.0*petiole,(tip.1-(withered ? 0.25 : 0))*petiole,tip.2*petiole)
                let stemColor = NSColor(red:0.30,green:0.40,blue:0.12,alpha:1)
                if withered {
                    let control = SCNVector3(point.x*0.8,point.y+0.45*CGFloat(petiole),point.z*0.6-0.10)
                    var previous = SCNVector3Zero
                    for step in 1...7 {
                        let t = CGFloat(step)/7
                        let next = SCNVector3(2*(1-t)*t*control.x+t*t*point.x,2*(1-t)*t*control.y+t*t*point.y,2*(1-t)*t*control.z+t*t*point.z)
                        stem(previous,next,radius:0.022,color:stemColor,parent:foliage); previous = next
                    }
                } else { stem(SCNVector3Zero,point,radius:0.022,color:stemColor,parent:foliage) }
                let leaf = LeafSceneNode(); leaf.name = "leaf"; leaf.position = point
                leaf.eulerAngles = SCNVector3(-0.10 + Float(i % 3) * 0.07, i % 2 == 0 ? -0.16 : 0.18, tip.3)
                leaf.slot = i
                let size = tip.4 * expansion
                leaf.scale = SCNVector3(state.phase == .withered ? size * 0.38 : size, state.phase == .withered ? size * 0.88 : size, size)
                if withered { leaf.eulerAngles.x = -0.15; leaf.eulerAngles.z = CGFloat(tip.3)*0.12 }
                foliage.addChildNode(leaf)
                let path = MonsteraLeaf.outline(juvenile: i == 5 || state.maturity < 0.6)
                let shape = SCNShape(path: path, extrusionDepth: 0.012); shape.chamferRadius = 0
                let yellow = CGFloat(state.yellowFraction)
                let green = NSColor(red: 0.12 + yellow * 0.46 + CGFloat(i % 2) * 0.025, green: 0.30 + yellow * 0.20 + CGFloat(i % 3) * 0.02, blue: 0.065, alpha: 1)
                let color = state.phase == .withered ? NSColor(red:0.30,green:0.20,blue:0.09,alpha:1) : green
                shape.materials = [material(color, .leaf)]
                leaf.addChildNode(SCNNode(geometry:withered ? WitheredLeaf.geometry(shape) : shape))
                let veinColor = state.phase == .withered ? NSColor(red:0.32,green:0.24,blue:0.12,alpha:1) : NSColor(red:0.34+yellow*0.15,green:0.44,blue:0.14,alpha:1)
                func vein(_ start:SCNVector3,_ end:SCNVector3,_ radius:CGFloat) {
                    if withered {
                        var previous = WitheredLeaf.bend(start)
                        for segment in 1...5 {
                            let t = CGFloat(segment)/5
                            let p = SCNVector3(start.x+(end.x-start.x)*t,start.y+(end.y-start.y)*t,start.z+(end.z-start.z)*t)
                            let next = WitheredLeaf.bend(p)
                            stem(previous,next,radius:radius,color:veinColor,parent:leaf); previous = next
                        }
                    } else { stem(start,end,radius:radius,color:veinColor,parent:leaf) }
                }
                vein(SCNVector3(0,0,0.025),SCNVector3(0,-1.04,0.025),0.005)
                let veins: [(Float,Float,Float)] = [(-0.12,0.45,0.02),(-0.36,0.43,-0.28),(-0.59,0.34,-0.56),(-0.84,0.20,-0.86)]
                for (start, width, end) in veins {
                    for sign: Float in [-1,1] {
                        vein(SCNVector3(0,start,0.025),SCNVector3(sign*width,end,0.025),0.0025)
                    }
                }

            }
            if plant.windowOpen {
                foliage.runAction(.repeatForever(.sequence([.rotateBy(x:0,y:0,z:0.025,duration:1.8),.rotateBy(x:0,y:0,z:-0.025,duration:1.8)])))
            }

        }
        root.addChildNode(Bookshelf.make(includePhotoAlbum:hasPhotoAlbum))
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = climate.daylight ? 650 : 240; ambient.light?.color = climate.daylight ? NSColor.white : NSColor(red:0.74,green:0.81,blue:1,alpha:1); root.addChildNode(ambient)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light?.type = .directional; sun.light?.intensity = climate.daylight ? (climate.rain ? 400 : 950) : 100
        sun.light?.color = climate.daylight ? NSColor(red:1,green:0.97,blue:0.87,alpha:1) : NSColor(red:0.65,green:0.75,blue:1,alpha:1)
        sun.light?.castsShadow = true; sun.light?.shadowMode = .deferred; sun.light?.shadowColor = NSColor(white:0.25,alpha:0.3); sun.eulerAngles = SCNVector3(-0.7,-0.6,0); root.addChildNode(sun)
        if !climate.daylight { Moonlight.add(to:scene,cloud:climate.cloud,windowOpen:plant.windowOpen) }
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true; camera.camera?.orthographicScale = 1.9
        camera.position = SCNVector3(0.65,2.55,7); camera.look(at:SCNVector3(0,1.75,0)); root.addChildNode(camera)
        return scene
    }
}
