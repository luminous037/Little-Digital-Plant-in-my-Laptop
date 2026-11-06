import AppKit
import SceneKit
import PlantCore

final class LightningNode: SCNNode {
    private let epoch:Double
    private let bolt = SCNNode()
    private let glow = SCNNode()
    private let flashLight = SCNLight()
    init(epoch:Date,daylight:Bool) {
        self.epoch = epoch.timeIntervalSinceReferenceDate
        super.init(); name = "lightning"; categoryBitMask = 8
        func material(_ color:NSColor) -> SCNMaterial {
            let m = SCNMaterial(); m.diffuse.contents = color; m.emission.contents = color
            m.lightingModel = .constant; m.isDoubleSided = true; m.writesToDepthBuffer = false
            return m
        }
        // A polygonal lightning fork sits outside the glass, behind the window frame.
        func segment(_ a:SCNVector3,_ b:SCNVector3,_ radius:CGFloat) {
            let delta = SCNVector3(b.x-a.x,b.y-a.y,b.z-a.z)
            let length = sqrt(delta.x*delta.x+delta.y*delta.y+delta.z*delta.z)
            let g = SCNCylinder(radius:radius,height:length); g.radialSegmentCount = 4
            g.materials = [material(NSColor(red:0.86,green:0.94,blue:1,alpha:1))]
            let n = SCNNode(geometry:g); n.categoryBitMask = 8
            n.position = SCNVector3((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2)
            n.eulerAngles.z = -atan2(delta.x,delta.y); bolt.addChildNode(n)
        }
        let points = [SCNVector3(1.06,3.06,-1.33),SCNVector3(0.89,2.79,-1.33),SCNVector3(1.01,2.71,-1.33),SCNVector3(0.73,2.28,-1.33)]
        for pair in zip(points,points.dropFirst()) { segment(pair.0,pair.1,0.012) }
        segment(points[1],SCNVector3(1.24,2.58,-1.33),0.007)
        bolt.categoryBitMask = 8; addChildNode(bolt)
        let plane = SCNPlane(width:1.6,height:1.7)
        plane.materials = [material(NSColor(red:0.8,green:0.9,blue:1,alpha:1))]
        glow.geometry = plane; glow.categoryBitMask = 8; glow.position = SCNVector3(0.65,2.22,-1.36); addChildNode(glow)
        flashLight.type = .omni; flashLight.color = NSColor(red:0.82,green:0.91,blue:1,alpha:1)
        flashLight.attenuationStartDistance = 0; flashLight.attenuationEndDistance = 7
        let light = SCNNode(); light.light = flashLight; light.position = SCNVector3(0.6,2.6,-0.8); addChildNode(light)
        update(elapsed:0)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(time:Double) { update(elapsed:time-epoch) }
    func update(elapsed:Double) {
        let flash = StormTimeline.sample(elapsed:elapsed).flash
        bolt.opacity = CGFloat(min(1,flash*2))
        glow.opacity = CGFloat(flash*0.28)
        flashLight.intensity = CGFloat(flash*2400)
    }
    static func verify() {
        let n = LightningNode(epoch:Date(),daylight:false)
        n.update(elapsed:0); precondition(n.bolt.opacity == 0 && n.flashLight.intensity == 0)
        n.update(elapsed:2.26); precondition(n.bolt.opacity > 0 && n.flashLight.intensity > 1000)
        n.update(elapsed:3); precondition(n.bolt.opacity == 0 && n.glow.opacity == 0 && n.flashLight.intensity == 0)
        precondition(n.bolt.childNodes.allSatisfy { $0.categoryBitMask == 8 })
        fputs("PASS: polygonal lightning, window glow, room flash light and fade to normal\n",stderr)
    }
}
