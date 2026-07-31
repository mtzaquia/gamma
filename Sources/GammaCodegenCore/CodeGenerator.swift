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

public enum GenerationTemplate: String, CaseIterable, Sendable {
    case tokens
    case assets

    public var defaultOutputFileName: String {
        switch self {
        case .tokens: "Theme+Tokens.generated.swift"
        case .assets: "Theme+Assets.generated.swift"
        }
    }
}

public struct GenerationOutput: Sendable {
    public let source: String
    public let warnings: [String]

    public init(source: String, warnings: [String] = []) {
        self.source = source
        self.warnings = warnings
    }
}

public enum CodeGenerationError: Error, LocalizedError, Equatable {
    case invalidIdentifier(source: String)
    case identifierCollision(scope: String, generated: String, sources: [String])
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidIdentifier(source):
            "Cannot form a Swift identifier from \(source.debugDescription)"
        case let .identifierCollision(scope, generated, sources):
            "Generated Swift identifier collision in \(scope): \(generated.debugDescription) from \(sources.map(\.debugDescription).joined(separator: ", "))"
        case let .invalidInput(message):
            message
        }
    }
}

public enum GammaCodeGenerator {
    public static func generate(
        inputURL: URL,
        template: GenerationTemplate
    ) throws -> GenerationOutput {
        try generate(inputURLs: [inputURL], template: template)
    }

    /// Generates one declaration surface from every matching input in a target.
    /// Multiple themes must expose the same token contract; this keeps theme
    /// variants from drifting away from the aliases compiled into the app.
    public static func generate(
        inputURLs: [URL],
        template: GenerationTemplate
    ) throws -> GenerationOutput {
        let inputURLs = Array(Set(inputURLs.map(\.standardizedFileURL))).sorted { $0.path < $1.path }
        guard !inputURLs.isEmpty else {
            throw CodeGenerationError.invalidInput("At least one input is required.")
        }

        switch template {
        case .tokens:
            guard inputURLs.allSatisfy({ !$0.pathExtension.caseInsensitiveCompare("xcassets").isOrderedSame }) else {
                throw CodeGenerationError.invalidInput(
                    "The tokens template requires a JSON theme input; .xcassets inputs support assets only."
                )
            }
            let documents = try inputURLs.map { url in
                _ = try decodeTheme(at: url)
                return (url: url, document: try decodeDocument(at: url))
            }
            try validateSharedTokenContract(documents)
            return GenerationOutput(source: try renderTokens(documents))

        case .assets:
            let catalogue = try mergeAssetInputs(inputURLs)
            return GenerationOutput(
                source: try renderAssets(
                    assets: catalogue.assets,
                    illustrations: catalogue.illustrations
                ),
                warnings: catalogue.warnings
            )
        }
    }
}

private extension GammaCodeGenerator {
    struct ThemeDocument: Decodable {
        var colors: [String: Token] = [:]
        var fonts: [String: Token] = [:]
        var units: [String: Token] = [:]
        var assets: [String: Asset] = [:]
        var illustrations: [String: Asset] = [:]
        var extensions: [String: [String: ExtensionToken]] = [:]

        private enum CodingKeys: String, CodingKey {
            case colors, fonts, units, assets, illustrations
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            colors = try container.decodeIfPresent([String: Token].self, forKey: .colors) ?? [:]
            fonts = try container.decodeIfPresent([String: Token].self, forKey: .fonts) ?? [:]
            units = try container.decodeIfPresent([String: Token].self, forKey: .units) ?? [:]
            assets = try container.decodeIfPresent([String: Asset].self, forKey: .assets) ?? [:]
            illustrations = try container.decodeIfPresent([String: Asset].self, forKey: .illustrations) ?? [:]

            let rootContainer = try decoder.container(keyedBy: DocumentCodingKey.self)
            for key in rootContainer.allKeys
            where !Self.reservedKeys.contains(key.stringValue) {
                let tokens = try rootContainer.decode([String: ExtensionToken].self, forKey: key)
                guard !tokens.isEmpty else { continue }
                if tokens.keys.contains("") {
                    throw DecodingError.dataCorruptedError(
                        forKey: key,
                        in: rootContainer,
                        debugDescription: "Extension token keys must not be empty"
                    )
                }
                extensions[key.stringValue] = tokens
            }
        }

        private static let reservedKeys = Set([
            "id", "defaults", "colors", "fonts", "units", "assets", "illustrations",
        ])
    }

    struct TokenContract {
        struct UnitAlias: Hashable {
            let key: String
            let group: String
        }

        let colors: Set<String>
        let fonts: Set<String>
        let units: Set<UnitAlias>
        let extensions: [String: Set<String>]

        init(document: ThemeDocument) {
            colors = Set(document.colors.keys)
            fonts = Set(document.fonts.keys)
            units = Set(document.units.map { key, token in
                UnitAlias(key: key, group: token.group ?? "")
            })
            extensions = document.extensions.mapValues { Set($0.keys) }
        }

        func differences(from reference: Self) -> [String] {
            var differences: [String] = []
            differences.append(contentsOf: setDifferences(kind: "color", values: colors, reference: reference.colors))
            differences.append(contentsOf: setDifferences(kind: "font", values: fonts, reference: reference.fonts))

            let unitKeys = Set(units.map(\.key))
            let referenceUnitKeys = Set(reference.units.map(\.key))
            differences.append(contentsOf: setDifferences(
                kind: "unit",
                values: unitKeys,
                reference: referenceUnitKeys
            ))

            let groups = Dictionary(uniqueKeysWithValues: units.map { ($0.key, $0.group) })
            let referenceGroups = Dictionary(uniqueKeysWithValues: reference.units.map { ($0.key, $0.group) })
            for key in unitKeys.intersection(referenceUnitKeys).sorted()
            where groups[key] != referenceGroups[key] {
                differences.append(
                    "unit \(key.debugDescription) moved from group "
                        + "\(referenceGroups[key, default: ""].debugDescription) to "
                        + groups[key, default: ""].debugDescription
                )
            }

            differences.append(contentsOf: setDifferences(
                kind: "extension family",
                values: Set(extensions.keys),
                reference: Set(reference.extensions.keys)
            ))
            for family in Set(extensions.keys).intersection(reference.extensions.keys).sorted() {
                differences.append(contentsOf: setDifferences(
                    kind: "extension \(family.debugDescription)",
                    values: extensions[family, default: []],
                    reference: reference.extensions[family, default: []]
                ))
            }
            return differences
        }

        private func setDifferences(
            kind: String,
            values: Set<String>,
            reference: Set<String>
        ) -> [String] {
            var result: [String] = []
            let missing = reference.subtracting(values).sorted()
            let extra = values.subtracting(reference).sorted()
            if !missing.isEmpty {
                result.append("missing \(kind) aliases: \(missing.map(\.debugDescription).joined(separator: ", "))")
            }
            if !extra.isEmpty {
                result.append("extra \(kind) aliases: \(extra.map(\.debugDescription).joined(separator: ", "))")
            }
            return result
        }
    }

    struct Token: Decodable {
        let group: String?
        let description: String?
    }

    struct ExtensionToken: Decodable {
        let name: String
        let group: String
        let description: String?
        let modes: [String: ThemeJSONValue]

        private enum CodingKeys: String, CodingKey {
            case name, group, description, modes
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            group = try container.decode(String.self, forKey: .group)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            modes = try container.decode([String: ThemeJSONValue].self, forKey: .modes)

            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw DecodingError.dataCorruptedError(
                    forKey: .name,
                    in: container,
                    debugDescription: "Extension token names must not be empty"
                )
            }
            if modes.isEmpty {
                throw DecodingError.dataCorruptedError(
                    forKey: .modes,
                    in: container,
                    debugDescription: "Extension tokens must define at least one mode"
                )
            }
            if modes.keys.contains("") {
                throw DecodingError.dataCorruptedError(
                    forKey: .modes,
                    in: container,
                    debugDescription: "Extension mode names must not be empty"
                )
            }
        }
    }

    struct Asset: Decodable {
        let path: String?
    }

    struct AssetCatalogue {
        let assets: [String: Asset]
        let illustrations: [String: Asset]
        let warnings: [String]
    }

    static func decodeDocument(at url: URL) throws -> ThemeDocument {
        do {
            return try JSONDecoder().decode(ThemeDocument.self, from: Data(contentsOf: url))
        } catch {
            throw CodeGenerationError.invalidInput(
                "Could not parse theme JSON at \(url.path): \(themeDecodingDescription(error))"
            )
        }
    }

    static func decodeTheme(at url: URL) throws -> RawTheme {
        do {
            return try JSONDecoder().decode(RawTheme.self, from: Data(contentsOf: url))
        } catch {
            throw CodeGenerationError.invalidInput(
                "Theme schema validation failed at \(url.path): \(themeDecodingDescription(error))"
            )
        }
    }

    static func validateSharedTokenContract(
        _ documents: [(url: URL, document: ThemeDocument)]
    ) throws {
        guard let reference = documents.first else { return }
        let referenceContract = TokenContract(document: reference.document)
        var diagnostics: [String] = []

        for candidate in documents.dropFirst() {
            let differences = TokenContract(document: candidate.document)
                .differences(from: referenceContract)
            guard !differences.isEmpty else { continue }
            diagnostics.append("\(candidate.url.path) differs from \(reference.url.path):")
            diagnostics.append(contentsOf: differences.map { "  - \($0)" })
        }

        guard diagnostics.isEmpty else {
            throw CodeGenerationError.invalidInput(
                ([
                    "Theme alias contract drift detected.",
                    "Every *.theme.json file in one target must define the same color, font, grouped unit, and extension aliases.",
                ] + diagnostics).joined(separator: "\n")
            )
        }
    }

    static func mergeAssetInputs(_ inputURLs: [URL]) throws -> AssetCatalogue {
        var assets: [String: Asset] = [:]
        var illustrations: [String: Asset] = [:]
        var assetPaths: [String: [String]] = [:]
        var illustrationPaths: [String: [String]] = [:]
        var warnings: [String] = []

        for inputURL in inputURLs {
            let input: AssetCatalogue
            if inputURL.pathExtension.caseInsensitiveCompare("xcassets").isOrderedSame {
                input = try crawlAssetCatalogue(at: inputURL)
            } else {
                let document = try decodeDocument(at: inputURL)
                input = AssetCatalogue(
                    assets: document.assets,
                    illustrations: document.illustrations,
                    warnings: []
                )
            }

            warnings.append(contentsOf: input.warnings)
            for (name, asset) in input.assets.sorted(by: { $0.key < $1.key }) {
                assets[name] = asset
                assetPaths[name, default: []].append(asset.path ?? "\(inputURL.path)#assets.\(name)")
            }
            for (name, illustration) in input.illustrations.sorted(by: { $0.key < $1.key }) {
                illustrations[name] = illustration
                illustrationPaths[name, default: []].append(
                    illustration.path ?? "\(inputURL.path)#illustrations.\(name)"
                )
            }
        }

        warnings.append(contentsOf: duplicateWarnings(pathsByBasename: assetPaths, kind: "asset"))
        warnings.append(contentsOf: duplicateWarnings(pathsByBasename: illustrationPaths, kind: "illustration"))
        return AssetCatalogue(
            assets: assets,
            illustrations: illustrations,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    static func crawlAssetCatalogue(at rootURL: URL) throws -> AssetCatalogue {
        let fileManager = FileManager.default
        guard rootURL.pathExtension.caseInsensitiveCompare("xcassets").isOrderedSame,
              fileManager.fileExists(atPath: rootURL.path)
        else {
            throw CodeGenerationError.invalidInput("Path is not an .xcassets directory: \(rootURL.path)")
        }

        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw CodeGenerationError.invalidInput("Could not enumerate asset catalogue: \(rootURL.path)")
        }

        let imageSets = enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension.caseInsensitiveCompare("imageset").isOrderedSame }
            .filter { url in
                relativeComponents(of: url, under: rootURL)
                    .allSatisfy { !$0.hasPrefix("!") }
            }
            .sorted { $0.path < $1.path }

        var assets: [String: Asset] = [:]
        var illustrations: [String: Asset] = [:]
        var assetPaths: [String: [String]] = [:]
        var illustrationPaths: [String: [String]] = [:]

        for imageSet in imageSets {
            let basename = imageSet.deletingPathExtension().lastPathComponent
            let components = relativeComponents(of: imageSet, under: rootURL)
            let isIllustration = components.contains {
                ["illustration", "illustrations"].contains($0.lowercased())
            }

            if isIllustration {
                appendAsset(
                    basename: basename,
                    path: imageSet.path,
                    assets: &illustrations,
                    paths: &illustrationPaths
                )
            } else {
                appendAsset(
                    basename: basename,
                    path: imageSet.path,
                    assets: &assets,
                    paths: &assetPaths
                )
            }
        }

        let warnings = duplicateWarnings(pathsByBasename: assetPaths, kind: "asset")
            + duplicateWarnings(pathsByBasename: illustrationPaths, kind: "illustration")
        return AssetCatalogue(assets: assets, illustrations: illustrations, warnings: warnings)
    }

    static func appendAsset(
        basename: String,
        path: String,
        assets: inout [String: Asset],
        paths: inout [String: [String]]
    ) {
        assets[basename] = Asset(path: path)
        paths[basename, default: []].append(path)
    }

    static func duplicateWarnings(
        pathsByBasename: [String: [String]],
        kind: String
    ) -> [String] {
        pathsByBasename
            .filter { $0.value.count > 1 }
            .sorted { $0.key < $1.key }
            .map { basename, paths in
                let pathList = paths.map { "  - \($0)" }.joined(separator: "\n")
                return """
                warning: duplicate \(kind) basename \(basename.debugDescription); keeping the last catalogue entry:
                \(pathList)
                """
            }
    }

    static func relativeComponents(of url: URL, under rootURL: URL) -> [String] {
        Array(url.standardizedFileURL.pathComponents.dropFirst(rootURL.standardizedFileURL.pathComponents.count))
    }

    static func renderTokens(
        _ documents: [(url: URL, document: ThemeDocument)]
    ) throws -> String {
        let document = documents[0].document
        try validateThemeResourceCollisions(documents.map(\.url))
        try validateCollisions(scope: "color aliases", sources: Array(document.colors.keys), transform: tokenAccessor)
        try validateCollisions(scope: "font aliases", sources: Array(document.fonts.keys), transform: tokenAccessor)

        let groupedUnits = Dictionary(grouping: document.units) { $0.value.group ?? "" }
            .filter { !$0.key.isEmpty }
        try validateThemeTypeCollisions(
            unitGroups: Array(groupedUnits.keys),
            extensionFamilies: Array(document.extensions.keys)
        )
        for (group, units) in groupedUnits {
            try validateCollisions(
                scope: "unit aliases in group \(group.debugDescription)",
                sources: units.map(\.key),
                transform: tokenAccessor
            )
        }
        for (family, tokens) in document.extensions {
            try validateCollisions(
                scope: "extension aliases in family \(family.debugDescription)",
                sources: Array(tokens.keys),
                transform: tokenAccessor
            )
        }

        var writer = SourceWriter()
        writer.line("// swiftlint:disable:next file_header")
        writer.line("// periphery:ignore:all")
        writer.line("#if canImport(Gamma)")
        writer.blankLine()
        writer.line("import Gamma")
        writer.blankLine()
        writer.line("// MARK: - Theme resources")
        writer.blankLine()
        try writer.block("public extension ThemeResource") { writer in
            for url in documents.map(\.url).sorted(by: { $0.path < $1.path }) {
                let stem = themeResourceStem(url)
                writer.line(
                    "static let \(try tokenAccessor(stem)) = Self(fileName: \(swiftStringLiteral(url.lastPathComponent)))"
                )
            }
        }
        writer.blankLine()
        writer.line("// MARK: - Theme.ColorAlias")
        writer.blankLine()
        try writer.block("public extension Theme.ColorAlias") { writer in
            for (key, token) in document.colors.sorted(by: { $0.key < $1.key }) {
                writer.docComment(description: token.description, key: key)
                writer.line("static let \(try tokenAccessor(key)) = Self(rawValue: \(swiftStringLiteral(key)))")
            }
        }
        writer.blankLine()
        writer.line("// MARK: - Theme.FontAlias")
        writer.blankLine()
        try writer.block("public extension Theme.FontAlias") { writer in
            for (key, token) in document.fonts.sorted(by: { $0.key < $1.key }) {
                writer.docComment(description: token.description, key: key)
                writer.line("static let \(try tokenAccessor(key)) = Self(rawValue: \(swiftStringLiteral(key)))")
            }
        }

        for group in groupedUnits.keys.sorted() {
            let typeName = try groupAliasName(group)
            writer.blankLine()
            writer.line("// MARK: - Theme.\(typeName)")
            writer.blankLine()
            writer.block("public extension Theme") { writer in
                writer.block("struct \(typeName): @MainActor UnitAlias") { writer in
                    writer.line("public var rawValue: String")
                    writer.block("public init(rawValue: String)") { writer in
                        writer.line("self.rawValue = rawValue")
                    }
                }
            }
            writer.blankLine()
            try writer.block("public extension UnitAlias where Self == Theme.\(typeName)") { writer in
                for (key, token) in groupedUnits[group, default: []].sorted(by: { $0.key < $1.key }) {
                    writer.docComment(description: token.description, key: key)
                    writer.line("static var \(try tokenAccessor(key)): Self { Self(rawValue: \(swiftStringLiteral(key))) }")
                }
            }
        }

        for family in document.extensions.keys.sorted() {
            let familyType = try extensionFamilyName(family)
            let aliasType = try groupAliasName(family)
            writer.blankLine()
            writer.line("// MARK: - Theme.\(aliasType)")
            writer.blankLine()
            writer.block("public extension Theme") { writer in
                writer.line("/// Identifies custom tokens under the \(swiftStringLiteral(family)) theme key.")
                writer.block("nonisolated enum \(familyType): ThemeExtensionKey") { writer in
                    writer.line("/// The top-level JSON key for this token family.")
                    writer.line("public static let key = \(swiftStringLiteral(family))")
                }
                writer.blankLine()
                writer.line("/// A typed alias for tokens in the \(swiftStringLiteral(family)) family.")
                writer.line("typealias \(aliasType) = ThemeExtensionAlias<\(familyType)>")
            }
            writer.blankLine()
            try writer.block(
                "public extension ThemeExtensionAlias where Extension == Theme.\(familyType)"
            ) { writer in
                for (key, token) in document.extensions[family, default: [:]].sorted(by: { $0.key < $1.key }) {
                    writer.docComment(description: token.description, key: key)
                    writer.line(
                        "static var \(try tokenAccessor(key)): Self { Self(rawValue: \(swiftStringLiteral(key))) }"
                    )
                }
            }
        }

        writer.blankLine()
        writer.line("#endif")
        return writer.source
    }

    static func validateThemeResourceCollisions(_ urls: [URL]) throws {
        var generated: [String: [String]] = [:]
        for url in urls {
            generated[try tokenAccessor(themeResourceStem(url)), default: []].append(url.path)
        }
        if let collision = generated
            .filter({ $0.value.count > 1 })
            .sorted(by: { $0.key < $1.key })
            .first {
            throw CodeGenerationError.identifierCollision(
                scope: "theme resources",
                generated: collision.key,
                sources: collision.value.sorted()
            )
        }
    }

    static func validateThemeTypeCollisions(
        unitGroups: [String],
        extensionFamilies: [String]
    ) throws {
        var generated: [String: [String]] = [
            "AssetAlias": ["built-in Theme.AssetAlias"],
            "ColorAlias": ["built-in Theme.ColorAlias"],
            "FontAlias": ["built-in Theme.FontAlias"],
            "IconAlias": ["built-in Theme.IconAlias"],
        ]

        for group in unitGroups.sorted() {
            generated[try groupAliasName(group), default: []]
                .append("unit group \(group.debugDescription)")
        }
        for family in extensionFamilies.sorted() {
            generated[try extensionFamilyName(family), default: []]
                .append("extension family \(family.debugDescription)")
            generated[try groupAliasName(family), default: []]
                .append("extension alias for \(family.debugDescription)")
        }

        if let collision = generated
            .filter({ $0.value.count > 1 })
            .sorted(by: { $0.key < $1.key })
            .first {
            throw CodeGenerationError.identifierCollision(
                scope: "Theme nested types",
                generated: collision.key,
                sources: collision.value
            )
        }
    }

    static func themeResourceStem(_ url: URL) -> String {
        let filename = url.lastPathComponent
        return filename.hasSuffix(".theme.json")
            ? String(filename.dropLast(".theme.json".count))
            : url.deletingPathExtension().lastPathComponent
    }

    static func renderAssets(
        assets: [String: Asset],
        illustrations: [String: Asset]
    ) throws -> String {
        try validateCollisions(scope: "icon asset aliases", sources: Array(assets.keys), transform: tokenAccessor)
        try validateCollisions(
            scope: "illustration asset aliases",
            sources: Array(illustrations.keys),
            transform: tokenAccessor
        )

        var writer = SourceWriter()
        writer.line("// swiftlint:disable:next file_header")
        writer.line("// periphery:ignore:all")
        writer.line("#if canImport(Gamma)")
        writer.blankLine()
        writer.line("import Gamma")
        writer.blankLine()
        writer.line("// MARK: - Theme Assets")
        try writer.block("public extension Theme.AssetAlias where Asset == IconAsset") { writer in
            for key in assets.keys.sorted() {
                writer.line("static let \(try tokenAccessor(key)) = Self(rawValue: \(swiftStringLiteral(key)))")
            }
        }

        if !illustrations.isEmpty {
            writer.blankLine()
            writer.line("// MARK: - Theme Illustrations")
            try writer.block("public extension Theme.AssetAlias where Asset == IllustrationAsset") { writer in
                for key in illustrations.keys.sorted() {
                    writer.line("static let \(try tokenAccessor(key)) = Self(rawValue: \(swiftStringLiteral(key)))")
                }
            }
        }

        writer.blankLine()
        writer.line("#endif")
        return writer.source
    }

    static func validateCollisions(
        scope: String,
        sources: [String],
        transform: (String) throws -> String
    ) throws {
        var generated: [String: [String]] = [:]
        for source in sources.sorted() {
            generated[try transform(source), default: []].append(source)
        }

        if let collision = generated
            .filter({ $0.value.count > 1 })
            .sorted(by: { $0.key < $1.key })
            .first {
            throw CodeGenerationError.identifierCollision(
                scope: scope,
                generated: collision.key,
                sources: collision.value
            )
        }
    }

    static func tokenAccessor(_ source: String) throws -> String {
        escapeReservedKeyword(lowerFirst(try swiftIdentifier(source)))
    }

    static func groupAliasName(_ source: String) throws -> String {
        escapeReservedKeyword(upperFirst(try swiftIdentifier(source)) + "Alias")
    }

    static func extensionFamilyName(_ source: String) throws -> String {
        escapeReservedKeyword(upperFirst(try swiftIdentifier(source)))
    }

    static func swiftIdentifier(_ source: String) throws -> String {
        var parts: [String] = []
        var current = ""

        for scalar in source.unicodeScalars {
            if scalar.isASCIIAlphaNumeric {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            parts.append(current)
        }

        guard let first = parts.first else {
            throw CodeGenerationError.invalidIdentifier(source: source)
        }

        var identifier = first + parts.dropFirst().map(upperFirst).joined()
        if identifier.first?.isNumber == true {
            identifier = "_" + identifier
        }
        return identifier
    }

    static func upperFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    static func lowerFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    static func escapeReservedKeyword(_ value: String) -> String {
        swiftReservedKeywords.contains(value) ? "`\(value)`" : value
    }

    static func swiftStringLiteral(_ value: String) -> String {
        let escaped = value.unicodeScalars.map { scalar -> String in
            switch scalar.value {
            case 0: "\\0"
            case 9: "\\t"
            case 10: "\\n"
            case 13: "\\r"
            case 34: "\\\""
            case 92: "\\\\"
            case 0..<32, 127: "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
            default: String(scalar)
            }
        }.joined()
        return "\"\(escaped)\""
    }

    static let swiftReservedKeywords: Set<String> = [
        "Any", "Protocol", "Self", "Type", "actor", "any", "as", "associatedtype", "associativity",
        "async", "await", "borrow", "borrowing", "break", "case", "catch", "class", "consume",
        "consuming", "continue", "convenience", "copy", "default", "defer", "deinit", "didSet",
        "distributed", "do", "dynamic", "each", "else", "enum", "extension", "fallthrough", "false",
        "fileprivate", "final", "for", "func", "get", "guard", "if", "import", "in", "indirect",
        "infix", "init", "inout", "internal", "is", "isolated", "lazy", "left", "let", "macro",
        "mutating", "nil", "none", "nonisolated", "nonmutating", "open", "operator", "optional",
        "override", "package", "postfix", "precedence", "precedencegroup", "prefix", "private", "protocol",
        "public", "repeat", "required", "rethrows", "return", "right", "self", "sending", "set", "some",
        "static", "struct", "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias",
        "unowned", "var", "weak", "where", "while", "willSet",
    ]
}

private struct SourceWriter {
    private var lines: [String] = []
    private var indentation = 0

    var source: String {
        lines.joined(separator: "\n") + "\n"
    }

    mutating func line(_ value: String) {
        lines.append(String(repeating: "    ", count: indentation) + value)
    }

    mutating func blankLine() {
        lines.append("")
    }

    mutating func block(
        _ declaration: String,
        body: (inout SourceWriter) throws -> Void
    ) rethrows {
        line(declaration + " {")
        indentation += 1
        try body(&self)
        indentation -= 1
        line("}")
    }

    mutating func docComment(description: String?, key: String) {
        guard let description, !description.isEmpty else { return }
        let text = "\(description) (\(key))"
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "")
        for lineValue in text.split(separator: "\n", omittingEmptySubsequences: false) {
            line("/// \(sanitizeComment(String(lineValue)))")
        }
    }

    private func sanitizeComment(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0..<9, 11..<32, 127:
                "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
            default:
                String(scalar)
            }
        }.joined()
    }
}

private struct DocumentCodingKey: CodingKey {
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

private extension Unicode.Scalar {
    var isASCIIAlphaNumeric: Bool {
        switch value {
        case 48...57, 65...90, 97...122: true
        default: false
        }
    }
}

private extension ComparisonResult {
    var isOrderedSame: Bool { self == .orderedSame }
}
