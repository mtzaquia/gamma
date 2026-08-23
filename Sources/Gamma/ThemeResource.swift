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

import GammaSchema
import Foundation

/// A generated reference to a bundled `*.theme.json` file.
public struct ThemeResource: Hashable, Sendable {
    /// The complete resource filename, including `.theme.json`.
    public let fileName: String

    public init(fileName: String) {
        self.fileName = fileName
    }

    /// Loads and validates this theme from a bundle.
    public func load(from bundle: Bundle = .main) throws -> RawTheme {
        try Self.load(fileName: fileName, from: bundle)
    }

    nonisolated static func load(fileName: String, from bundle: Bundle) throws -> RawTheme {
        let fileURL = URL(fileURLWithPath: fileName)
        let resourceName = fileURL.deletingPathExtension().lastPathComponent
        let resourceExtension = fileURL.pathExtension
        guard let url = bundle.url(
            forResource: resourceName,
            withExtension: resourceExtension.isEmpty ? nil : resourceExtension
        ) else {
            throw ThemeResourceError.notFound(fileName: fileName, bundle: bundle.bundleURL)
        }

        do {
            return try JSONDecoder().decode(RawTheme.self, from: Data(contentsOf: url))
        } catch {
            throw ThemeResourceError.invalidTheme(fileName: fileName, underlying: error)
        }
    }
}

/// Errors produced while loading a generated theme resource.
public enum ThemeResourceError: Error, LocalizedError {
    case notFound(fileName: String, bundle: URL)
    case invalidTheme(fileName: String, underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case let .notFound(fileName, bundle):
            "Theme resource \(fileName.debugDescription) was not found in bundle at \(bundle.path)."
        case let .invalidTheme(fileName, underlying):
            "Theme resource \(fileName.debugDescription) is invalid: \(themeDecodingDescription(underlying))"
        }
    }
}

nonisolated struct ThemeResourceCacheKey: Hashable, Sendable {
    let fileName: String
    let bundleURL: URL
}

enum ThemeResourceCache {
    private static let store = ThemeResourceStore()

    static func count() async -> Int {
        await store.count
    }

    static func removeAll() async {
        await store.removeAll()
    }

    static func load(_ resource: ThemeResource, from bundle: Bundle) async -> RawTheme {
        await store.load(resource, from: bundle)
    }
}

private actor ThemeResourceStore {
    private var themes: [ThemeResourceCacheKey: RawTheme] = [:]

    var count: Int { themes.count }

    func removeAll() {
        themes.removeAll()
    }

    func load(_ resource: ThemeResource, from bundle: Bundle) -> RawTheme {
        let key = ThemeResourceCacheKey(
            fileName: resource.fileName,
            bundleURL: bundle.bundleURL.standardizedFileURL
        )
        if let theme = themes[key] {
            return theme
        }

        do {
            let theme = try ThemeResource.load(fileName: resource.fileName, from: bundle)
            themes[key] = theme
            return theme
        } catch {
            preconditionFailure(
                "Gamma could not install theme resource "
                    + "\(resource.fileName.debugDescription): \(error.localizedDescription)"
            )
        }
    }
}
