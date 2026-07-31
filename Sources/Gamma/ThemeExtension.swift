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

/// The shared structure of a token in a mode-resolved theme family.
///
/// Conforming types define the metadata shared by every family token and
/// the concrete value stored under each mode name. In a target whose default
/// isolation is `MainActor`, declare the token and mode types `nonisolated` so
/// their synthesized `Decodable` conformances can run during theme decoding.
nonisolated public protocol ThemeExtensionToken: Decodable {
    /// The concrete value decoded for one mode.
    associatedtype Mode: Decodable

    /// The display name supplied by the theme producer.
    var name: String { get }

    /// The group used to organize related tokens.
    var group: String { get }

    /// The token values keyed by mode name.
    var modes: [String: Mode] { get }
}

/// Connects a token family to its concrete payload and resolver selection.
nonisolated public protocol ThemeExtension {
    /// The top-level JSON key whose value is the family's token dictionary.
    static var key: String { get }

    /// The concrete token decoded for this family.
    associatedtype Token: ThemeExtensionToken

    /// The resolver value for this family. Custom families normally use the
    /// default `String`; Gamma's built-in families may use richer policies.
    associatedtype Selection: Hashable & Sendable = String
}

nonisolated extension RawColor: ThemeExtensionToken {}
nonisolated extension RawFont: ThemeExtensionToken {}
nonisolated extension RawUnit: ThemeExtensionToken {}

public extension Theme {
    /// The built-in color token family.
    nonisolated enum Colors: ThemeExtension {
        /// The top-level JSON key for color tokens.
        nonisolated public static let key = "colors"
        /// The decoded token type for this family.
        public typealias Token = RawColor
        /// The light and dark mode-name pair selected by the resolver.
        public typealias Selection = ThemeColorModeSelection
    }

    /// The built-in font token family.
    nonisolated enum Fonts: ThemeExtension {
        /// The top-level JSON key for font tokens.
        nonisolated public static let key = "fonts"
        /// The decoded token type for this family.
        public typealias Token = RawFont
        /// The primary and cascade mode names selected by the resolver.
        public typealias Selection = ThemeFontModeSelection
    }

    /// The built-in numeric unit token family.
    nonisolated enum Units: ThemeExtension {
        /// The top-level JSON key for numeric unit tokens.
        nonisolated public static let key = "units"
        /// The decoded token type for this family.
        public typealias Token = RawUnit
        /// The mode name selected by the resolver.
        public typealias Selection = String
    }
}

/// A typed alias for one token in a built-in or consumer-defined family.
nonisolated public struct ThemeExtensionAlias<Extension: ThemeExtension>: RawRepresentable, Hashable, Sendable {
    /// The token key as it appears in the extension's JSON dictionary.
    public var rawValue: String

    /// Creates an alias from a token key.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Registers a consumer-defined token family for validation during theme installation.
///
/// Registration requires the extension's top-level key to exist and contain a
/// keyed dictionary whose values decode as the extension's token type. Gamma
/// also validates the shared `name`, `group`, and `modes` structure. During
/// installation, Gamma requires one resolver-selected mode for the family and
/// verifies that every token contains it.
public struct ThemeExtensionRegistration {
    let identifier: ObjectIdentifier
    let validationImplementation: (RawTheme, ResolvedThemeModes?) -> [ThemeValidationIssue]

    /// Creates a registration for a theme extension family.
    ///
    /// - Parameter family: The family to decode and validate when its theme is installed.
    public init<Extension: ThemeExtension>(_ family: Extension.Type)
    where Extension.Selection == String {
        identifier = ObjectIdentifier(Extension.self)
        validationImplementation = { theme, resolvedModes in
            theme.extensionValidationIssues(
                for: family,
                resolvedModes: resolvedModes
            )
        }
    }
}

extension RawTheme {
    func extensionValidationIssues<Extension: ThemeExtension>(
        for _: Extension.Type,
        resolvedModes: ResolvedThemeModes?
    ) -> [ThemeValidationIssue]
    where Extension.Selection == String {
        let structuralIssues = extensionStructureValidationIssues(forKey: Extension.key)
        guard structuralIssues.isEmpty else { return structuralIssues }

        do {
            let tokens = try ThemeExtensionTokenCache.tokens(for: Extension.self, in: self) ?? [:]
            guard let resolvedModes else { return [] }
            guard let selectedMode = resolvedModes[Extension.self] else {
                return [ThemeValidationIssue(
                    path: "resolver.\(Extension.key)",
                    message: "mode selection is required for the registered extension"
                )]
            }
            guard !selectedMode.isEmpty else {
                return [ThemeValidationIssue(
                    path: "resolver.\(Extension.key)",
                    message: "mode name must not be empty"
                )]
            }

            return tokens.compactMap { alias, token in
                guard token.modes[selectedMode] == nil else { return nil }
                return ThemeValidationIssue(
                    path: "\(Extension.key).\(alias).modes.\(selectedMode)",
                    message: "mode selected by the resolver is missing"
                )
            }
        } catch {
            return [ThemeValidationIssue(
                path: Extension.key,
                message: "does not match \(String(describing: Extension.Token.self)): "
                    + themeDecodingDescription(error)
            )]
        }
    }

    private func extensionStructureValidationIssues(forKey key: String) -> [ThemeValidationIssue] {
        guard !key.isEmpty else {
            return [.init(path: "extensions", message: "extension key must not be empty")]
        }
        guard let payload = extensionPayloads[key] else {
            return [.init(path: key, message: "registered extension payload is missing")]
        }
        guard case let .object(tokens) = payload else {
            return [.init(path: key, message: "expected a keyed token dictionary")]
        }

        var issues: [ThemeValidationIssue] = []
        for (alias, payload) in tokens {
            let path = "\(key).\(alias)"
            if alias.isEmpty {
                issues.append(.init(path: key, message: "token key must not be empty"))
            }
            guard case let .object(token) = payload else {
                issues.append(.init(path: path, message: "expected a token object"))
                continue
            }

            switch token["name"] {
            case let .string(name) where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
                break
            case .string:
                issues.append(.init(path: "\(path).name", message: "token name must not be empty"))
            case nil:
                issues.append(.init(path: "\(path).name", message: "field is required"))
            default:
                issues.append(.init(path: "\(path).name", message: "expected a string"))
            }

            switch token["group"] {
            case .string:
                break
            case nil:
                issues.append(.init(path: "\(path).group", message: "field is required"))
            default:
                issues.append(.init(path: "\(path).group", message: "expected a string"))
            }

            switch token["modes"] {
            case let .object(modes) where modes.isEmpty:
                issues.append(.init(path: "\(path).modes", message: "token must define at least one mode"))
            case let .object(modes):
                for mode in modes.keys where mode.isEmpty {
                    issues.append(.init(path: "\(path).modes", message: "mode name must not be empty"))
                }
            case nil:
                issues.append(.init(path: "\(path).modes", message: "field is required"))
            default:
                issues.append(.init(path: "\(path).modes", message: "expected a keyed mode dictionary"))
            }
        }
        return issues
    }
}

private struct ThemeExtensionTokenCacheKey: Hashable {
    let themeInstanceID: UUID
    let extensionType: ObjectIdentifier
}

enum ThemeExtensionTokenCache {
    private static let cache = BoundedCache<ThemeExtensionTokenCacheKey, Any>(countLimit: 128)

    static func tokens<Extension: ThemeExtension>(
        for _: Extension.Type,
        in theme: RawTheme
    ) throws -> [String: Extension.Token]?
    where Extension.Selection == String {
        let key = ThemeExtensionTokenCacheKey(
            themeInstanceID: theme.instanceID,
            extensionType: ObjectIdentifier(Extension.self)
        )
        if let cached = cache[key] as? [String: Extension.Token] {
            return cached
        }

        guard let payload = theme.extensionPayloads[Extension.key] else { return nil }
        let data = try JSONEncoder().encode(payload)
        let tokens = try JSONDecoder().decode([String: Extension.Token].self, from: data)
        cache[key] = tokens
        return tokens
    }
}
