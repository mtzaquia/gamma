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
import GammaSchema
import SwiftUI

/// A failure while constructing a type-safe token override.
nonisolated public enum ThemeTokenOverrideError: Error, Hashable, Sendable {
    /// The alias raw key does not begin with the group represented by its scope.
    case aliasGroupMismatch(alias: String, expectedGroup: String)
}

/// One type-safe replacement for all modes of a theme token.
nonisolated public struct ThemeTokenOverride: Hashable, Sendable {
    let familyKey: String
    let tokenKey: String
    let modes: ThemeJSONValue

    /// Creates a replacement whose value type is determined by its alias family.
    ///
    /// The mode payload must be encodable when an override is constructed in
    /// Swift. Overrides decoded from JSON do not require this initializer.
    ///
    /// - Parameters:
    ///   - alias: The existing token whose complete mode dictionary is replaced.
    ///   - modes: The replacement values keyed by mode name.
    /// - Throws: ``ThemeTokenOverrideError/aliasGroupMismatch(alias:expectedGroup:)``
    ///   when a manually constructed alias violates its group scope, or an
    ///   encoding error when the mode payload cannot be represented as JSON.
    public init<Scope: ThemeAliasScope>(
        _ alias: Theme.Alias<Scope>,
        modes: [String: Scope.Family.Token.Mode]
    ) throws where Scope.Family.Token.Mode: Encodable {
        if let expectedGroup = Scope.groupName, alias.tokenGroup != expectedGroup {
            throw ThemeTokenOverrideError.aliasGroupMismatch(
                alias: alias.rawValue,
                expectedGroup: expectedGroup
            )
        }
        familyKey = Scope.Family.key
        tokenKey = alias.rawValue
        let data = try JSONEncoder().encode(modes)
        self.modes = try JSONDecoder().decode(ThemeJSONValue.self, from: data)
    }
}

/// A set of complete token-mode replacements for one themed view subtree.
///
/// Decoded payloads use top-level family keys such as `colors`, `fonts`,
/// `units`, or a registered extension key. Token keys remain JSON strings on
/// the wire. Use ``ThemeTokenOverride`` when constructing overrides in Swift so
/// each key and mode payload are checked against the alias family.
nonisolated public struct ThemeOverrides: Decodable, Hashable, Sendable {
    let families: [String: [String: ThemeJSONValue]]

    /// Creates overrides from type-safe token replacements.
    ///
    /// When `tokens` contains more than one replacement for the same alias, the
    /// last replacement wins.
    ///
    /// - Parameter tokens: The token replacements to apply.
    public init(tokens: [ThemeTokenOverride] = []) {
        var families: [String: [String: ThemeJSONValue]] = [:]
        for token in tokens {
            families[token.familyKey, default: [:]][token.tokenKey] = token.modes
        }
        self.families = families
    }

    /// Decodes string-keyed token replacements for built-in and extension families.
    ///
    /// Built-in mode payloads are validated during decoding. Consumer-defined
    /// payloads are decoded as JSON and validated against their registered
    /// ``ThemeExtension`` type when the override is applied.
    ///
    /// - Parameter decoder: The decoder supplying the override document.
    /// - Throws: A decoding error when a family is not a token dictionary or a
    ///   built-in mode payload has the wrong shape.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: OverrideCodingKey.self)
        families = try Dictionary(uniqueKeysWithValues: container.allKeys.map { key in
            if key.stringValue == Theme.Colors.key {
                _ = try container.decode(
                    [String: [String: RawColor.Mode]].self,
                    forKey: key
                )
            } else if key.stringValue == Theme.Fonts.key {
                _ = try container.decode(
                    [String: [String: RawFont.Mode]].self,
                    forKey: key
                )
            } else if key.stringValue == Theme.Units.key {
                _ = try container.decode(
                    [String: [String: RawUnit.Mode]].self,
                    forKey: key
                )
            }
            let tokens = try container.decode([String: ThemeJSONValue].self, forKey: key)
            if tokens.values.contains(where: { value in
                guard case .object = value else { return true }
                return false
            }) {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: container,
                    debugDescription: "Override tokens must contain keyed mode dictionaries"
                )
            }
            return (
                key.stringValue,
                tokens
            )
        })
    }

    func tokens(for familyKey: String) -> [String: ThemeJSONValue] {
        families[familyKey, default: [:]]
    }

    var extensionTokenCount: Int {
        families
            .filter { !Self.builtInFamilyKeys.contains($0.key) }
            .values
            .reduce(0) { $0 + $1.count }
    }

    func combinedHash(with parentHash: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(parentHash)
        hasher.combine(self)
        return hasher.finalize()
    }

    private static let builtInFamilyKeys = Set([
        Theme.Colors.key,
        Theme.Fonts.key,
        Theme.Units.key,
    ])
}

private struct OverrideCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// A view that applies decoded token overrides to the theme environment of its content.
///
/// Use this to hot-swap specific built-in or consumer-defined tokens within a
/// subtree without replacing the entire theme.
public struct WithThemeOverrides<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.themeExtensions) private var themeExtensions
    @Environment(\.themeModeResolver) private var modeResolver

    let overrides: ThemeOverrides
    let content: Content

    public var body: some View {
        let modes = modeResolver.modes(
            for: ThemeModeContext(
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                horizontalSizeClass: horizontalSizeClass
            )
        )

        content
            .transformEnvironment(\.theme) { theme in
                let issues = theme.apply(overrides)
                ThemeDiagnostics.validate(
                    theme,
                    modes: modes,
                    extensions: themeExtensions,
                    additionalIssues: issues,
                    isOverride: true
                )
                ThemeDiagnostics.overridesApplied(theme, overrides: overrides)
            }

    }

    /// Creates the view with the given token overrides applied to all content.
    public init(overrides: ThemeOverrides, @ViewBuilder content: () -> Content) {
        self.overrides = overrides
        self.content = content()
    }
}

extension RawTheme {
    mutating func apply(_ overrides: ThemeOverrides) -> [ThemeValidationIssue] {
        var issues: [ThemeValidationIssue] = []

        for (token, payload) in overrides.tokens(for: Theme.Colors.key) {
            guard var color = colors[token] else {
                issues.append(.init(
                    path: "overrides.colors.\(token)",
                    message: "references a color token that does not exist"
                ))
                continue
            }
            do {
                color.modes = try decodeOverrideModes(payload, as: RawColor.Mode.self)
                colors[token] = color
            } catch {
                issues.append(.init(
                    path: "overrides.colors.\(token)",
                    message: "does not contain valid color modes"
                ))
            }
        }

        for (token, payload) in overrides.tokens(for: Theme.Fonts.key) {
            guard var font = fonts[token] else {
                issues.append(.init(
                    path: "overrides.fonts.\(token)",
                    message: "references a font token that does not exist"
                ))
                continue
            }
            do {
                font.modes = try decodeOverrideModes(payload, as: RawFont.Mode.self)
                fonts[token] = font
            } catch {
                issues.append(.init(
                    path: "overrides.fonts.\(token)",
                    message: "does not contain valid font modes"
                ))
            }
        }

        for (token, payload) in overrides.tokens(for: Theme.Units.key) {
            guard var unit = units[token] else {
                issues.append(.init(
                    path: "overrides.units.\(token)",
                    message: "references a unit token that does not exist"
                ))
                continue
            }
            do {
                unit.modes = try decodeOverrideModes(payload, as: RawUnit.Mode.self)
                units[token] = unit
            } catch {
                issues.append(.init(
                    path: "overrides.units.\(token)",
                    message: "does not contain valid unit modes"
                ))
            }
        }

        for (family, tokens) in overrides.families
        where family != Theme.Colors.key
            && family != Theme.Fonts.key
            && family != Theme.Units.key {
            guard case let .object(existingTokens)? = extensionPayloads[family] else {
                issues.append(.init(
                    path: "overrides.\(family)",
                    message: "references a token family that does not exist"
                ))
                continue
            }

            var updatedTokens = existingTokens
            for (token, modes) in tokens {
                guard case let .object(existingToken)? = updatedTokens[token] else {
                    issues.append(.init(
                        path: "overrides.\(family).\(token)",
                        message: "references a token that does not exist"
                    ))
                    continue
                }
                guard case .object = modes else {
                    issues.append(.init(
                        path: "overrides.\(family).\(token)",
                        message: "expected a keyed mode dictionary"
                    ))
                    continue
                }

                var updatedToken = existingToken
                updatedToken["modes"] = modes
                updatedTokens[token] = .object(updatedToken)
            }
            extensionPayloads[family] = .object(updatedTokens)
        }

        overrideHash = overrides.combinedHash(with: overrideHash)
        return issues
    }

    private func decodeOverrideModes<Mode: Decodable>(
        _ payload: ThemeJSONValue,
        as _: Mode.Type
    ) throws -> [String: Mode] {
        guard case .object = payload else { throw OverridePayloadError.expectedModeDictionary }
        let data = try JSONEncoder().encode(payload)
        return try JSONDecoder().decode([String: Mode].self, from: data)
    }
}

private enum OverridePayloadError: Error {
    case expectedModeDictionary
}
