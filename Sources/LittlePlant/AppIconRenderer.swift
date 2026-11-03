import AppKit
import SceneKit
import Metal
import PlantCore

/// Reuses the real plant mesh inside a raised, handheld-console-style tile.
@MainActor
enum AppIconRenderer {
    static func export(to directory:URL) throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var healthy = Plant(matureLeafCount:6); healthy.adopted = true
        let room = RoomScene(plant:healthy,climate:Climate()).makeRoom()
        let scene = SCNScene(); scene.background.contents = NSColor.clear
        let plant = room.rootNode.childNode(withName:"plant",recursively:false)!.clone()
        plant.position = SCNVector3Zero; scene.rootNode.addChildNode(plant)
        for light in room.rootNode.childNodes where light.light != nil { scene.rootNode.addChildNode(light.clone()) }
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.65
        camera.position = SCNVector3(0.3,1.9,7); camera.look(at:SCNVector3(0,1.45,0))
        scene.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil); renderer.scene = scene; renderer.pointOfView = camera
        let portrait = renderer.snapshot(atTime:0,with:NSSize(width:256,height:256),antialiasingMode:.none)
        for size in [16,32,128,256,512] {
            for scale in [1,2] {
                let pixels = size*scale
                let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:pixels*4,bitsPerPixel:32)!
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
                NSGraphicsContext.current?.cgContext.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
                func tile(_ rect:NSRect,_ radius:CGFloat,_ top:CGFloat,_ bottom:CGFloat) {
                    let path = NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius)
                    NSGradient(starting:NSColor(white:bottom,alpha:1),ending:NSColor(white:top,alpha:1))!.draw(in:path,angle:90)
                }
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.28); shadow.shadowBlurRadius = 22; shadow.shadowOffset = NSSize(width:0,height:-14); shadow.set()
                tile(NSRect(x:66,y:66,width:892,height:892),184,0.85,0.5)
                NSGraphicsContext.restoreGraphicsState()
                tile(NSRect(x:76,y:82,width:872,height:872),175,0.99,0.64)
                tile(NSRect(x:94,y:100,width:836,height:836),159,0.67,0.87)
                tile(NSRect(x:106,y:112,width:812,height:812),150,1.0,0.83)
                let outline = NSBezierPath(roundedRect:NSRect(x:111,y:117,width:802,height:802),xRadius:145,yRadius:145)
                NSColor.white.withAlphaComponent(0.9).setStroke(); outline.lineWidth = 5; outline.stroke()
                NSGraphicsContext.current?.imageInterpolation = pixels >= 256 ? .none : .high
                portrait.draw(in:NSRect(x:142,y:136,width:740,height:740),from:.zero,operation:.sourceOver,fraction:1)
                NSGraphicsContext.restoreGraphicsState()
                let suffix = scale == 2 ? "@2x" : ""
                let url = directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
                try bitmap.representation(using:.png,properties:[:])!.write(to:url)
            }
        }
        fputs("Exported application icon using the project Monstera mesh\n",stderr)
    }
}
