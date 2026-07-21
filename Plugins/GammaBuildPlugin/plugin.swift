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
struct GammaBuildPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: any Target
    ) async throws -> [Command] {
        guard let sourceTarget = target as? any SourceModuleTarget else { return [] }
        return try commands(
            inputURLs: sourceTarget.sourceFiles.map(\.url),
            workDirectoryURL: context.pluginWorkDirectoryURL,
            toolURL: context.tool(named: "gamma-codegen").url
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GammaBuildPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        try commands(
            inputURLs: target.inputFiles.map(\.url),
            workDirectoryURL: context.pluginWorkDirectoryURL,
            toolURL: try context.tool(named: "gamma-codegen").url
        )
    }
}
#endif

private func commands(
    inputURLs: [URL],
    workDirectoryURL: URL,
    toolURL: URL
) throws -> [Command] {
    let inputs = discoveredInputs(in: inputURLs)
    guard inputs.contains(where: { $0.template == .tokens }) else {
        Diagnostics.error(
            "GammaBuildPlugin found no *.theme.json input after searching the target's files "
                + "and folders recursively. Add a file ending exactly in .theme.json, then enable "
                + "its Xcode target membership or declare it as a target resource in Package.swift. "
                + "Otherwise, remove the plug-in from this target."
        )
        return []
    }

    return GenerationTemplate.allCases.compactMap { template in
        let templateInputs = inputs.filter { $0.template == template }.map(\.url)
        guard !templateInputs.isEmpty else { return nil }

        let outputURL = workDirectoryURL.appendingPathComponent(
            "Gamma+\(template.title).generated.swift"
        )
        let inputArguments = templateInputs.flatMap { ["--input", $0.path] }
        return .buildCommand(
            displayName: "Generate Gamma \(template.rawValue) aliases",
            executable: toolURL,
            arguments: inputArguments + [
                "--output-file", outputURL.path,
                "--template", template.rawValue,
            ],
            inputFiles: templateInputs,
            outputFiles: [outputURL]
        )
    }
}

private func discoveredInputs(in urls: [URL]) -> [GeneratorInput] {
    var inputsByPath: [String: GeneratorInput] = [:]

    for url in urls {
        for input in discoveredInputs(at: url) {
            let path = input.url.standardizedFileURL.path
            inputsByPath["\(input.template.rawValue):\(path)"] = input
        }
    }

    return inputsByPath.values.sorted {
        if $0.url.path == $1.url.path {
            $0.template.rawValue < $1.template.rawValue
        } else {
            $0.url.path < $1.url.path
        }
    }
}

private func discoveredInputs(at url: URL) -> [GeneratorInput] {
    if let input = generatorInput(for: url) {
        return [input]
    }

    guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
          let enumerator = FileManager.default.enumerator(
              at: url,
              includingPropertiesForKeys: [.isDirectoryKey],
              options: [.skipsHiddenFiles, .skipsPackageDescendants]
          )
    else {
        return []
    }

    return enumerator.compactMap { element in
        guard let nestedURL = element as? URL else { return nil }
        return generatorInput(for: nestedURL)
    }
}

private func generatorInput(for url: URL) -> GeneratorInput? {
    if url.lastPathComponent.hasSuffix(".theme.json") {
        return GeneratorInput(url: url, template: .tokens)
    }
    if url.pathExtension.caseInsensitiveCompare("xcassets") == .orderedSame {
        return GeneratorInput(url: url, template: .assets)
    }
    return nil
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
