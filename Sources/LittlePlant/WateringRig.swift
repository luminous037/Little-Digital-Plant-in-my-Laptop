import SceneKit
import AppKit

/// Low-poly galvanized metal tool and ballistic water droplets, in the room's own renderer.
final class WateringRig {
    let can = SCNNode()
    private let nozzle = SCNNode()
    private var scene: SCNScene?
    private(set) var enabled = false
    private(set) var grabbed = false
    private(set) var pouring = false
    private var offset = SCNVector3Zero
    private struct Drop { var node: SCNNode; var velocity: SCNVector3; var age: Double }
    private struct Splash { var node: SCNNode; var age: Double }
    private var drops: [Drop] = []
    private var splashes: [Splash] = []
    private var serial = 0
    private var spawnBudget = 0.0
    var onSoilWater: (Double) -> Void = { _ in }
    var onEnd: () -> Void = {}
    private let soil = SCNVector3(-0.65, 0.65, 0.25)

    init() {
        can.name = "wateringCan"
        func metal(_ gray: CGFloat) -> SCNMaterial {
            let m = SCNMaterial(); m.lightingModel = .blinn
            m.diffuse.contents = RetroTexture.image(NSColor(white: gray, alpha: 1), surface: .ceramic)
            m.diffuse.magnificationFilter = .nearest; m.diffuse.minificationFilter = .nearest
            m.specular.contents = NSColor(white:0.85,alpha:1); m.shininess = 0.65
            return m
        }
        let steel = metal(0.55), bright = metal(0.77)
        func add(_ geometry: SCNGeometry, _ position: SCNVector3, _ material: SCNMaterial) -> SCNNode {
            geometry.materials = [material]; let n = SCNNode(geometry:geometry); n.position = position; can.addChildNode(n); return n
        }
        let body = SCNCylinder(radius:0.23,height:0.39); body.radialSegmentCount = 10
        _ = add(body,SCNVector3Zero,steel)
        let opening = SCNCylinder(radius:0.196,height:0.008); opening.radialSegmentCount = 10
        let dark = SCNMaterial(); dark.diffuse.contents = NSColor(white:0.16,alpha:1)
        _ = add(opening,SCNVector3(0,0.202,0),dark)
        for y: CGFloat in [-0.19, 0.19] {
            let band = SCNTorus(ringRadius:0.226,pipeRadius:0.018); band.ringSegmentCount = 10; band.pipeSegmentCount = 4
            _ = add(band,SCNVector3(0,y,0),bright)
        }
        let handle = SCNTorus(ringRadius:0.23,pipeRadius:0.029); handle.ringSegmentCount = 12; handle.pipeSegmentCount = 5
        let h = add(handle,SCNVector3(0.28,0.025,0),bright); h.eulerAngles.x = .pi / 2; h.scale.x = 0.84
        let a = SCNVector3(-0.19,-0.06,0), b = SCNVector3(-0.65,0.19,0)
        let dx = b.x-a.x, dy = b.y-a.y
        let spout = SCNCone(topRadius:0.035,bottomRadius:0.075,height:sqrt(dx*dx+dy*dy)); spout.radialSegmentCount = 8
        let sn = add(spout,SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,0),steel)
        sn.look(at:b,up:SCNVector3(0,0,1),localFront:SCNVector3(0,1,0))
        let rose = SCNCylinder(radius:0.09,height:0.045); rose.radialSegmentCount = 8
        let rn = add(rose,b,bright); rn.look(at:SCNVector3(-0.8,0.24,0),up:SCNVector3(0,0,1),localFront:SCNVector3(0,1,0))
        for i in 0..<7 {
            let hole = SCNSphere(radius:0.009); hole.segmentCount = 4; hole.materials = [dark]
            let n = SCNNode(geometry:hole)
            n.position = SCNVector3(sin(Double(i)*2.4)*0.055,0.026,cos(Double(i)*2.4)*0.055)
            rn.addChildNode(n)
        }
        nozzle.position = SCNVector3(-0.69,0.20,0); can.addChildNode(nozzle)
        can.position = SCNVector3(1.20,0.95,0.95)
    }
    func attach(to scene: SCNScene) {
        self.scene = scene
        if enabled {
            can.removeFromParentNode(); scene.rootNode.addChildNode(can)
            for drop in drops { drop.node.removeFromParentNode(); scene.rootNode.addChildNode(drop.node) }
            for splash in splashes { splash.node.removeFromParentNode(); scene.rootNode.addChildNode(splash.node) }
        }
    }
    func setEnabled(_ value: Bool) {
        guard enabled != value else { return }
        enabled = value
        if value {
            can.position = SCNVector3(1.20,0.95,0.95)
            scene?.rootNode.addChildNode(can)
        } else {
            finish(); can.removeFromParentNode(); clearDrops()
        }
    }
    func grab(at world: SCNVector3) {
        guard enabled else { return }
        grabbed = true; pouring = false
        offset = SCNVector3(can.position.x-world.x,can.position.y-world.y,can.position.z-world.z)
    }
    func drag(to world: SCNVector3, inside: Bool) {
        guard grabbed else { return }
        can.position = SCNVector3(min(1.8,max(-1.6,world.x+offset.x)),min(2.8,max(0.78,world.y+offset.y)),world.z+offset.z)
        pouring = inside
        can.eulerAngles.z = inside ? 0.25 : 0
    }
    func finish() {
        let wasGrabbed = grabbed
        grabbed = false; pouring = false; can.eulerAngles.z = 0
        if wasGrabbed { onEnd() }
    }
    func suspend() { finish(); clearDrops() }
    private func clearDrops() {
        drops.forEach { $0.node.removeFromParentNode() }; drops.removeAll()
        splashes.forEach { $0.node.removeFromParentNode() }; splashes.removeAll()
    }
    func update(_ dt: Double) {
        guard enabled, let scene, dt > 0 else { return }
        let dt = CGFloat(min(0.12,dt))
        if pouring {
            spawnBudget += Double(dt) * 72
            let count = min(12, Int(spawnBudget)); spawnBudget -= Double(count)
            for _ in 0..<count {
                serial += 1
                let sphere = SCNSphere(radius:0.022); sphere.segmentCount = 5
                let m = SCNMaterial(); m.diffuse.contents = NSColor(red:0.12,green:0.48,blue:0.88,alpha:1)
                m.emission.contents = NSColor(red:0.04,green:0.10,blue:0.18,alpha:1); sphere.materials = [m]
                let n = SCNNode(geometry:sphere); n.position = nozzle.convertPosition(SCNVector3Zero,to:nil); n.scale.y = 1.8
                scene.rootNode.addChildNode(n)
                let spread = CGFloat((serial * 17) % 11 - 5) / 100
                drops.append(Drop(node:n,velocity:SCNVector3(-0.23+spread,-0.95,-1.10+spread),age:0))
            }
        }
        var survivors: [Drop] = []; var delivered = 0.0
        for var drop in drops {
            let before = drop.node.position
            drop.velocity.y -= 2.5 * dt
            drop.node.position = SCNVector3(before.x+drop.velocity.x*dt,before.y+drop.velocity.y*dt,before.z+drop.velocity.z*dt)
            drop.age += Double(dt)
            let after = drop.node.position
            if before.y > soil.y && after.y <= soil.y {
                // Interpolate the crossing so fast drops cannot skip the small soil disk.
                let f = (before.y-soil.y) / max(0.0001,before.y-after.y)
                let x = before.x+(after.x-before.x)*f, z = before.z+(after.z-before.z)*f
                if hypot(x-soil.x,z-soil.z) < 0.33 {
                    delivered += 0.16
                    if splashes.count < 8 { splash(at:SCNVector3(x,soil.y+0.008,z)) }
                }
                if hypot(x-soil.x,z-soil.z) < 0.33 { drop.node.removeFromParentNode() }
                else { survivors.append(drop) }
            } else if drop.age > 1.5 || after.y < 0.03 {
                drop.node.removeFromParentNode()
            } else { survivors.append(drop) }
        }
        drops = survivors
        var rings: [Splash] = []
        for var ring in splashes {
            ring.age += Double(dt)
            if ring.age > 0.32 { ring.node.removeFromParentNode() }
            else {
                let s = CGFloat(1+ring.age*5); ring.node.scale = SCNVector3(s,1,s); ring.node.opacity = CGFloat(1-ring.age/0.32)
                rings.append(ring)
            }
        }
        splashes = rings
        if delivered > 0 { onSoilWater(delivered) }
    }
    private func splash(at point: SCNVector3) {
        let g = SCNTorus(ringRadius:0.035,pipeRadius:0.008); g.ringSegmentCount = 8; g.pipeSegmentCount = 3
        let m = SCNMaterial(); m.diffuse.contents = NSColor(red:0.46,green:0.77,blue:0.94,alpha:1); g.materials = [m]
        let n = SCNNode(geometry:g); n.position = point; scene?.rootNode.addChildNode(n)
        splashes.append(Splash(node:n,age:0))
    }
    func stagePreviewPour() {
        // Only called by the explicit screenshot harness; never write the user's plant data.
        onSoilWater = { _ in }; onEnd = {}
        setEnabled(true); can.position = SCNVector3(0.20,1.50,0.95)
        grab(at:can.position); drag(to:can.position,inside:true)
        for _ in 0..<6 { update(1.0/12) }
    }
    func verify() {
        let saved = onSoilWater, savedEnd = onEnd; var received = 0.0
        let wasEnabled = enabled
        onEnd = {}
        onSoilWater = { received += $0 }
        setEnabled(true)
        // A click alone never pours.
        grab(at:can.position); update(0.1); precondition(received == 0 && !pouring)
        // Drags away from the pot still spray, but do not water the plant.
        drag(to:SCNVector3(1.5,1.5,0.95),inside:true)
        for _ in 0..<20 { update(1.0/12) }
        precondition(received == 0,"Missing the pot must not increase moisture")
        suspend()
        // Position the nozzle over the soil's ballistic landing area.
        can.position = SCNVector3(0.20,1.50,0.95)
        grab(at:can.position); drag(to:can.position,inside:true)
        for _ in 0..<24 { update(1.0/12) }
        precondition(received > 0,"Water landing on soil must be delivered")
        finish(); precondition(!pouring && !grabbed,"Release must stop the spray")
        setEnabled(false); onSoilWater = saved; onEnd = savedEnd
        if wasEnabled { setEnabled(true) }
        fputs("PASS: watering can grab/drag, soil-only delivery, miss, release\n",stderr)
    }
}
