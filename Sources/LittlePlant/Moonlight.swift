import SceneKit
import AppKit

/// Cool light enters at the window and leaves a four-pane footprint on the floor.
enum Moonlight {
    static func add(to scene:SCNScene,cloud:Double,windowOpen:Bool) {
        let clarity = max(0.25,1-cloud/125)
        let light = SCNNode(); light.name = "moonlight"
        light.light = SCNLight(); light.light?.type = .spot
        light.light?.color = NSColor(red:0.70,green:0.82,blue:1,alpha:1)
        light.light?.intensity = 1900*clarity
        light.light?.spotInnerAngle = 48; light.light?.spotOuterAngle = 88
        light.light?.attenuationStartDistance = 2; light.light?.attenuationEndDistance = 10
        light.light?.castsShadow = true; light.light?.shadowMode = .deferred
        light.light?.shadowColor = NSColor(red:0.06,green:0.09,blue:0.20,alpha:0.5)
        light.light?.shadowRadius = 3; light.light?.shadowMapSize = CGSize(width:512,height:512)
        light.position = SCNVector3(0.95,2.95,-1.08)
        light.look(at:SCNVector3(-0.65,0,1.65))
        scene.rootNode.addChildNode(light)
        let bounce = SCNNode(); bounce.name = "moonlightBounce"
        bounce.light = SCNLight(); bounce.light?.type = .omni
        bounce.light?.color = NSColor(red:0.67,green:0.79,blue:1,alpha:1)
        bounce.light?.intensity = 260*clarity
        bounce.light?.attenuationStartDistance = 1; bounce.light?.attenuationEndDistance = 6
        bounce.position = SCNVector3(0.35,2.4,-0.9); scene.rootNode.addChildNode(bounce)
        // Broad translucent sheets carry the moonbeam from the window to the front of the room.
        for layer in 0..<3 {
            let width = CGFloat(1)-CGFloat(layer)*0.16
            let offset = CGFloat(layer)*0.015
            let points = [SCNVector3(0.63-0.71*width,2.87,-1.16+offset),
                          SCNVector3(0.63+0.71*width,2.87,-1.16+offset),
                          SCNVector3(-0.4+1.35*width,0.02,1.74+offset),
                          SCNVector3(-0.4-1.35*width,0.02,1.74+offset)]
            let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:points)],elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)])
            let material = SCNMaterial(); material.lightingModel = .constant
            material.diffuse.contents = NSColor(red:0.57,green:0.73,blue:1,alpha:0.065*clarity)
            material.isDoubleSided = true; material.blendMode = .add; material.writesToDepthBuffer = false
            geometry.materials = [material]
            let shaft = SCNNode(geometry:geometry); shaft.name = "moonbeam"; shaft.categoryBitMask = 4
            scene.rootNode.addChildNode(shaft)
        }
        // Low-poly projected panes remain visible at the room's retro resolution.
        let gap: CGFloat = windowOpen ? 0.022 : 0.055
        func project(_ x:CGFloat,_ y:CGFloat) -> SCNVector3 { SCNVector3(x-y*0.55,0.014,min(1.78,-1.28+y*1.08)) }
        for row in 0..<2 {
            for column in 0..<2 {
                let x = -0.12+CGFloat(column)*0.78, y = 1.42+CGFloat(row)*0.79
                let vertices = [project(x+gap,y+gap),project(x+0.75-gap,y+gap),project(x+0.75-gap,y+0.76-gap),project(x+gap,y+0.76-gap)]
                let element = SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)
                let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:vertices)],elements:[element])
                let material = SCNMaterial(); material.lightingModel = .constant
                material.diffuse.contents = NSColor(red:0.60,green:0.75,blue:1,alpha:(windowOpen ? 0.50 : 0.42)*clarity)
                material.isDoubleSided = true; material.writesToDepthBuffer = false
                geometry.materials = [material]
                let pane = SCNNode(geometry:geometry); pane.name = "moonlitFloor"; pane.categoryBitMask = 4
                scene.rootNode.addChildNode(pane)
            }
        }
    }
}
