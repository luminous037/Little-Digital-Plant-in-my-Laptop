import SceneKit
import AppKit

final class AlbumSceneNode: SCNNode { var trackID = "" }

@MainActor
final class MusicRig {
    let root = SCNNode()
    let disc = SCNNode(), cord = SCNNode()
    private var albums: [String:AlbumSceneNode] = [:]
    var album: SCNNode { albums[music?.track.id ?? RoomTrack.library[0].id]! }
    func albumNode(id:String) -> SCNNode { albums[id]! }
    private var lastTrackID: String?
    private var discMetal: SCNMaterial!, discLabel: SCNMaterial!, discAccent: SCNMaterial!
    private let player = SCNNode(), grip = SCNNode(), string = SCNNode()
    private weak var music: RoomMusic?
    private var spin: CGFloat = 0
    private var lastPhase: RoomMusic.Phase?
    private var flightOrigin = SCNVector3Zero
    private var flightScale: CGFloat = 1
    private func home(for id:String) -> SCNVector3 {
        let index = RoomTrack.library.firstIndex { $0.id == id } ?? 0
        return SCNVector3(1.05+CGFloat(index)*0.24,0.895-CGFloat(index)*0.006,-0.72+CGFloat(index)*0.055)
    }
    private let display = SCNVector3(0,2.05,2.7)
    private let spindle = SCNVector3(1.90,2.43,-1.04)
    var hoveredAlbumID: String?
    private(set) var pull: CGFloat = 0
    private var cordElapsed: Double?
    @discardableResult func triggerCord() -> Bool {
        guard cordElapsed == nil else { return false }
        cordElapsed = 0
        return true
    }
    func cancelCordAnimation() { cordElapsed = nil; pull = 0 }
    init() {
        disc.name = "cdDisc"; cord.name = "cdCord"
        root.name = "musicRig"; root.addChildNode(disc); root.addChildNode(player)
        let cream = material(NSColor(red:0.88,green:0.89,blue:0.83,alpha:1))
        let silver = material(NSColor(white:0.69,alpha:1))
        let dark = material(NSColor(white:0.21,alpha:1))
        player.position = SCNVector3(1.90,2.43,-1.20)
        box(0.59,0.59,0.13,SCNVector3Zero,cream,player,bevel:0.04)
        // Speaker perforations are baked into one small nearest-sampled texture.
        let face = SCNPlane(width:0.54,height:0.54)
        face.materials = [material(Self.speakerTexture())]
        let faceNode = SCNNode(geometry:face); faceNode.position.z = 0.071; player.addChildNode(faceNode)
        tube(0,0.235,0.045,dark,player,at:SCNVector3(0,0,0.09))
        tube(0,0.043,0.065,silver,player,at:SCNVector3(0,0,0.13))
        player.addChildNode(cord)
        let line = SCNCylinder(radius:0.008,height:1.0); line.radialSegmentCount = 5; line.materials = [material(NSColor(white:0.06,alpha:1))]
        string.geometry = line; string.position = SCNVector3(0,-0.79,0.025); cord.addChildNode(string)
        box(0.045,0.11,0.035,SCNVector3(0,-1.31,0.025),material(NSColor(white:0.06,alpha:1)),grip)
        cord.addChildNode(grip)
        let hit = box(0.14,1.16,0.06,SCNVector3(0,-0.85,0.03),material(NSColor.white.withAlphaComponent(0.005)),cord)
        hit.name = "cordHit"
        for track in RoomTrack.library {
            let album = AlbumSceneNode(); album.name = "cdAlbum"; album.trackID = track.id
            album.position = home(for:track.id); root.addChildNode(album); albums[track.id] = album
            let art = material(Self.albumTexture(track:track)); art.lightingModel = .constant
            box(0.30,0.30,0.045,SCNVector3Zero,material(NSColor(white:0.72,alpha:1)),album,bevel:0.005)
            let cover = SCNPlane(width:0.28,height:0.28); cover.materials = [art]
            let coverNode = SCNNode(geometry:cover); coverNode.position.z = 0.025; album.addChildNode(coverNode)
            let band = material(track.palette.colors.accent)
            box(0.022,0.29,0.006,SCNVector3(-0.132,0,0.029),band,album)
        }
        discMetal = material(NSColor(white:0.69,alpha:1))
        discLabel = material(NSColor(red:0.88,green:0.89,blue:0.83,alpha:1))
        discAccent = material(NSColor(red:0.47,green:0.56,blue:0.52,alpha:1))
        tube(0.027,0.215,0.015,discMetal,disc,at:SCNVector3Zero)
        tube(0.027,0.115,0.017,discLabel,disc,at:SCNVector3(0,0,0.002))
        for radius: CGFloat in [0.13,0.17,0.20] {
            let ring = SCNTorus(ringRadius:radius,pipeRadius:0.0015); ring.ringSegmentCount = 32; ring.pipeSegmentCount = 3; ring.materials = [discAccent]
            let node = SCNNode(geometry:ring); node.eulerAngles.x = .pi/2; node.position.z = 0.011; disc.addChildNode(node)
        }
        box(0.025,0.055,0.003,SCNVector3(0.055,0.045,0.012),discAccent,disc)
    }
    func configure(_ music:RoomMusic) { self.music = music }
    func attach(to scene:SCNScene) { root.removeFromParentNode(); scene.rootNode.addChildNode(root) }
    func update(_ delta:Double) {
        guard let music else { return }
        let t = CGFloat(min(1,max(0,Date().timeIntervalSince(music.transitionStart)/1.8)))
        let eased = t*t*(3-2*t)
        let phase = music.phase
        if lastTrackID != music.track.id {
            let colors = music.track.palette.colors
            discMetal.diffuse.contents = colors.metal
            discLabel.diffuse.contents = colors.label
            discAccent.diffuse.contents = colors.accent
            lastTrackID = music.track.id
        }
        if lastPhase != phase {
            if phase == .disc { disc.position = album.position; disc.scale = SCNVector3(1.4,1.4,1.4) }
            if music.flying { flightOrigin = disc.position; flightScale = disc.scale.x }
            lastPhase = phase
        }
        player.name = phase == .loaded ? "cdDisc" : nil
        let blend = CGFloat(min(1,delta*9))
        for track in RoomTrack.library {
            let node = albums[track.id]!
            var destination = home(for:track.id), scale: CGFloat = 1
            if track.id == music.track.id {
                if phase == .album { destination = display; scale = 6 }
                if phase == .disc { destination = SCNVector3(-0.65,2.05,2.65); scale = 4 }
            }
            if phase == .shelf && hoveredAlbumID == track.id { destination.z += 0.16 }
            node.position = lerp(node.position,destination,blend)
            node.scale = lerp(node.scale,SCNVector3(scale,scale,scale),blend)
        }
        disc.isHidden = phase == .shelf || phase == .album
        switch phase {
        case .disc:
            disc.position = lerp(disc.position,SCNVector3(0.55,2.05,2.8),blend)
            disc.scale = lerp(disc.scale,SCNVector3(2.5,2.5,2.5),blend)
        case .inserting:
            disc.position = lerp(flightOrigin,spindle,eased)
            disc.position.y += sin(.pi*eased)*0.40
            let s = flightScale+(1-flightScale)*eased; disc.scale = SCNVector3(s,s,s)
        case .returning:
            disc.position = lerp(flightOrigin,home(for:music.track.id),eased); disc.position.y += sin(.pi*eased)*0.35
            let s = 1-0.4*eased; disc.scale = SCNVector3(s,s,s)
        default: disc.position = spindle; disc.scale = SCNVector3(1,1,1)
        }
        if music.playing { spin += CGFloat(delta)*3.6 }
        disc.eulerAngles.z = spin + (music.flying ? eased * .pi*2 : 0)
        if let elapsed = cordElapsed {
            let next = elapsed + max(0,delta)
            if next >= 0.55 { cordElapsed = nil; pull = 0 }
            else {
                cordElapsed = next
                let phase = next < 0.18 ? next/0.18 : 1-(next-0.18)/0.37
                let ease = phase*phase*(3-2*phase)
                pull = 0.20 * CGFloat(ease)
            }
        }
        let stretch = pull
        string.scale.y = 1+stretch
        string.position.y = -0.79-stretch/2
        grip.position.y = -stretch
    }
    private func lerp(_ a:SCNVector3,_ b:SCNVector3,_ t:CGFloat) -> SCNVector3 { SCNVector3(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t,a.z+(b.z-a.z)*t) }
    private func material(_ contents:Any) -> SCNMaterial {
        let m = SCNMaterial(); m.diffuse.contents = contents; m.diffuse.magnificationFilter = .nearest; m.diffuse.minificationFilter = .nearest; m.lightingModel = .lambert; return m
    }
    @discardableResult private func box(_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ p:SCNVector3,_ m:SCNMaterial,_ parent:SCNNode,bevel:CGFloat = 0) -> SCNNode {
        let g = SCNBox(width:w,height:h,length:d,chamferRadius:bevel); g.chamferSegmentCount = 1; g.materials = [m]
        let n = SCNNode(geometry:g); n.position = p; parent.addChildNode(n); return n
    }
    private func tube(_ inner:CGFloat,_ outer:CGFloat,_ height:CGFloat,_ m:SCNMaterial,_ parent:SCNNode,at p:SCNVector3) {
        let g = SCNTube(innerRadius:inner,outerRadius:outer,height:height); g.radialSegmentCount = 32; g.materials = [m]
        let n = SCNNode(geometry:g); n.eulerAngles.x = .pi/2; n.position = p; parent.addChildNode(n)
    }
    private static func speakerTexture() -> NSImage {
        let image = NSImage(size:NSSize(width:64,height:64)); image.lockFocus()
        NSColor(red:0.87,green:0.88,blue:0.81,alpha:1).setFill(); NSRect(x:0,y:0,width:64,height:64).fill()
        NSColor(white:0.48,alpha:0.7).setFill()
        for y in stride(from:2,to:64,by:3) { for x in stride(from:2,to:64,by:3) { NSRect(x:CGFloat(x),y:CGFloat(y),width:1,height:1).fill() } }
        image.unlockFocus(); return image
    }
    private static func albumTexture(track:RoomTrack) -> NSImage {
        let colors = track.palette.colors
        let dreamy = track.palette == .lavender
        let image = NSImage(size:NSSize(width:256,height:256)); image.lockFocus()
        colors.paper.setFill(); NSRect(x:0,y:0,width:256,height:256).fill()
        colors.frame.setFill(); NSRect(x:36,y:76,width:184,height:150).fill()
        colors.glass.setFill()
        for x in [48,136] { for y in [88,156] { NSRect(x:CGFloat(x),y:CGFloat(y),width:72,height:56).fill() } }
        if dreamy {
            NSColor(red:0.95,green:0.91,blue:0.74,alpha:1).setFill()
            NSBezierPath(ovalIn:NSRect(x:171,y:184,width:25,height:25)).fill()
        }
        if track.palette == .yellow {
            NSColor(red:0.78,green:0.33,blue:0.23,alpha:1).setFill()
            NSBezierPath(ovalIn:NSRect(x:171,y:180,width:25,height:25)).fill()
            NSColor(red:0.39,green:0.48,blue:0.24,alpha:1).setFill()
            NSRect(x:181,y:202,width:5,height:8).fill()
            NSRect(x:176,y:201,width:15,height:3).fill()
        }
        image.unlockFocus(); return image
    }
}

private struct MusicColors {
    let paper, frame, glass, ink, metal, label, accent: NSColor
}
private extension RoomTrack.Palette {
    var colors: MusicColors {
        func rgb(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat) -> NSColor { NSColor(red:r,green:g,blue:b,alpha:1) }
        switch self {
        case .sage:
            return MusicColors(paper:rgb(0.85,0.88,0.78),frame:rgb(0.42,0.53,0.46),glass:rgb(0.76,0.82,0.72),ink:rgb(0.21,0.31,0.26),metal:rgb(0.69,0.69,0.69),label:rgb(0.88,0.89,0.83),accent:rgb(0.47,0.56,0.52))
        case .lavender:
            return MusicColors(paper:rgb(0.87,0.84,0.94),frame:rgb(0.46,0.40,0.61),glass:rgb(0.67,0.66,0.83),ink:rgb(0.31,0.24,0.43),metal:rgb(0.72,0.68,0.83),label:rgb(0.87,0.80,0.95),accent:rgb(0.54,0.46,0.66))
        case .yellow:
            return MusicColors(paper:rgb(0.97,0.93,0.72),frame:rgb(0.66,0.61,0.35),glass:rgb(0.88,0.83,0.57),ink:rgb(0.42,0.35,0.18),metal:rgb(0.87,0.81,0.55),label:rgb(0.99,0.94,0.73),accent:rgb(0.67,0.58,0.28))
        }
    }
}
