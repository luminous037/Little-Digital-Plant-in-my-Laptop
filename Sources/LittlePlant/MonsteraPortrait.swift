import AppKit
import SceneKit
import Metal
import PlantCore

/// The book reuses the exact project mesh and textures, with no external plant photograph.
enum MonsteraPortrait {
    static let image: NSImage = {
        var healthy = Plant(matureLeafCount:6); healthy.adopted = true
        return render(plant:healthy)
    }()
    static func render(plant:Plant,size:NSSize = NSSize(width:150,height:208),framing:Double = 1.62) -> NSImage {
        let room = RoomScene(plant:plant,climate:Climate()).makeRoom()
        guard let plant = room.rootNode.childNode(withName:"plant",recursively:false)?.clone() else {
            preconditionFailure("Missing project plant graphic")
        }
        let scene = SCNScene(); scene.background.contents = NSColor(red:0.94,green:0.92,blue:0.85,alpha:1)
        plant.position = SCNVector3Zero; scene.rootNode.addChildNode(plant)
        for source in room.rootNode.childNodes where source.light != nil { scene.rootNode.addChildNode(source.clone()) }
        let camera = SCNNode(); camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true; camera.camera?.orthographicScale = framing
        camera.position = SCNVector3(0.35,1.9,7); camera.look(at:SCNVector3(0,1.45,0))
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene = scene; renderer.pointOfView = camera
        return renderer.snapshot(atTime:0,with:size,antialiasingMode:.none)
    }
    static func exportGrowthExamples(to directory:URL) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        for (name,hours,count) in [("growth-starter",0.0,2),("growth-sprout",12.0,3),("growth-growing",80.0,4),("growth-full",193.0,6)] {
            var plant = Plant(); plant.adopted = true
            var remaining = hours
            while remaining > 0 {
                plant.moisture = 45; plant.air = 70; plant.rootStress = 0
                let step = min(0.25,remaining)
                plant.advance(hours:step,climate:Climate()); remaining -= step
            }
            let present = plant.leaves.filter(\.isPresent)
            precondition(present.count == count,"Examples must show actual sequential plant growth")
            let image = render(plant:plant,size:NSSize(width:240,height:300),framing:1.85)
            let rep = NSBitmapImageRep(data:image.tiffRepresentation!)!
            try rep.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent(name+".png"))
            fputs("Rendered \(name): \(count) leaves, maturities \(present.map { Int($0.maturity*100) })\n",stderr)
        }
    }
}
