import AppKit
import CoreText

/// Register the supplied fonts only within this process; no system installation.
enum RetroFonts {
    static let temperature = register("Nintendo-DS-BIOS")
    static let clock = register("Galmuri14")
    private static func register(_ filename: String) -> String {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.module.url(forResource: filename, withExtension: "ttf"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            preconditionFailure("Missing bundled font: \(filename)")
        }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        precondition(NSFont(name: name, size: 20) != nil, "Font registration failed: \(name)")
        if CommandLine.arguments.contains("--render-preview") { fputs("Font loaded: \(filename) → \(name)\n", stderr) }
        return name
    }
}
