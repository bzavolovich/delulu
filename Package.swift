// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Delulu",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Delulu", targets: ["Delulu"])],
    targets: [
        .target(name: "DeluluCore"),
        .executableTarget(name: "Delulu", dependencies: ["DeluluCore"]),
        .testTarget(name: "DeluluCoreTests", dependencies: ["DeluluCore"])
    ]
)
