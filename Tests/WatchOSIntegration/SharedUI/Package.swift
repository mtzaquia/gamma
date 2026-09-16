// swift-tools-version: 6.3
import PackageDescription
let package = Package(
    name: "SharedUI",
    platforms: [.iOS(.v17), .watchOS("26.0")],
    products: [.library(name: "SharedUI", targets: ["SharedUI"])],
    dependencies: [.package(name: "gamma", path: "../../..")],
    targets: [.target(name: "SharedUI", dependencies: [.product(name: "Gamma", package: "gamma")],
        resources: [.process("Resources")],
        plugins: [.plugin(name: "GammaBuildPlugin", package: "gamma")])]
)
