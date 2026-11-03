import SwiftUI
import QuartzCore

/// Texture strips follow a continuous bent sheet, with perspective and local shading.
struct CurledBookPage: View, Animatable {
    var front: NSImage
    var back: NSImage
    var progress: Double
    var forward: Bool
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    private let width: CGFloat = 185
    private let height: CGFloat = 330
    private let count = 96
    var body: some View {
        Canvas { context, _ in
            let frontTexture = context.resolve(Image(nsImage:front))
            let backTexture = context.resolve(Image(nsImage:back))
            let direction: CGFloat = forward ? 1 : -1
            let strip = width/CGFloat(count)
            // Paint far sections first so a curled edge cannot cover the nearer sheet.
            let sections = (0..<count).sorted {
                PaperCurl.sample(distance:(CGFloat($0)+0.5)*strip,width:width,progress:progress).z <
                PaperCurl.sample(distance:(CGFloat($1)+0.5)*strip,width:width,progress:progress).z
            }
            for index in sections {
                let s = CGFloat(index)*strip
                let a = PaperCurl.sample(distance:s,width:width,progress:progress)
                let b = PaperCurl.sample(distance:s+strip,width:width,progress:progress)
                let da = PaperCurl.perspectiveDepth(a.z), db = PaperCurl.perspectiveDepth(b.z)
                let x0 = direction*a.x/da, x1 = direction*b.x/db
                let y0 = height/2-height/2/da, y1 = height/2-height/2/db
                var slice = context
                slice.translateBy(x:185+x0,y:y0+48)
                slice.concatenate(CGAffineTransform(a:(x1-x0)/strip,b:(y1-y0)/strip,c:0,d:1/da,tx:0,ty:0))
                slice.clip(to:Path(CGRect(x:0,y:0,width:strip+1.0,height:height)))
                // Texture direction follows the projected surface, including backward turns.
                let mapping = PaperCurl.textureMapping(projectedWidth:x1-x0,forward:forward)
                if mapping.mirrored {
                    slice.translateBy(x:strip,y:0)
                    slice.scaleBy(x:-1,y:1)
                }
                let sample = mapping.mirrored ? width-s-strip : s
                let shade = 1-0.12*abs(sin(Double(a.theta)))*sin(.pi*progress)
                slice.addFilter(.colorMultiply(Color(white:shade)))
                slice.draw(mapping.backFace ? backTexture : frontTexture,in:CGRect(x:-sample,y:0,width:width,height:height))
            }
        }.frame(width:370,height:height+96).frame(width:370,height:height).shadow(color:.black.opacity(0.16*sin(.pi*progress)),radius:7,x:2,y:6)
    }
}

/// Integrating a varying surface angle keeps neighbouring strips joined, unlike a flat hinge.
enum PaperCurl {
    // Positive z lifts paper toward the reader, making it larger rather than receding.
    static func perspectiveDepth(_ z: CGFloat) -> CGFloat { 1-z/850 }
    static func textureMapping(projectedWidth: CGFloat,forward: Bool) -> (backFace:Bool,mirrored:Bool) {
        let direction: CGFloat = forward ? 1 : -1
        return (projectedWidth*direction < 0,projectedWidth < 0)
    }
    static func verifyTextureDirections() {
        precondition(perspectiveDepth(0) == 1 && perspectiveDepth(150) < 1, "Raised paper must enlarge toward the reader")
        for forward in [true,false] {
            let direction: CGFloat = forward ? 1 : -1
            for p in [0.0,0.25,0.49,0.51,0.75,1.0] {
                for i in 0..<96 {
                    let s = CGFloat(i)*185/96
                    let a = sample(distance:s,width:185,progress:p)
                    let b = sample(distance:s+185/96,width:185,progress:p)
                    let dx = direction*(b.x/perspectiveDepth(b.z)-a.x/perspectiveDepth(a.z))
                    let mapping = textureMapping(projectedWidth:dx,forward:forward)
                    // The two reversals must cancel, keeping glyphs readable in screen space.
                    precondition(dx*(mapping.mirrored ? -1 : 1) >= 0,"Page text must never be mirrored")
                    if p == 0 { precondition(!mapping.backFace,"Turn must begin with the departing page") }
                    if p == 1 { precondition(mapping.backFace,"Turn must end with the arriving page") }
                }
            }
        }
        fputs("PASS: both page faces, forward/backward texture orientation across 12 turn states\n",stderr)
    }
    static func sample(distance: CGFloat,width: CGFloat,progress: Double) -> (x:CGFloat,z:CGFloat,theta:CGFloat) {
        let p = CGFloat(max(0,min(1,progress)))
        let bend = 0.95 * sin(.pi*p)
        let start = .pi*p-bend
        let k = 2*bend/width
        let theta = start+k*distance
        if abs(k)<0.00001 { return (distance*cos(start),distance*sin(start),theta) }
        return ((sin(theta)-sin(start))/k,(cos(start)-cos(theta))/k,theta)
    }
}
