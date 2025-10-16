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

import CoreGraphics
import Foundation

package func themeDecodingDescription(_ error: any Error) -> String {
    switch error {
    case let DecodingError.dataCorrupted(context):
        context.debugDescription
    case let DecodingError.keyNotFound(key, context):
        "missing key \(key.stringValue.debugDescription) at \(codingPath(context.codingPath))"
    case let DecodingError.typeMismatch(type, context):
        "expected \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case let DecodingError.valueNotFound(type, context):
        "missing \(type) at \(codingPath(context.codingPath)): \(context.debugDescription)"
    default:
        error.localizedDescription
    }
}

private func codingPath(_ codingPath: [any CodingKey]) -> String {
    let path = codingPath.map(\.stringValue).joined(separator: ".")
    return path.isEmpty ? "<root>" : path
}

/// A single validation problem in a decoded theme document.
package struct ThemeValidationIssue: Hashable, Sendable, CustomStringConvertible {
    package let path: String
    package let message: String

    package init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    package var description: String {
        "\(path): \(message)"
    }
}

/// The decoded representation of a design-system theme payload.
public struct RawTheme: Decodable, Identifiable, Hashable, Sendable {
    /// A logical identifier supplied by the theme producer.
    public let id: String

    package let defaults: RawDefaults
    package var colors: [String: RawColor]
    package var fonts: [String: RawFont]
    package var units: [String: RawUnit]

    /// Distinguishes separately decoded payloads even when their logical IDs match.
    package let instanceID: UUID
    /// Composes the dynamic override scopes applied to this value.
    package var overrideHash: Int

    private enum CodingKeys: String, CodingKey {
        case id, defaults, colors, fonts, units
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        defaults = try container.decode(RawDefaults.self, forKey: .defaults)
        colors = try container.decode([String: RawColor].self, forKey: .colors)
        fonts = try container.decode([String: RawFont].self, forKey: .fonts)
        units = try container.decode([String: RawUnit].self, forKey: .units)
        instanceID = UUID()
        overrideHash = 0

        let issues = schemaValidationIssues()
        guard issues.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: (["Theme validation failed:"] + issues.map { "• \($0.description)" })
                    .joined(separator: "\n")
            )
        }
    }

    package init(
        id: String,
        defaults: RawDefaults,
        colors: [String: RawColor],
        fonts: [String: RawFont],
        units: [String: RawUnit],
        instanceID: UUID = UUID(),
        overrideHash: Int = 0
    ) {
        self.id = id
        self.defaults = defaults
        self.colors = colors
        self.fonts = fonts
        self.units = units
        self.instanceID = instanceID
        self.overrideHash = overrideHash
    }

    package static let empty = Self(
        id: "<empty>",
        defaults: .init(font: "", primaryTextColor: "", secondaryTextColor: nil),
        colors: [:],
        fonts: [:],
        units: [:]
    )

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.instanceID == rhs.instanceID && lhs.overrideHash == rhs.overrideHash
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(instanceID)
        hasher.combine(overrideHash)
    }
}

package struct RawDefaults: Decodable, Hashable, Sendable {
    package let font: String
    package let primaryTextColor: String
    package let secondaryTextColor: String?

    package init(font: String, primaryTextColor: String, secondaryTextColor: String?) {
        self.font = font
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
    }
}

public struct RawColor: Decodable, Hashable, Sendable {
    package let name: String
    package let group: String
    package let description: String
    package var modes: [String: Mode]

    public struct Mode: Decodable, Hashable, Sendable {
        public let hex: String
        public let alpha: Double

        /// Creates a color mode with a six-digit `#RRGGBB` value and opacity.
        public init(hex: String, alpha: Double) {
            self.hex = hex
            self.alpha = alpha

            assert(
                hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
                "RawColor.Mode expected a six-digit #RRGGBB value"
            )
            assert(alpha.isFinite && (0...1).contains(alpha), "RawColor.Mode alpha must be between 0 and 1")
        }

        /// Creates a color mode from an eight-digit `#RRGGBBAA` value.
        /// Returns `nil` instead of substituting a color when the input is malformed.
        public init?(hexa: String) {
            let sanitized = hexa
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "#", with: "")

            var rgba: UInt64 = 0
            guard sanitized.count == 8,
                  Scanner(string: sanitized).scanHexInt64(&rgba)
            else {
                return nil
            }

            hex = "#" + sanitized.prefix(6)
            alpha = Double(rgba & 0xFF) / 255.0
        }
    }
}

public struct RawFont: Decodable, Hashable, Sendable {
    package let name: String
    package let group: String
    package let description: String
    package var modes: [String: Mode]

    package init(name: String, group: String, description: String, modes: [String: Mode]) {
        self.name = name
        self.group = group
        self.description = description
        self.modes = modes
    }

    public struct Mode: Decodable, Hashable, Sendable {
        public let fontSize: CGFloat
        public let fontName: String
        public let lineHeight: CGFloat
        public let letterSpacing: CGFloat
        public let textCase: TextCase

        /// Creates a new font mode with the given basline metrics, name, and case.
        public init(
            fontSize: CGFloat,
            fontName: String,
            lineHeight: CGFloat,
            letterSpacing: CGFloat,
            textCase: TextCase
        ) {
            self.fontSize = fontSize
            self.fontName = fontName
            self.lineHeight = lineHeight
            self.letterSpacing = letterSpacing
            self.textCase = textCase
        }

        public struct TextCase: Decodable, Hashable, RawRepresentable, Sendable {
            public var rawValue: String

            package static let original = Self(rawValue: "ORIGINAL")
            package static let upper = Self(rawValue: "UPPER")
            package static let lower = Self(rawValue: "LOWER")
            package static let validRawValues = Set([original.rawValue, upper.rawValue, lower.rawValue])

            public init(rawValue: String) {
                self.rawValue = rawValue
            }

            public init(from decoder: any Decoder) throws {
                let container = try decoder.singleValueContainer()
                let rawValue = try container.decode(String.self)
                switch rawValue {
                case "UPPER": self = .upper
                case "LOWER": self = .lower
                case "ORIGINAL": self = .original
                default:
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Unknown font text case \(rawValue.debugDescription); expected ORIGINAL, UPPER, or LOWER"
                    )
                }
            }
        }
    }
}

public struct RawUnit: Decodable, Hashable, Sendable {
    public typealias Mode = CGFloat

    package let name: String
    package let group: String
    package let description: String
    package var modes: [String: Mode]

}

package extension RawTheme {
    func schemaValidationIssues() -> [ThemeValidationIssue] {
        var issues: [ThemeValidationIssue] = []

        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "id", message: "theme id must not be empty"))
        }

        validateDefaultAlias(defaults.font, in: fonts, path: "defaults.font", issues: &issues)
        validateDefaultAlias(defaults.primaryTextColor, in: colors, path: "defaults.primaryTextColor", issues: &issues)
        if let secondaryTextColor = defaults.secondaryTextColor {
            validateDefaultAlias(secondaryTextColor, in: colors, path: "defaults.secondaryTextColor", issues: &issues)
        }

        for (token, color) in colors {
            validateTokenMetadata(
                token: token,
                name: color.name,
                group: color.group,
                modesAreEmpty: color.modes.isEmpty,
                kind: "colors",
                issues: &issues
            )
            for (mode, value) in color.modes {
                let path = "colors.\(token).modes.\(mode)"
                if mode.isEmpty {
                    issues.append(.init(path: path, message: "mode name must not be empty"))
                }
                if value.hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) == nil {
                    issues.append(.init(path: "\(path).hex", message: "expected a six-digit #RRGGBB value"))
                }
                if !value.alpha.isFinite || !(0...1).contains(value.alpha) {
                    issues.append(.init(path: "\(path).alpha", message: "expected a finite value between 0 and 1"))
                }
            }
        }

        for (token, font) in fonts {
            validateTokenMetadata(
                token: token,
                name: font.name,
                group: font.group,
                modesAreEmpty: font.modes.isEmpty,
                kind: "fonts",
                issues: &issues
            )
            for (mode, value) in font.modes {
                let path = "fonts.\(token).modes.\(mode)"
                if mode.isEmpty {
                    issues.append(.init(path: path, message: "mode name must not be empty"))
                }
                if value.fontName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    issues.append(.init(path: "\(path).fontName", message: "font name must not be empty"))
                }
                if !value.fontSize.isFinite || value.fontSize <= 0 {
                    issues.append(.init(path: "\(path).fontSize", message: "expected a finite value greater than zero"))
                }
                if !value.lineHeight.isFinite || value.lineHeight <= 0 {
                    issues.append(.init(path: "\(path).lineHeight", message: "expected a finite value greater than zero"))
                }
                if !value.letterSpacing.isFinite {
                    issues.append(.init(path: "\(path).letterSpacing", message: "expected a finite value"))
                }
                if !RawFont.Mode.TextCase.validRawValues.contains(value.textCase.rawValue) {
                    issues.append(.init(path: "\(path).textCase", message: "expected ORIGINAL, UPPER, or LOWER"))
                }
            }
        }

        for (token, unit) in units {
            validateTokenMetadata(
                token: token,
                name: unit.name,
                group: unit.group,
                modesAreEmpty: unit.modes.isEmpty,
                kind: "units",
                issues: &issues
            )
            for (mode, value) in unit.modes {
                let path = "units.\(token).modes.\(mode)"
                if mode.isEmpty {
                    issues.append(.init(path: path, message: "mode name must not be empty"))
                }
                if !value.isFinite {
                    issues.append(.init(path: path, message: "expected a finite numeric value"))
                }
            }
        }

        return issues.sortedForDiagnostics()
    }

    private func validateDefaultAlias<Value>(
        _ alias: String,
        in values: [String: Value],
        path: String,
        issues: inout [ThemeValidationIssue]
    ) {
        if alias.isEmpty {
            issues.append(.init(path: path, message: "default alias must not be empty"))
        } else if values[alias] == nil {
            issues.append(.init(path: path, message: "references missing token \(alias.debugDescription)"))
        }
    }

    private func validateTokenMetadata(
        token: String,
        name: String,
        group: String,
        modesAreEmpty: Bool,
        kind: String,
        issues: inout [ThemeValidationIssue]
    ) {
        let path = "\(kind).\(token)"
        if token.isEmpty {
            issues.append(.init(path: kind, message: "token key must not be empty"))
        }
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).name", message: "token name must not be empty"))
        }
        if group.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).group", message: "token group must not be empty"))
        }
        if modesAreEmpty {
            issues.append(.init(path: "\(path).modes", message: "token must define at least one mode"))
        }
    }
}

private extension Array where Element == ThemeValidationIssue {
    func sortedForDiagnostics() -> Self {
        sorted {
            if $0.path == $1.path {
                $0.message < $1.message
            } else {
                $0.path < $1.path
            }
        }
    }
}
