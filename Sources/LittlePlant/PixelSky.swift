import AppKit
import SceneKit
import PlantCore

/// A tiny ordered-dither texture, shared by every weather variant.
final class PixelSkyNode: SCNNode {
    private let climate: Climate
    private let hour: Int
    private var frame: Int?
    init(climate:Climate,hour:Int) {
        self.climate = climate; self.hour = hour
        super.init()
        name = "window"; position = SCNVector3(0.65,2.22,-1.405)
        let box = SCNBox(width:1.6,height:1.65,length:0.035,chamferRadius:0)
        let material = SCNMaterial(); material.lightingModel = .constant
        material.diffuse.magnificationFilter = .nearest; material.diffuse.minificationFilter = .nearest; material.diffuse.mipFilter = .none
        box.materials = [material]; geometry = box
        update(time:Date.timeIntervalSinceReferenceDate)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) has not been implemented") }
    func update(time:Double) {
        let key = PixelSky.hasClouds(climate:climate,hour:hour) ? Int(time*2) : 0
        guard key != frame else { return }
        frame = key
        geometry?.firstMaterial?.diffuse.contents = PixelSky.texture(climate:climate,hour:hour,time:time)
    }
}

enum PixelSky {
    static let width = 64, height = 80
    private static let bayer = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
    private static let cloud = [
        ".....####......",
        "...########....",
        ".############..",
        "##############.",
        ".##############",
        "..############.",
        "....########..."
    ].map(Array.init)
    static func hasClouds(climate:Climate,hour:Int) -> Bool {
        climate.daylight && [.clear,.partlyCloudy].contains(climate.condition) && (5..<12).contains(hour)
    }
    private static func palette(_ climate:Climate,hour:Int) -> [(Double,Double,Double)] {
        if climate.condition == .snow {
            return climate.daylight ? [(0.29,0.37,0.47),(0.44,0.53,0.63),(0.64,0.72,0.80),(0.84,0.88,0.92)] : [(0.035,0.055,0.10),(0.09,0.13,0.20),(0.19,0.25,0.34),(0.34,0.41,0.49)]
        }
        if !climate.daylight {
            if climate.rain { return [(0.025,0.035,0.075),(0.07,0.09,0.16),(0.13,0.17,0.25),(0.24,0.29,0.37)] }
            return [(0.025,0.045,0.14),(0.07,0.12,0.26),(0.13,0.23,0.40),(0.29,0.40,0.57)]
        }
        if climate.rain { return [(0.24,0.31,0.42),(0.37,0.46,0.56),(0.52,0.61,0.69),(0.72,0.79,0.83)] }
        let clear: [(Double,Double,Double)] = [(0.14,0.43,0.79),(0.27,0.58,0.87),(0.43,0.72,0.93),(0.64,0.84,0.97),(0.86,0.94,0.99)]
        let grey = min(0.68,0.06+max(0,(climate.skyCloudCover-30)/110))
        let evening = hour >= 17 ? 0.86 : 1.0
        return clear.map { r,g,b in
            let mean = (r+g+b)/3
            return ((r+(mean-r)*grey)*evening,(g+(mean-g)*grey)*evening,(b+(mean-b)*grey)*evening)
        }
    }
    static func texture(climate:Climate,hour:Int,time:Double) -> NSImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
        let bytes = bitmap.bitmapData!, colors = palette(climate,hour:hour)
        func pixel(_ x:Int,_ y:Int,_ color:(Double,Double,Double)) {
            guard x >= 0 && x < width && y >= 0 && y < height else { return }
            let index = y*bitmap.bytesPerRow+x*4
            bytes[index] = UInt8(max(0,min(255,color.0*255)))
            bytes[index+1] = UInt8(max(0,min(255,color.1*255)))
            bytes[index+2] = UInt8(max(0,min(255,color.2*255)))
            bytes[index+3] = 255
        }
        for y in 0..<height {
            let level = Double(y)/Double(height-1)*Double(colors.count-1)
            let base = Int(level), fraction = level-Double(base)
            for x in 0..<width {
                let threshold = (Double(bayer[(y%4)*4+x%4])+0.5)/16
                let band = min(colors.count-1,base+(fraction > threshold ? 1 : 0))
                pixel(x,y,colors[band])
            }
        }
        if hasClouds(climate:climate,hour:hour) {
            for (i,altitude) in [12,29,44].enumerated() {
                let x = cloudX(time:time,index:i)
                for row in cloud.indices {
                    for column in cloud[row].indices where cloud[row][column] == "#" {
                        pixel(x+column,altitude+row,row >= 5 ? (0.79,0.87,0.93) : (0.96,0.98,1))
                    }
                }
            }
        }
        let image = NSImage(size:NSSize(width:width,height:height)); image.addRepresentation(bitmap)
        return image
    }
    static func cloudX(time:Double,index:Int) -> Int {
        // One shared drift preserves spacing and keeps every cloud on the same pixel step.
        let drift = Int(floor(time*0.4))
        return (drift+index*27) % (width+16)-16
    }
    static func verify() {
        let climates = [Climate(),Climate(temperature:18,humidity:88,cloud:95,rain:true),Climate(daylight:false),Climate(daylight:false,rain:true)]
        for climate in climates {
            let image = texture(climate:climate,hour:8,time:0)
            let bitmap = image.representations.first as! NSBitmapImageRep
            let top = bitmap.colorAt(x:0,y:0)!.usingColorSpace(.deviceRGB)!
            let bottom = bitmap.colorAt(x:0,y:height-1)!.usingColorSpace(.deviceRGB)!
            precondition(top.redComponent+top.greenComponent+top.blueComponent < bottom.redComponent+bottom.greenComponent+bottom.blueComponent,"Sky must be darker above and lighter below in every weather")
        }
        precondition(hasClouds(climate:Climate(),hour:8) && !hasClouds(climate:Climate(),hour:14))
        precondition(!hasClouds(climate:Climate(rain:true),hour:8) && !hasClouds(climate:Climate(daylight:false),hour:8))
        precondition(cloudX(time:15,index:0)>cloudX(time:0,index:0),"Morning clouds must drift sideways")
        for time in [0.0,13,125,199,4000] {
            let span = width+16
            let expected = (cloudX(time:time+17,index:0)-cloudX(time:time,index:0)+span)%span
            for index in 1..<3 {
                let motion = (cloudX(time:time+17,index:index)-cloudX(time:time,index:index)+span)%span
                precondition(motion == expected,"Clouds must move together, including across wraparound")
            }
        }
        fputs("PASS: weather gradients, morning-only clouds, shared speed/direction and spacing through wraparound\n",stderr)
    }
}
