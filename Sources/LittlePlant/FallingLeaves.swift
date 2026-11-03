import SceneKit

/// Detached blades use real time, independent of the accelerated plant clock.
final class FallingLeaves {
    static let category = 2
    private struct Entry {
        let node: SCNNode
        let origin: SCNVector3
        let rotation: SCNVector3
        let direction: CGFloat
        var age = 0.0
    }
    private var scene: SCNScene?
    private var entries: [Entry] = []
    var count: Int { entries.count }
    var firstNode: SCNNode? { entries.first?.node }
    let duration = 1.05

    static func snapshot(_ source: SCNNode) -> SCNNode {
        let blade = source.clone()
        blade.name = "fallingLeaf"
        blade.simdTransform = source.presentation.simdWorldTransform
        blade.isHidden = false
        func detach(_ node: SCNNode) {
            node.removeAllActions()
            node.categoryBitMask = category
            node.castsShadow = false
            node.childNodes.forEach(detach)
        }
        detach(blade)
        return blade
    }
    func attach(to scene: SCNScene) {
        self.scene = scene
        // Detached blades remain lit and visible, but are excluded from tool hit tests.
        scene.rootNode.enumerateChildNodes { node, _ in
            if let light = node.light { light.categoryBitMask |= Self.category }
            if let camera = node.camera { camera.categoryBitMask |= Self.category }
        }
        for entry in entries {
            entry.node.removeFromParentNode()
            scene.rootNode.addChildNode(entry.node)
        }
    }
    func add(_ blade: SCNNode) {
        entries.append(Entry(node:blade,origin:blade.position,rotation:blade.eulerAngles,direction:entries.count % 2 == 0 ? -1 : 1))
        scene?.rootNode.addChildNode(blade)
    }
    func update(_ delta: Double) {
        guard delta > 0 else { return }
        var alive: [Entry] = []
        for var entry in entries {
            entry.age += delta
            guard entry.age < duration else { entry.node.removeFromParentNode(); continue }
            let p = entry.age / duration
            let fall = CGFloat(pow(p,1.25))
            entry.node.position = SCNVector3(entry.origin.x + entry.direction * CGFloat(sin(p * .pi)) * 0.045,
                                            entry.origin.y - fall * 0.32,
                                            entry.origin.z)
            entry.node.eulerAngles = SCNVector3(entry.rotation.x + CGFloat(sin(p * .pi)) * 0.10,
                                               entry.rotation.y,
                                               entry.rotation.z + entry.direction * CGFloat(sin(p * .pi * 0.8)) * 0.12)
            let fade = min(1,max(0,(p-0.10)/0.90))
            entry.node.opacity = CGFloat(1 - fade*fade*(3-2*fade))
            alive.append(entry)
        }
        entries = alive
    }
    func clear() { entries.forEach { $0.node.removeFromParentNode() }; entries.removeAll() }
}
