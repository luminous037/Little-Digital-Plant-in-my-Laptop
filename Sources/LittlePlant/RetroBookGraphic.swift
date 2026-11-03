import SwiftUI
import SceneKit
import Metal

@MainActor
enum RetroBookGraphic {
    private static var covers: [String:NSImage] = [:]
    static func cover(english: Bool,isPhotoAlbum:Bool = false) -> NSImage {
        let key = "\(english)-\(isPhotoAlbum)"
        if let image = covers[key] { return image }
        let image = BookOpeningRenderer(english:english,left:nil,right:nil,isPhotoAlbum:isPhotoAlbum).image(progress:0)
        covers[key] = image
        return image
    }
}

/// The same front-facing mesh is used for the closed cover and every opening frame.
@MainActor
final class BookOpeningRenderer {
    // Artwork matches the 1.85 × 3.30 cover mesh; the framebuffer matches the view's 19:17 ratio.
    static let artworkSize = NSSize(width:185,height:330)
    static let framebufferSize = NSSize(width:760,height:680)
    private let renderer = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
    private let hinge = SCNNode()
    private let camera = SCNNode()
    init(english:Bool,left:NSImage?,right:NSImage?,isPhotoAlbum:Bool = false) {
        let artwork = ImageRenderer(content:BookCoverArtwork(english:english,isPhotoAlbum:isPhotoAlbum)); artwork.scale = 2
        guard let texture = artwork.nsImage else { preconditionFailure("Missing book cover artwork") }
        let scene = SCNScene(); scene.background.contents = NSColor.clear
        func material(_ contents:Any) -> SCNMaterial {
            let m = SCNMaterial(); m.diffuse.contents = contents
            m.diffuse.magnificationFilter = .nearest; m.diffuse.minificationFilter = .nearest
            m.lightingModel = .lambert
            return m
        }
        let leather = material(RetroTexture.image(isPhotoAlbum ? NSColor(white:0.92,alpha:1) : NSColor(red:0.19,green:0.27,blue:0.22,alpha:1),surface:.leather))
        let paper = material(RetroTexture.image(NSColor(red:0.88,green:0.86,blue:0.77,alpha:1),surface:.paper))
        func box(_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ x:CGFloat,_ z:CGFloat,_ materials:[SCNMaterial],parent:SCNNode) {
            let mesh = SCNBox(width:w,height:h,length:d,chamferRadius:0.008)
            mesh.chamferSegmentCount = 1; mesh.materials = materials
            let n = SCNNode(geometry:mesh); n.position = SCNVector3(x,0,z); parent.addChildNode(n)
        }
        box(1.85,3.3,0.15,0.925,-0.015,[right.map { material($0) } ?? paper,paper,paper,paper,paper,paper],parent:scene.rootNode)
        box(1.85,3.3,0.045,0.925,-0.115,[leather],parent:scene.rootNode)
        hinge.position.z = 0.105; scene.rootNode.addChildNode(hinge)
        // Front cover hinges toward the reader. The inside carries the left page.
        box(1.85,3.3,0.045,0.925,0,[material(texture),leather,left.map { material($0) } ?? paper,leather,leather,leather],parent:hinge)
        box(0.045,3.3,0.23,0,-0.015,[leather],parent:scene.rootNode)
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .omni
        key.light?.intensity = 350; key.position = SCNVector3(-3,5,7); scene.rootNode.addChildNode(key)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 600; scene.rootNode.addChildNode(ambient)
        camera.camera = SCNCamera(); camera.camera?.usesOrthographicProjection = true
        camera.camera?.orthographicScale = 1.7
        scene.rootNode.addChildNode(camera)
        renderer.scene = scene; renderer.pointOfView = camera
    }
    func image(progress:Double) -> NSImage {
        let p = min(1,max(0,progress))
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        hinge.eulerAngles.y = -.pi * p
        camera.position = SCNVector3(0.925*(1-p),0,10)
        // Parallel to the book: no side-view yaw or pitch at any point.
        camera.eulerAngles = SCNVector3Zero
        SCNTransaction.commit()
        return renderer.snapshot(atTime:p,with:Self.framebufferSize,antialiasingMode:.none)
    }
}

struct BookOpeningGraphic: View, Animatable {
    var renderer: BookOpeningRenderer
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    var body: some View {
        Image(nsImage:renderer.image(progress:progress)).interpolation(.none).resizable()
            .frame(width:380,height:340)
            .shadow(color:.black.opacity(0.22),radius:8,x:2,y:7)
    }
}
