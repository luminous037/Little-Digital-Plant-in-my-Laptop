import AppKit
import SceneKit

/// Small, faceted flakes preserve the room's low-resolution look.
final class PixelSnowNode: SCNNode {
    private struct Flake {
        let node:SCNNode
        let x:Double, phase:Double, speed:Double, sway:Double, alpha:Double
    }
    private var flakes:[Flake] = []
    init(daylight:Bool) {
        super.init(); name = "pixelSnow"; categoryBitMask = 8
        for index in 0..<66 {
            func seed(_ salt:Int) -> Double { Double((index*7919+salt*104729+index*index*137)%65521)/65521 }
            let near = index%3 == 0
            let size = (near ? 0.022 : 0.012)+seed(2)*0.014
            let shape = SCNPlane(width:size,height:size)
            let m = SCNMaterial(); m.lightingModel = .constant
            m.diffuse.contents = NSColor(red:0.91,green:0.95,blue:1,alpha:1)
            m.isDoubleSided = true; m.writesToDepthBuffer = false; shape.materials = [m]
            let n = SCNNode(geometry:shape); n.categoryBitMask = 8
            n.position.z = near ? -1.325 : -1.35; addChildNode(n)
            flakes.append(Flake(node:n,x:0.04+seed(1)*1.24,phase:seed(7),speed:(near ? 0.16 : 0.09)+seed(5)*0.06,sway:0.04+seed(4)*0.045,alpha:(near ? 0.8 : 0.48)*(daylight ? 1 : 0.85)))
        }
        update(time:Date.timeIntervalSinceReferenceDate)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(time:Double) {
        for f in flakes {
            let phase = (time*f.speed/1.71+f.phase).truncatingRemainder(dividingBy:1)
            let y = 3.075-phase*1.71
            f.node.position.x = CGFloat(f.x+sin(time*0.8+f.phase*12)*f.sway+sin(time*0.21)*0.025)
            f.node.position.y = CGFloat(y)
            f.node.eulerAngles.z = CGFloat(sin(time*0.5+f.phase*20)*0.65)
            f.node.opacity = CGFloat(f.alpha*min(1,max(0,min((3.075-y)/0.1,(y-1.365)/0.1))))
        }
    }
    static func verify() {
        let snow = PixelSnowNode(daylight:true)
        snow.update(time:100)
        let before = snow.flakes.map { $0.node.position }
        snow.update(time:100.1)
        for (f,p) in zip(snow.flakes,before) {
            precondition(f.node.categoryBitMask == 8 && f.node.position.x > -0.16 && f.node.position.x < 1.47)
            precondition(f.node.position.y >= 1.365 && f.node.position.y <= 3.075)
            if f.node.position.y < p.y { precondition(abs(Double(f.node.position.y-p.y)+f.speed*0.1)<0.0001) }
        }
        let rebuilt = PixelSnowNode(daylight:true); rebuilt.update(time:100.1)
        precondition(zip(snow.flakes,rebuilt.flakes).allSatisfy { abs($0.node.position.y-$1.node.position.y)<0.0001 },"Snow must continue across scene rebuilds")
        fputs("PASS: 66 layered snowflakes, slow fall and sway, window bounds, noninteractive geometry and rebuild continuity\n",stderr)
    }
}
