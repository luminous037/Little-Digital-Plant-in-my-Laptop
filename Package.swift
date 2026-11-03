// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "LittlePlant",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "LittlePlant", targets: ["LittlePlant"])],
    targets: [
        .target(name: "PlantCore"),
        .executableTarget(name: "LittlePlant", dependencies: ["PlantCore"], resources: [.process("Resources")]),
        .executableTarget(name: "PlantChecks", dependencies: ["PlantCore"], path: "Tests/PlantChecks")
    ]
)
