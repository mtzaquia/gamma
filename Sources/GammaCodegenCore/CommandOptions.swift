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

package struct CodeGenerationCommandOptions {
    package var inputURLs: [URL] = []
    package var outputDirectoryURL: URL?
    package var outputFileURL: URL?
    package var templates: [GenerationTemplate] = []
    package var showsHelp = false

    package init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "-h", "--help":
                showsHelp = true
                index += 1
            case "-i", "--input":
                inputURLs.append(
                    URL(fileURLWithPath: try value(after: argument, arguments: arguments, index: &index))
                )
            case "-o", "--output":
                outputDirectoryURL = URL(
                    fileURLWithPath: try value(after: argument, arguments: arguments, index: &index),
                    isDirectory: true
                )
            case "--output-file":
                outputFileURL = URL(
                    fileURLWithPath: try value(after: argument, arguments: arguments, index: &index)
                )
            case "-t", "--template":
                templates = try parseTemplates(
                    try value(after: argument, arguments: arguments, index: &index)
                )
            default:
                throw CodeGenerationCLIError("Unknown argument: \(argument)")
            }
        }
    }

    private func value(
        after option: String,
        arguments: [String],
        index: inout Int
    ) throws -> String {
        let valueIndex = index + 1
        guard arguments.indices.contains(valueIndex) else {
            throw CodeGenerationCLIError("Missing value for \(option)")
        }
        index += 2
        return arguments[valueIndex]
    }

    private func parseTemplates(_ value: String) throws -> [GenerationTemplate] {
        let names = value == "both"
            ? ["tokens", "assets"]
            : value.split(separator: ",").map(String.init)
        return try names.map { name in
            guard let template = GenerationTemplate(
                rawValue: name.trimmingCharacters(in: .whitespaces)
            ) else {
                throw CodeGenerationCLIError(
                    "Unknown template \(name.debugDescription); use tokens, assets, or both"
                )
            }
            return template
        }
    }

    package static let help = """
    Usage: gamma-codegen [options]

      -i, --input PATH          Theme JSON file or .xcassets catalogue; repeatable
      -o, --output PATH         Output directory
          --output-file PATH    Exact output file; requires one template
      -t, --template TYPE       tokens, assets, both, or a comma-separated list
      -h, --help                Show this help
    """
}

package struct CodeGenerationCLIError: Error, LocalizedError {
    package let message: String

    package init(_ message: String) {
        self.message = message
    }

    package var errorDescription: String? { message }
}
