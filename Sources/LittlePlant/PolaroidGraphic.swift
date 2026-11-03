import AppKit
import SceneKit
import Metal

@MainActor
enum PolaroidGraphic {
    private static let cache = NSCache<NSString,NSImage>()
    static func png(_ image:NSImage) -> Data? {
        image.tiffRepresentation.flatMap { NSBitmapImageRep(data:$0)?.representation(using:.png,properties:[:]) }
    }
    static func artwork(scene:NSImage,record:PlantPhoto) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:480,pixelsHigh:528,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1920,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
        NSGraphicsContext.current?.cgContext.scaleBy(x:2,y:2)
        NSGraphicsContext.current?.imageInterpolation = .none
        NSColor(white:0.96,alpha:1).setFill(); NSRect(x:0,y:0,width:240,height:264).fill()
        NSColor(white:0.72,alpha:1).setStroke(); NSBezierPath(rect:NSRect(x:0.5,y:0.5,width:239,height:263)).stroke()
        // Preserve the complete 3D room framebuffer; no HUD or buttons enter this image.
        scene.draw(in:NSRect(x:12,y:76,width:216,height:176),from:.zero,operation:.sourceOver,fraction:1)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .right; paragraph.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key:Any] = [.font:NSFont(name:RetroFonts.clock,size:12) ?? NSFont.systemFont(ofSize:12),.foregroundColor:NSColor(white:0.12,alpha:1),.paragraphStyle:paragraph]
        (record.dateText as NSString).draw(in:NSRect(x:12,y:36,width:216,height:20),withAttributes:attrs)
        (record.plantName as NSString).draw(in:NSRect(x:12,y:15,width:216,height:20),withAttributes:attrs)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size:NSSize(width:240,height:264)); image.addRepresentation(bitmap); return image
    }
    static func card(scene:NSImage,record:PlantPhoto) -> NSImage {
        let key = record.id.uuidString as NSString
        if let image = cache.object(forKey:key) { return image }
        let texture = artwork(scene:scene,record:record)
        let model = SCNScene(); model.background.contents = NSColor.clear
        func material(_ value:Any) -> SCNMaterial {
            let m = SCNMaterial(); m.diffuse.contents = value; m.lightingModel = .constant
            m.diffuse.magnificationFilter = .nearest; m.diffuse.minificationFilter = .nearest
            return m
        }
        let face = material(texture), edge = material(NSColor(white:0.72,alpha:1))
        let mesh = SCNBox(width:2.4,height:2.64,length:0.035,chamferRadius:0.008)
        mesh.chamferSegmentCount = 1; mesh.materials = [face,edge,edge,edge,edge,edge]
        model.rootNode.addChildNode(SCNNode(geometry:mesh))
        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.44; camera.position = SCNVector3(0.35,0.15,10); camera.look(at:SCNVector3Zero)
        model.rootNode.addChildNode(camera)
        let renderer = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil); renderer.scene = model; renderer.pointOfView = camera
        let image = renderer.snapshot(atTime:0,with:NSSize(width:480,height:528),antialiasingMode:.none)
        cache.countLimit = 40; cache.setObject(image,forKey:key)
        return image
    }
}
