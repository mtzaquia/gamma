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

import GammaCodegenCore
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct GammaCodegenCommand {
    static func main() {
        do {
            let options = try CodeGenerationCommandOptions(
                arguments: Array(CommandLine.arguments.dropFirst())
            )
            if options.showsHelp {
                print(CodeGenerationCommandOptions.help)
                return
            }
            try generate(options: options)
        } catch {
            writeToStandardError("error: \(error.localizedDescription)\n")
            exit(EXIT_FAILURE)
        }
    }

    private static func generate(options: CodeGenerationCommandOptions) throws {
        guard !options.inputURLs.isEmpty else {
            throw CodeGenerationCLIError("--input is required")
        }

        var templates = options.templates.isEmpty ? [.tokens] : options.templates
        let themeInputs = options.inputURLs.filter {
            $0.pathExtension.caseInsensitiveCompare("xcassets") != .orderedSame
        }
        let assetInputs = options.inputURLs

        if themeInputs.isEmpty {
            guard templates.contains(.assets) else {
                throw CodeGenerationCLIError(
                    "The tokens template requires a JSON theme input; .xcassets inputs support assets only."
                )
            }
            if templates.contains(.tokens) {
                writeToStandardError(
                    "warning: skipping the tokens template because the input is an .xcassets catalogue\n"
                )
                templates.removeAll { $0 == .tokens }
            }
        }

        if options.outputFileURL != nil, templates.count != 1 {
            throw CodeGenerationCLIError("--output-file requires exactly one template")
        }
        guard options.outputDirectoryURL != nil || options.outputFileURL != nil else {
            throw CodeGenerationCLIError("--output or --output-file is required")
        }

        for template in templates {
            let inputs = template == .tokens ? themeInputs : assetInputs
            let result = try GammaCodeGenerator.generate(
                inputURLs: inputs,
                template: template
            )

            let outputURL = options.outputFileURL
                ?? options.outputDirectoryURL!.appendingPathComponent(template.defaultOutputFileName)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try result.source.write(to: outputURL, atomically: true, encoding: .utf8)
            let inputDescription = inputs.map(\.path).joined(separator: ", ")
            print("✓ Generated \(outputURL.path) from \(inputDescription)")
        }
    }

    private static func writeToStandardError(_ message: String) {
        FileHandle.standardError.write(Data(message.utf8))
    }
}
