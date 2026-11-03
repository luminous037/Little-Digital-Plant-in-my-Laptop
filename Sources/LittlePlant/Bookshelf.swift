import SceneKit
import AppKit

/// A walnut cabinet containing a single pull-out field guide.
enum Bookshelf {
    static func make(includePhotoAlbum:Bool = false) -> SCNNode {
        let shelf = SCNNode(); shelf.name = "bookshelf"; shelf.position = SCNVector3(1.35,0,-0.85)
        func material(_ color: NSColor) -> SCNMaterial {
            let m = SCNMaterial(); m.diffuse.contents = RetroTexture.image(color,surface:.wood)
            m.diffuse.magnificationFilter = .nearest; m.diffuse.minificationFilter = .nearest
            m.lightingModel = .lambert; return m
        }
        let walnut = material(NSColor(red:0.23,green:0.13,blue:0.075,alpha:1))
        let dark = material(NSColor(red:0.15,green:0.08,blue:0.045,alpha:1))
        let cover = material(NSColor(red:0.22,green:0.30,blue:0.20,alpha:1))
        let pages = material(NSColor(red:0.84,green:0.81,blue:0.70,alpha:1))
        let gold = material(NSColor(red:0.72,green:0.62,blue:0.36,alpha:1))
        func box(_ w: CGFloat,_ h: CGFloat,_ d: CGFloat,_ p: SCNVector3,_ m: SCNMaterial,_ parent: SCNNode) {
            let g = SCNBox(width:w,height:h,length:d,chamferRadius:0); g.materials = [m]
            let n = SCNNode(geometry:g); n.position = p; parent.addChildNode(n)
        }
        box(0.96,1.02,0.05,SCNVector3(0,0.54,-0.22),dark,shelf)
        for x: CGFloat in [-0.48,0.48] { box(0.065,1.08,0.55,SCNVector3(x,0.54,0),walnut,shelf) }
        for y: CGFloat in [0.08,0.72,1.07] { box(1.02,0.065,0.57,SCNVector3(0,y,0),walnut,shelf) }
        for x: CGFloat in [-0.37,0.37] { box(0.10,0.10,0.38,SCNVector3(x,0.03,0),dark,shelf) }
        let book = SCNNode(); book.name = "book"; book.position = SCNVector3(-0.12,0.41,0.015)
        shelf.addChildNode(book)
        box(0.205,0.52,0.37,SCNVector3(0,0,0),pages,book)
        for x: CGFloat in [-0.12,0.12] { box(0.025,0.56,0.43,SCNVector3(x,0,0),cover,book) }
        box(0.265,0.56,0.03,SCNVector3(0,0,0.22),cover,book)
        for y: CGFloat in [-0.19,0.19] { box(0.18,0.012,0.006,SCNVector3(0,y,0.238),gold,book) }
        let emblem = SCNShape(path:MonsteraLeaf.outline(juvenile:false),extrusionDepth:0.002); emblem.materials = [gold]
        let leaf = SCNNode(geometry:emblem); leaf.scale = SCNVector3(0.10,0.10,0.10); leaf.position = SCNVector3(0,0.055,0.24)
        book.addChildNode(leaf)
        if includePhotoAlbum {
            let album = SCNNode(); album.name = "photoAlbumBook"; album.position = SCNVector3(0.23,0.41,0.015)
            shelf.addChildNode(album)
            let white = material(NSColor(white:0.93,alpha:1)), grey = material(NSColor(white:0.52,alpha:1))
            box(0.205,0.52,0.37,SCNVector3Zero,pages,album)
            for x:CGFloat in [-0.12,0.12] { box(0.025,0.56,0.43,SCNVector3(x,0,0),white,album) }
            box(0.265,0.56,0.03,SCNVector3(0,0,0.22),white,album)
            for x:CGFloat in [-0.065,0.065] { box(0.014,0.15,0.006,SCNVector3(x,0,0.24),grey,album) }
            for y:CGFloat in [-0.075,0.075] { box(0.14,0.014,0.006,SCNVector3(0,y,0.24),grey,album) }
        }
        return shelf
    }
}
