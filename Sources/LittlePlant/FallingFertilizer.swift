import SceneKit
import AppKit

/// Four faceted pellets fall in real time and survive room rebuilds during feeding.
final class FallingFertilizer {
    static let category = 8
    static let landingOffsets = [SCNVector3(-0.17,0,0.09),SCNVector3(0.14,0,0.11),SCNVector3(-0.08,0,-0.14),SCNVector3(0.15,0,-0.09)]
    private struct Batch {
        let nodes: [SCNNode]
        let targets: [SCNVector3]
        var age = 0.0
    }
    private var scene: SCNScene?
    private var batches: [Batch] = []
    var count: Int { batches.reduce(0) { $0+$1.nodes.count } }
    var firstNode: SCNNode? { batches.first?.nodes.first }
    func attach(to scene:SCNScene) {
        self.scene = scene
        scene.rootNode.enumerateChildNodes { node,_ in
            node.light?.categoryBitMask |= Self.category
            node.camera?.categoryBitMask |= Self.category
        }
        for batch in batches { for node in batch.nodes { node.removeFromParentNode(); scene.rootNode.addChildNode(node) } }
    }
    func emit() {
        guard let scene, let plant = scene.rootNode.childNode(withName:"plant",recursively:false) else { return }
        let material = SCNMaterial(); material.lightingModel = .lambert
        material.diffuse.contents = RetroTexture.image(NSColor(red:0.97,green:0.67,blue:0.40,alpha:1),surface:.ceramic)
        material.diffuse.magnificationFilter = .nearest; material.diffuse.minificationFilter = .nearest
        let targets = Self.landingOffsets.map { plant.convertPosition(SCNVector3($0.x,0.65,$0.z),to:nil) }
        let nodes = targets.enumerated().map { index,target -> SCNNode in
            let mesh = SCNSphere(radius:0.032); mesh.segmentCount = 6; mesh.materials = [material]
            let node = SCNNode(geometry:mesh); node.name = "fallingFertilizer"; node.categoryBitMask = Self.category
            node.position = SCNVector3(target.x,target.y+1.0,target.z)
            node.eulerAngles = SCNVector3(0.2*CGFloat(index),0.35*CGFloat(index),0)
            node.isHidden = index > 0; scene.rootNode.addChildNode(node)
            return node
        }
        batches.append(Batch(nodes:nodes,targets:targets))
    }
    func update(_ delta:Double) {
        var alive: [Batch] = []
        for var batch in batches {
            batch.age += max(0,delta)
            guard batch.age < 2.15 else { batch.nodes.forEach { $0.removeFromParentNode() }; continue }
            for (index,node) in batch.nodes.enumerated() {
                let age = batch.age-Double(index)*0.12
                node.isHidden = age < 0
                let p = min(1,max(0,age/1.45))
                let target = batch.targets[index]
                let fall = CGFloat(pow(p,1.35))
                let sink = min(1,max(0,(age-1.45)/0.25))
                node.position = SCNVector3(target.x+CGFloat(sin(p * .pi))*0.025,target.y+1-fall-CGFloat(sink)*0.10,target.z)
                node.opacity = CGFloat(1-sink)
                node.eulerAngles.z = CGFloat(min(1,p))*0.9
            }
            alive.append(batch)
        }
        batches = alive
    }
    func clear() {
        batches.forEach { $0.nodes.forEach { $0.removeFromParentNode() } }
        batches.removeAll()
    }
    func verify() { FallingFertilizer().verifyIsolated() }
    private func verifyIsolated() {
        let originalScene = scene
        let fixture = SCNScene(), plant = SCNNode()
        plant.name = "plant"; plant.position = SCNVector3(-0.65,0,0.25)
        fixture.rootNode.addChildNode(plant)
        attach(to:fixture); emit()
        precondition(count == 4,"Each feed must create exactly four pellets")
        let node = firstNode!, start = node.position.y
        update(0.6)
        precondition(node.position.y < start && node.position.y > 0.69 && node.categoryBitMask == Self.category,"Pellets must fall slowly and remain noninteractive")
        let y = node.position.y
        let next = SCNScene(); attach(to:next)
        precondition(node.parent === next.rootNode && node.position.y == y,"Scene refresh must preserve falling pellets")
        update(1.2)
        precondition(node.position.y < 0.6375 && node.opacity == 0,"Pellets must sink below soil and disappear")
        update(1)
        precondition(count == 0 && node.parent == nil,"Completed animation must clean up")
        if let originalScene { attach(to:originalScene) }
        fputs("PASS: four fertilizer pellets, slow 3D fall, noninteractive geometry, rebuild continuity, sinking/disappearance and cleanup\n",stderr)
    }
}
