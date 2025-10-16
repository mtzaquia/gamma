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
            context.package.sourceModules.map { $0.sourceFiles.map(\.url) },
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
            context.xcodeProject.targets.map { $0.inputFiles.map(\.url) },
            toolURL: toolURL
        )
    }
}
#endif

private func generateDiscoveredInputs(_ inputGroups: [[URL]], toolURL: URL) throws {
    let targetInputs = inputGroups
        .map { discoveredInputs(in: $0) }
        .filter { !$0.isEmpty }
    guard !targetInputs.isEmpty else {
        Diagnostics.error("No *.theme.json or .xcassets inputs were found.")
        return
    }

    for inputs in targetInputs {
        let outputDirectory = inputs[0].url
            .deletingLastPathComponent()
            .appendingPathComponent("Generated/Gamma", isDirectory: true)

        for template in GenerationTemplate.allCases {
            let templateInputs = inputs.filter { $0.template == template }.map(\.url)
            guard !templateInputs.isEmpty else { continue }

            let outputName = templateInputs.count == 1
                ? "\(outputStem(for: templateInputs[0]))+\(template.title).generated.swift"
                : "Gamma+\(template.title).generated.swift"
            let outputURL = outputDirectory.appendingPathComponent(outputName)
            let inputArguments = templateInputs.flatMap { ["--input", $0.path] }
            try run(
                toolURL: toolURL,
                arguments: inputArguments + [
                    "--output-file", outputURL.path,
                    "--template", template.rawValue,
                ]
            )
        }
    }
}

private func outputStem(for url: URL) -> String {
    let name = url.lastPathComponent
        .replacingOccurrences(of: ".theme.json", with: "")
        .replacingOccurrences(of: ".xcassets", with: "")
    return String(name.map { $0.isLetter || $0.isNumber ? $0 : "-" })
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
