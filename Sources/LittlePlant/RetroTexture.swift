import AppKit

/// Tiny, deterministic textures, sampled without smoothing like handheld-era 3D.
enum RetroTexture {
    enum Surface: String { case plaster, leaf, soil, ceramic, wood, leather, paper }
    private static var cache: [String: NSImage] = [:]
    static func image(_ color: NSColor, surface: Surface = .plaster) -> NSImage {
        let rgb = color.usingColorSpace(.deviceRGB) ?? .gray
        let key = "\(rgb)-\(surface.rawValue)"
        if let cached = cache[key] { return cached }
        let side = 64
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32)!
        func noise(_ x: Int, _ y: Int, _ seed: Int) -> CGFloat {
            var n = UInt64(x + y * 131 + seed * 977) &* 0x45d9f3b
            n = ((n >> 16) ^ n) &* 0x45d9f3b
            return CGFloat((n ^ (n >> 16)) & 255) / 255
        }
        let bytes = bitmap.bitmapData!
        for y in 0..<side {
            for x in 0..<side {
                let grain = noise(x, y, 7) - 0.5
                let patches = noise(x / 5, y / 6, 19) - 0.5
                var shade: CGFloat
                switch surface {
                case .leaf:
                    shade = grain * 0.09 + patches * 0.10
                    // Baked centre ridge and branching veins, kept chunky at 64 px.
                    shade += x < 32 ? 0.04 : -0.05
                    let vein = abs((x - 32)) / 2
                    if abs(x - 32) < 1 || (y + vein) % 14 == 0 { shade += 0.07 }
                    if noise(x / 3, y / 3, 31) > 0.90 { shade += 0.04 }
                case .leather:
                    shade = grain * 0.075 + patches * 0.045
                    if noise(x,y,53) > 0.91 { shade -= 0.06 }
                case .paper:
                    shade = (noise(0,y,61)-0.5)*0.12 + grain*0.02
                case .wood:
                    let grainLine = noise(x / 2,y / 15,43) - 0.5
                    shade = grainLine * 0.09 + grain * 0.025
                case .soil: shade = grain * 0.24 + patches * 0.16
                case .ceramic: shade = grain * 0.07 + patches * 0.06 + (noise(x,y,13) > 0.985 ? -0.20 : 0)
                case .plaster: shade = grain * 0.05 + patches * 0.035
                }
                let base = y * bitmap.bytesPerRow + x * 4
                for (channel, value) in [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].enumerated() {
                    // Coarse palette bands are intentional, rather than smooth photographic noise.
                    let quantized = (max(0, min(1, value + shade)) * 31).rounded() / 31
                    bytes[base + channel] = UInt8(quantized * 255)
                }
                bytes[base + 3] = 255
            }
        }
        let image = NSImage(size: NSSize(width: side, height: side)); image.addRepresentation(bitmap)
        cache[key] = image
        return image
    }
}
