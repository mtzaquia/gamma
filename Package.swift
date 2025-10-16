// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let defaultSwiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]

let package = Package(
    name: "Gamma",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Gamma", targets: ["Gamma"]),
        .executable(name: "gamma-codegen", targets: ["gamma-codegen"]),
        .plugin(name: "GammaBuildPlugin", targets: ["GammaBuildPlugin"]),
        .plugin(name: "GammaGeneratePlugin", targets: ["GammaGeneratePlugin"]),
    ],
    targets: [
        .target(
            name: "Gamma",
            dependencies: ["GammaSchema"],
            swiftSettings: defaultSwiftSettings
        ),
        .target(name: "GammaSchema"),
        .target(
            name: "GammaCodegenCore",
            dependencies: ["GammaSchema"]
        ),
        .executableTarget(
            name: "gamma-codegen",
            dependencies: ["GammaCodegenCore"]
        ),
        .plugin(
            name: "GammaBuildPlugin",
            capability: .buildTool(),
            dependencies: ["gamma-codegen"]
        ),
        .plugin(
            name: "GammaGeneratePlugin",
            capability: .command(
                intent: .custom(
                    verb: "generate-gamma",
                    description: "Generate Gamma Aliases"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "This command writes generated Swift sources next to the selected inputs."
                    ),
                ]
            ),
            dependencies: ["gamma-codegen"]
        ),
        .testTarget(
            name: "GammaTests",
            dependencies: [
                .target(
                    name: "Gamma",
                    condition: .when(platforms: [.iOS])
                ),
            ],
            resources: [.process("Resources")],
            swiftSettings: defaultSwiftSettings
        ),
        .testTarget(
            name: "GammaCodegenTests",
            dependencies: ["GammaCodegenCore"]
        ),
    ]
)
