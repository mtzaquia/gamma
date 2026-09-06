//
//  Copyright (c) 2026 @mtzaquia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import PackagePlugin

@main
struct GammaGeneratePlugin: CommandPlugin {
    func performCommand(
        context: PluginContext,
        arguments: [String]
    ) async throws {
        let toolURL = try context.tool(named: "gamma-codegen").url
        if !arguments.isEmpty {
            try run(toolURL: toolURL, arguments: arguments)
            return
        }

        try generateDiscoveredInputs(
            context.package.sourceModules.map {
                GenerationTarget(
                    inputURLs: $0.sourceFiles.map(\.url),
                    outputDirectory: $0.directoryURL.appendingPathComponent("Generated/Gamma", isDirectory: true)
                )
            },
            toolURL: toolURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GammaGeneratePlugin: XcodeCommandPlugin {
    func performCommand(
        context: XcodePluginContext,
        arguments: [String]
    ) throws {
        let toolURL = try context.tool(named: "gamma-codegen").url
        if !arguments.isEmpty {
            try run(toolURL: toolURL, arguments: arguments)
            return
        }

        try generateDiscoveredInputs(
            context.xcodeProject.targets.map {
                GenerationTarget(
                    inputURLs: $0.inputFiles.map(\.url),
                    outputDirectory: context.xcodeProject.directoryURL
                        .appendingPathComponent("Generated/Gamma", isDirectory: true)
                        .appendingPathComponent($0.id, isDirectory: true)
                )
            },
            toolURL: toolURL
        )
    }
}
#endif

private struct GenerationTarget {
    let inputURLs: [URL]
    let outputDirectory: URL
}

private func generateDiscoveredInputs(_ targets: [GenerationTarget], toolURL: URL) throws {
    guard targets.contains(where: { !discoveredInputs(in: $0.inputURLs).isEmpty }) else {
        Diagnostics.error("No *.theme.json or .xcassets inputs were found.")
        return
    }

    for target in targets {
        let inputs = discoveredInputs(in: target.inputURLs)
        guard !inputs.isEmpty else { continue }
        var outputURLs = Set<URL>()

        for template in GenerationTemplate.allCases {
            let templateInputs = inputs.filter { $0.template == template }.map(\.url)
            guard !templateInputs.isEmpty else { continue }

            let outputURL = target.outputDirectory.appendingPathComponent(
                "Gamma+\(template.title).generated.swift"
            )
            let inputArguments = templateInputs.flatMap { ["--input", $0.path] }
            try run(
                toolURL: toolURL,
                arguments: inputArguments + [
                    "--output-file", outputURL.path,
                    "--template", template.rawValue,
                ]
            )
            outputURLs.insert(outputURL.standardizedFileURL)
        }

        // Only retire generated sources after every replacement succeeded. The
        // target's source list also finds legacy outputs beside renamed inputs.
        let legacyDirectories = inputs.map {
            $0.url.deletingLastPathComponent().appendingPathComponent("Generated/Gamma", isDirectory: true)
        }
        let directoryCandidates = (legacyDirectories + [target.outputDirectory]).flatMap {
            (try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil)) ?? []
        }
        for url in Set(target.inputURLs + directoryCandidates) {
            guard !outputURLs.contains(url.standardizedFileURL), isGeneratedOutput(url) else { continue }
            try FileManager.default.removeItem(at: url)
        }
    }
}

private func isGeneratedOutput(_ url: URL) -> Bool {
    let name = url.lastPathComponent
    let components = url.deletingLastPathComponent().pathComponents
    let isGenerationDirectory = zip(components, components.dropFirst()).contains {
        $0 == "Generated" && $1 == "Gamma"
    }
    guard name.hasSuffix("+Tokens.generated.swift") || name.hasSuffix("+Assets.generated.swift"),
          isGenerationDirectory,
          let source = try? String(contentsOf: url, encoding: .utf8)
    else { return false }
    return source.hasPrefix("// swiftlint:disable:next file_header\n// periphery:ignore:all\n#if canImport(Gamma)\n")
}

private func run(toolURL: URL, arguments: [String]) throws {
    let process = Process()
    process.executableURL = toolURL
    process.arguments = arguments
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()

    guard process.terminationReason == .exit, process.terminationStatus == 0 else {
        throw PluginFailure.generatorFailed(status: process.terminationStatus)
    }
}

private func discoveredInputs(in urls: [URL]) -> [GeneratorInput] {
    urls.compactMap { url in
        if url.lastPathComponent.hasSuffix(".theme.json") {
            return GeneratorInput(url: url, template: .tokens)
        }
        if url.pathExtension.caseInsensitiveCompare("xcassets") == .orderedSame {
            return GeneratorInput(url: url, template: .assets)
        }
        return nil
    }
    .sorted {
        if $0.url.path == $1.url.path {
            $0.template.rawValue < $1.template.rawValue
        } else {
            $0.url.path < $1.url.path
        }
    }
}

private struct GeneratorInput {
    let url: URL
    let template: GenerationTemplate
}

private enum GenerationTemplate: String, CaseIterable {
    case tokens
    case assets

    var title: String {
        switch self {
        case .tokens: "Tokens"
        case .assets: "Assets"
        }
    }
}

private enum PluginFailure: Error, CustomStringConvertible {
    case generatorFailed(status: Int32)

    var description: String {
        switch self {
        case let .generatorFailed(status):
            "Gamma generator exited with status \(status)."
        }
    }
}
