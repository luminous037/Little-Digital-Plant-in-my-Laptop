import AppKit
import SceneKit

final class LeafSceneNode: SCNNode { var slot = 0 }

/// Petiole at the heart-shaped notch; the broad blade hangs down to its pointed tip.
/// Rounded lobes and narrow cuts keep the silhouette continuous instead of fern-like.
enum MonsteraLeaf {
    static func outline(juvenile: Bool = false) -> NSBezierPath {
        let p = NSBezierPath()
        func curve(_ x: CGFloat, _ y: CGFloat, _ ax: CGFloat, _ ay: CGFloat, _ bx: CGFloat, _ by: CGFloat) {
            p.curve(to: NSPoint(x:x,y:y), controlPoint1:NSPoint(x:ax,y:ay), controlPoint2:NSPoint(x:bx,y:by))
        }
        p.move(to: .zero)
        curve(-0.33,0.25, -0.09,0.10, -0.13,0.30)
        curve(-0.60,0.12, -0.47,0.28, -0.58,0.24)
        curve(-0.65,-0.10, -0.65,0.07, -0.67,-0.02)
        if juvenile {
            curve(-0.42,-0.74, -0.68,-0.38, -0.58,-0.59)
        } else {
            curve(-0.29,-0.23, -0.49,-0.10, -0.34,-0.18)
            curve(-0.29,-0.25, -0.26,-0.23, -0.26,-0.25)
            curve(-0.65,-0.15, -0.39,-0.22, -0.55,-0.15)
            curve(-0.60,-0.39, -0.66,-0.23, -0.65,-0.33)
            curve(-0.25,-0.43, -0.48,-0.33, -0.32,-0.38)
            curve(-0.25,-0.45, -0.22,-0.43, -0.22,-0.45)
            curve(-0.58,-0.44, -0.35,-0.41, -0.50,-0.40)
            curve(-0.44,-0.68, -0.57,-0.53, -0.51,-0.63)
            curve(-0.22,-0.65, -0.35,-0.59, -0.27,-0.61)
            curve(-0.22,-0.68, -0.19,-0.64, -0.19,-0.67)
            curve(-0.40,-0.74, -0.29,-0.69, -0.35,-0.70)
        }
        curve(0,-1.10, -0.31,-0.94, -0.07,-0.95)
        curve(0.40,-0.74, 0.08,-0.96, 0.31,-0.94)
        if juvenile {
            curve(0.65,-0.10, 0.59,-0.62, 0.69,-0.33)
        } else {
            curve(0.22,-0.68, 0.35,-0.70, 0.29,-0.69)
            curve(0.22,-0.65, 0.19,-0.67, 0.19,-0.64)
            curve(0.44,-0.68, 0.27,-0.61, 0.35,-0.59)
            curve(0.58,-0.44, 0.51,-0.63, 0.57,-0.53)
            curve(0.25,-0.45, 0.50,-0.40, 0.35,-0.41)
            curve(0.25,-0.43, 0.22,-0.45, 0.22,-0.43)
            curve(0.60,-0.39, 0.32,-0.38, 0.48,-0.33)
            curve(0.65,-0.15, 0.65,-0.33, 0.66,-0.23)
            curve(0.29,-0.25, 0.55,-0.15, 0.39,-0.22)
            curve(0.29,-0.23, 0.26,-0.25, 0.26,-0.23)
            curve(0.65,-0.10, 0.34,-0.18, 0.49,-0.10)
        }
        curve(0.60,0.12, 0.67,-0.02, 0.65,0.07)
        curve(0.33,0.25, 0.58,0.24, 0.47,0.28)
        curve(0,0, 0.13,0.30, 0.09,0.10)
        p.close()
        if !juvenile {
            p.appendOval(in: NSRect(x:-0.14,y:-0.39,width:0.06,height:0.13))
            p.appendOval(in: NSRect(x:0.08,y:-0.61,width:0.055,height:0.12))
        }
        p.windingRule = .evenOdd
        p.flatness = 0.012
        return p
    }
}
