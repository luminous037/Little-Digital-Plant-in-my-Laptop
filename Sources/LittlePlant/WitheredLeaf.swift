import SceneKit
import Metal

/// Bend the real mesh and veins so the blade droops while scissors follow the visible surface.
enum WitheredLeaf {
    private static let preparation = SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
    static func bend(_ point:SCNVector3) -> SCNVector3 {
        let distance = max(0,-point.y)
        let radius: CGFloat = 1.1/1.15
        let angle = min(1.3,distance/radius)
        return SCNVector3(point.x*(1-0.18*distance),point.y > 0 ? point.y : -radius*sin(angle),point.z+radius*(1-cos(angle)))
    }
    private static func vectors(_ source:SCNGeometrySource) -> [SCNVector3] {
        source.data.withUnsafeBytes { raw in
            (0..<source.vectorCount).map { index in
                let offset = source.dataOffset+index*source.dataStride
                func component(_ n:Int) -> CGFloat {
                    let p = offset+n*source.bytesPerComponent
                    if source.bytesPerComponent == 4 { return CGFloat(raw.loadUnaligned(fromByteOffset:p,as:Float.self)) }
                    return CGFloat(raw.loadUnaligned(fromByteOffset:p,as:Double.self))
                }
                return SCNVector3(component(0),component(1),component(2))
            }
        }
    }
    static func geometry(_ shape:SCNShape) -> SCNGeometry {
        // Complex fenestrated paths tessellate lazily; prepare before reading the vertex buffers.
        preparation.prepare(shape,shouldAbortBlock:nil)
        let sources = shape.sources
        guard let source = sources.first(where:{ $0.semantic == .vertex }), source.vectorCount > 0 else { return shape }
        let original = vectors(source)
        let vertices = original.map(bend)
        let originalNormals = sources.first(where:{ $0.semantic == .normal }).map(vectors)
        let normals = original.enumerated().map { index,point -> SCNVector3 in
            let n = originalNormals?.count == original.count ? originalNormals![index] : SCNVector3(0,0,1)
            let angle = min(1.3,max(0,-point.y)/(1.1/1.15))
            return SCNVector3(n.x,n.y*cos(angle)+n.z*sin(angle),-n.y*sin(angle)+n.z*cos(angle))
        }
        let uv = sources.filter { $0.semantic == .texcoord }
        let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)]+uv,elements:shape.elements)
        geometry.materials = shape.materials
        return geometry
    }
    static func verify() {
        let shape = SCNShape(path:MonsteraLeaf.outline(),extrusionDepth:0.012)
        let result = geometry(shape)
        precondition(result !== shape,"Withered blade must use a bent mesh")
        let points = vectors(result.sources(for:.vertex).first!)
        precondition(points.contains { $0.y < -0.7 && $0.z > 0.3 },"Leaf tip must curl down and forward")
        precondition(!result.sources(for:.normal).isEmpty && !result.sources(for:.texcoord).isEmpty,"Curl must preserve lit, textured graphics")
        fputs("PASS: withered mesh curl, downward tip, normals and texture coordinates\n",stderr)
    }
}
