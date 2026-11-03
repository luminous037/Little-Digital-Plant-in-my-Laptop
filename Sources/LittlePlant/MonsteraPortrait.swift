import AppKit
import SceneKit
import Metal
import PlantCore

/// The book reuses the exact project mesh and textures, with no external plant photograph.
enum MonsteraPortrait {
    static let image: NSImage = {
        var healthy = Plant(matureLeafCount:6); healthy.adopted = true
        let room = RoomScene(plant:healthy,climate:Climate()).makeRoom()
        guard let plant = room.rootNode.childNode(withName:"plant",recursively:false)?.clone() else {
            preconditionFailure("Missing project plant graphic")
        }
        let scene = SCNScene(); scene.background.contents = NSColor(red:0.94,green:0.92,blue:0.85,alpha:1)
        plant.position = SCNVector3Zero; scene.rootNode.addChildNode(plant)
        for source in room.rootNode.childNodes where source.light != nil { scene.rootNode.addChildNode(source.clone()) }
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true; camera.camera?.orthographicScale = 1.62
        camera.position = SCNVector3(0.35,1.9,7); camera.look(at:SCNVector3(0,1.45,0))
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene = scene; renderer.pointOfView = camera
        return renderer.snapshot(atTime:0,with:NSSize(width:150,height:208),antialiasingMode:.none)
    }()
}
