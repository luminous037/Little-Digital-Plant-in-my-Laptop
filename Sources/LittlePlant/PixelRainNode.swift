import AppKit
import SceneKit

/// Layered, independently phased rain behind the window, sampled at the room's pixel cadence.
final class PixelRainNode: SCNNode {
    private struct Drop {
        let node: SCNNode
        let x: Double
        let phase: Double
        let speed: Double
        let length: Double
        let alpha: Double
    }
    private var drops: [Drop] = []
    init(daylight: Bool) {
        super.init()
        name = "pixelRain"; categoryBitMask = 8
        for index in 0..<46 {
            // Stable seeds avoid synchronized starts and keep motion continuous after scene rebuilds.
            func seed(_ salt: Int) -> Double { Double((index * 7919 + salt * 104729 + index * index * 137) % 65521) / 65521 }
            let near = index % 3 == 0
            let length = (near ? 0.085 : 0.035) + seed(3) * 0.065
            let shape = SCNPlane(width:near ? 0.009 : 0.006,height:length)
            let material = SCNMaterial(); material.lightingModel = .constant
            material.diffuse.contents = NSColor(red:daylight ? 0.83 : 0.57,green:daylight ? 0.9 : 0.69,blue:daylight ? 0.96 : 0.83,alpha:1)
            material.isDoubleSided = true; material.writesToDepthBuffer = false
            shape.materials = [material]
            let node = SCNNode(geometry:shape); node.categoryBitMask = 8
            node.eulerAngles.z = -0.13
            node.position.z = near ? -1.325 : -1.345
            addChildNode(node)
            drops.append(Drop(node:node,x:seed(1),phase:seed(7),speed:(near ? 0.84 : 0.48)+seed(5)*0.38,length:length,alpha:(near ? 0.55 : 0.25)+seed(9)*0.17))
        }
        update(time:Date.timeIntervalSinceReferenceDate)
    }
    static func verify() {
        let rain = PixelRainNode(daylight:true)
        let time = 1234.0
        rain.update(time:time)
        let before = rain.drops.map { $0.node.position }
        rain.update(time:time+1.0/12)
        precondition(Set(rain.drops.map { Int($0.speed*100) }).count > 10,"Rain must have varied fall speeds")
        for (index,drop) in rain.drops.enumerated() {
            let p = drop.node.position
            precondition(p.x > -0.18 && p.x < 1.49 && p.y >= 1.365 && p.y <= 3.075,"Rain must stay outside the window opening")
            if p.y < before[index].y { precondition(abs(Double(p.y-before[index].y)+drop.speed/12) < 0.0001,"Rain must fall steadily between frames") }
            precondition(drop.node.categoryBitMask == 8 && drop.node.opacity >= 0 && drop.node.opacity <= 1)
        }
        let rebuilt = PixelRainNode(daylight:false); rebuilt.update(time:time+1.0/12)
        for (a,b) in zip(rain.drops,rebuilt.drops) {
            precondition(abs(a.node.position.y-b.node.position.y) < 0.0001 && abs(a.node.position.x-b.node.position.x) < 0.0001,"Rebuilds must not restart rainfall")
        }
        fputs("PASS: layered rain speeds, continuous fall, window bounds, noninteractive drops and scene-rebuild continuity\n",stderr)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(time:Double) {
        // Recycle above/below the opening with a short fade, never jump upward in view.
        let top = 3.075, bottom = 1.365, travel = top-bottom
        let gust = sin(time*0.62)*0.016 + sin(time*0.23)*0.01
        for drop in drops {
            let phase = (time*drop.speed/travel+drop.phase).truncatingRemainder(dividingBy:1)
            let y = top-phase*travel
            let x = -0.05 + drop.x*1.48 - phase*0.10 + gust
            drop.node.position.x = CGFloat(x); drop.node.position.y = CGFloat(y)
            drop.node.eulerAngles.z = CGFloat(-0.13-gust)
            let edge = min(1,max(0,min((top-y)/0.12,(y-bottom)/0.12)))
            drop.node.opacity = CGFloat(drop.alpha*edge)
        }
    }
}
