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
import Testing
@testable import GammaCodegenCore

@Suite("Gamma code generator")
struct CodeGeneratorTests {
    @Test("Generates valid identifiers and escaped string literals")
    func identifiersAndStringLiterals() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            try writeTheme(
                colors: ["1x-foo", "icon@2x", "class", "get", "quote\"and\\slash"],
                to: input
            )

            let source = try GammaCodeGenerator.generate(
                inputURL: input,
                template: .tokens
            ).source

            #expect(source.contains("static var test1xFoo"))
            #expect(source.contains("static var testIcon2x"))
            #expect(source.contains("static var testClass"))
            #expect(source.contains("static var testGet"))
            #expect(source.contains(#"Self(rawValue: "test/quote\"and\\slash")"#))
        }
    }

    @Test("Fails when distinct tokens generate the same Swift name")
    func identifierCollision() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            try writeTheme(colors: ["foo-bar", "foo_bar"], to: input)

            #expect(throws: CodeGenerationError.self) {
                try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
            }
        }
    }

    @Test("Duplicate asset basenames fail with every conflicting path")
    func duplicateAssetsFail() throws {
        try withTemporaryDirectory { directory in
            let catalogue = directory.appendingPathComponent("Assets.xcassets", isDirectory: true)
            let first = catalogue.appendingPathComponent("Actions/close.imageset", isDirectory: true)
            let second = catalogue.appendingPathComponent("Navigation/close.imageset", isDirectory: true)
            let third = catalogue.appendingPathComponent("Toolbar/close.imageset", isDirectory: true)
            try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: third, withIntermediateDirectories: true)

            do {
                _ = try GammaCodeGenerator.generate(
                    inputURL: catalogue,
                    template: .assets
                )
                Issue.record("Expected duplicate basenames to fail generation")
            } catch {
                let message = error.localizedDescription
                #expect(message.contains("Duplicate asset basename \"close\""))
                #expect(message.contains(first.path))
                #expect(message.contains(second.path))
                #expect(message.contains(third.path))
            }
        }
    }

    @Test("Asset identifier collisions fail after catalogue discovery")
    func assetIdentifierCollision() throws {
        try withTemporaryDirectory { directory in
            let catalogue = directory.appendingPathComponent("Assets.xcassets", isDirectory: true)
            try FileManager.default.createDirectory(
                at: catalogue.appendingPathComponent("foo-bar.imageset", isDirectory: true),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: catalogue.appendingPathComponent("foo_bar.imageset", isDirectory: true),
                withIntermediateDirectories: true
            )

            #expect(throws: CodeGenerationError.self) {
                try GammaCodeGenerator.generate(inputURL: catalogue, template: .assets)
            }
        }
    }

    @Test("Unit groups and aliases are deterministic")
    func unitGenerationIsDeterministic() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: [
                    "spacing/large": token(group: "spacing"),
                    "spacing/small": token(group: "spacing"),
                    "radius/card": token(group: "radius"),
                ]
            )
            try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]).write(to: input)

            let first = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source
            let second = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(first == second)
            #expect(first.contains("typealias SpacingAlias = Theme.Alias<SpacingGroup>"))
            #expect(first.contains("static var spacingSmall"))
            #expect(first.contains("typealias RadiusAlias = Theme.Alias<RadiusGroup>"))
        }
    }

    @Test("Unit group type names remain valid when the group is a keyword")
    func keywordUnitGroup() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: ["self/default": token(group: "self")]
            )
            try JSONSerialization.data(withJSONObject: document).write(to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("nonisolated enum SelfGroup: ThemeTokenGroup"))
            #expect(source.contains("typealias SelfAlias = Theme.Alias<SelfGroup>"))
            #expect(source.contains("Scope == Theme.Units.SelfGroup"))
        }
    }

    @Test("Generation accepts empty token groups")
    func emptyTokenGroups() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            var document = validThemeDocument(
                units: ["unit": token(group: "")],
                colorGroup: "",
                fontGroup: ""
            )
            var defaults = document["defaults"] as! [String: String]
            defaults["font"] = "body"
            document["defaults"] = defaults
            var fonts = document["fonts"] as! [String: Any]
            fonts["body"] = fonts.removeValue(forKey: "default")
            document["fonts"] = fonts
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(!source.contains("UngroupedAlias"))
            #expect(!source.contains("UngroupedGroup"))
            #expect(source.contains("Scope == Theme.Colors"))
            #expect(source.contains("Scope == Theme.Fonts"))
            #expect(source.contains("Scope == Theme.Units"))
            #expect(source.contains(#"static var body: Self { Self(rawValue: "body") }"#))
            #expect(source.contains(#"static var unit: Self { Self(rawValue: "unit") }"#))
        }
    }

    @Test("Full-key accessor collisions fail across groups in one family")
    func fullKeyAccessorCollisionsAcrossGroups() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(units: [
                "a-b/c": token(group: "a-b"),
                "a/b-c": token(group: "a"),
            ])
            try write(document, to: input)

            #expect(throws: CodeGenerationError.self) {
                try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
            }
        }
    }

    @Test("Empty and named groups have distinct scopes")
    func emptyAndNamedGroups() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(units: [
                "empty": token(group: ""),
                "general/named": token(group: "general"),
            ])
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("Scope == Theme.Units"))
            #expect(source.contains("typealias GeneralAlias = Theme.Alias<GeneralGroup>"))
            #expect(source.contains("Scope == Theme.Units.GeneralGroup"))
            #expect(!source.contains("Ungrouped"))
        }
    }

    @Test("Custom token families generate markers, aliases, and accessors")
    func customTokenFamilyGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": [
                    "brand/hero": token(group: "brand"),
                    "brand/something": token(group: "brand"),
                ],
            ])
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("nonisolated enum Gradients: Sendable"))
            #expect(source.contains(#"nonisolated public static let key = "gradients""#))
            #expect(source.contains("nonisolated enum BrandGroup: ThemeTokenGroup"))
            #expect(source.contains("typealias BrandAlias = Theme.Alias<BrandGroup>"))
            #expect(source.contains("Scope == Theme.Gradients.BrandGroup"))
            #expect(source.contains(#"static var brandHero: Self { Self(rawValue: "brand/hero") }"#))
            #expect(source.contains(#"static var brandSomething: Self { Self(rawValue: "brand/something") }"#))
        }
    }

    @Test("Full-key accessor names may repeat across custom token families")
    func customAccessorNamesAreScopedByFamily() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": ["brand/shared": token(group: "brand")],
                "shadows": ["brand/shared": token(group: "brand")],
            ])
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.components(separatedBy: "static var brandShared").count - 1 == 2)
            #expect(source.contains("Scope == Theme.Gradients.BrandGroup"))
            #expect(source.contains("Scope == Theme.Shadows.BrandGroup"))
        }
    }

    @Test("Group names may repeat across token families")
    func groupNamesAreScopedByFamily() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: ["gradients/default": token(group: "gradients")],
                extensions: ["gradients": ["brand/hero": token(group: "brand")]]
            )
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("Theme.Units.GradientsAlias"))
            #expect(source.contains("Theme.Gradients.BrandAlias"))
        }
    }

    @Test("Custom family markers cannot collide with built-in families")
    func customFamilyMarkerCollision() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "Colors": ["brand/hero": token(group: "brand")],
            ])
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected built-in Theme type collision to fail generation")
            } catch {
                #expect(error.localizedDescription.contains("Colors"))
                #expect(error.localizedDescription.contains("built-in Theme.Colors"))
                #expect(error.localizedDescription.contains("extension family"))
            }
        }
    }

    @Test("Malformed custom token metadata fails generation")
    func malformedCustomTokenFailsGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": [
                    "brand/hero": [
                        "name": "",
                        "group": "brand",
                        "modes": ["light": [:]],
                    ],
                ],
            ])
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected custom token validation to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(input.path))
                #expect(error.localizedDescription.contains("gradients.brand/hero.name"))
            }
        }
    }

    @Test("Generation rejects a malformed theme through the shared schema")
    func malformedThemeFailsGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("Broken.theme.json")
            var document = validThemeDocument()
            var colors = document["colors"] as! [String: Any]
            var color = colors["test/default"] as! [String: Any]
            var modes = color["modes"] as! [String: Any]
            modes["light"] = ["hex": "broken", "alpha": 1]
            color["modes"] = modes
            colors["test/default"] = color
            document["colors"] = colors
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected schema validation to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(input.path))
                #expect(error.localizedDescription.contains("colors.test/default.modes.light.hex"))
            }
        }
    }

    @Test("Multiple theme variants generate one shared alias surface")
    func matchingThemeVariantsGenerateTogether() throws {
        try withTemporaryDirectory { directory in
            let first = directory.appendingPathComponent("Day.theme.json")
            let second = directory.appendingPathComponent("Night.theme.json")
            try write(validThemeDocument(id: "day"), to: first)
            try write(validThemeDocument(id: "night"), to: second)

            let output = try GammaCodeGenerator.generate(
                inputURLs: [second, first],
                template: .tokens
            )

            #expect(output.source.components(separatedBy: #"Self(rawValue: "test/default")"#).count - 1 == 1)
            #expect(output.source.contains("static let day = Self(fileName: \"Day.theme.json\")"))
            #expect(output.source.contains("static let night = Self(fileName: \"Night.theme.json\")"))
        }
    }

    @Test("Multiple theme variants fail with both paths when aliases drift")
    func driftingThemeVariantsFailTogether() throws {
        try withTemporaryDirectory { directory in
            let first = directory.appendingPathComponent("BrandA.theme.json")
            let second = directory.appendingPathComponent("BrandB.theme.json")
            try write(validThemeDocument(id: "brand-a"), to: first)
            var drifted = validThemeDocument(id: "brand-b")
            var colors = drifted["colors"] as! [String: Any]
            colors["test/brand-only"] = colorToken()
            drifted["colors"] = colors
            try write(drifted, to: second)

            do {
                _ = try GammaCodeGenerator.generate(
                    inputURLs: [first, second],
                    template: .tokens
                )
                Issue.record("Expected alias contract drift to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(first.path))
                #expect(error.localizedDescription.contains(second.path))
                #expect(error.localizedDescription.contains("test/brand-only"))
            }
        }
    }

    @Test("Token key prefix must match its group exactly")
    func tokenKeyPrefixMatchesGroup() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("Brand.theme.json")
            var document = validThemeDocument()
            var colors = document["colors"] as! [String: Any]
            var color = colors["test/default"] as! [String: Any]
            color["group"] = "surface"
            colors["test/default"] = color
            document["colors"] = colors
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected mismatched token group to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(input.path))
                #expect(error.localizedDescription.contains("test/default.group"))
                #expect(error.localizedDescription.contains(#"expected token key "surface"/<name>"#))
            }
        }
    }

    @Test("Multiple theme variants fail when custom extension aliases drift")
    func driftingCustomExtensionsFailTogether() throws {
        try withTemporaryDirectory { directory in
            let first = directory.appendingPathComponent("Day.theme.json")
            let second = directory.appendingPathComponent("Night.theme.json")
            try write(validThemeDocument(
                id: "day",
                extensions: ["gradients": ["brand/hero": token(group: "brand")]]
            ), to: first)
            try write(validThemeDocument(
                id: "night",
                extensions: ["gradients": [
                    "brand/hero": token(group: "brand"),
                    "brand/night-only": token(group: "brand"),
                ]]
            ), to: second)

            do {
                _ = try GammaCodeGenerator.generate(
                    inputURLs: [first, second],
                    template: .tokens
                )
                Issue.record("Expected custom extension contract drift to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(first.path))
                #expect(error.localizedDescription.contains(second.path))
                #expect(error.localizedDescription.contains("brand/night-only"))
                #expect(error.localizedDescription.contains("gradients"))
            }
        }
    }

    @Test("CLI accepts repeated inputs and expands both templates")
    func commandOptionsSupportThemeFamilies() throws {
        let options = try CodeGenerationCommandOptions(arguments: [
            "--input", "BrandA.theme.json",
            "--input", "BrandB.theme.json",
            "--output", "Generated",
            "--template", "both",
        ])

        #expect(options.inputURLs.map(\.lastPathComponent) == [
            "BrandA.theme.json",
            "BrandB.theme.json",
        ])
        #expect(options.templates == [.tokens, .assets])
        #expect(options.outputDirectoryURL?.lastPathComponent == "Generated")
    }

    @Test("CLI rejects unsupported templates")
    func commandOptionsRejectUnsupportedTemplates() {
        #expect(throws: CodeGenerationCLIError.self) {
            try CodeGenerationCommandOptions(arguments: ["--template", "react"])
        }
    }

    private func writeTheme(colors: [String], to url: URL) throws {
        let colorTokens = Dictionary(uniqueKeysWithValues: colors.map {
            ("test/\($0)", colorToken())
        })
        let document = validThemeDocument(colors: colorTokens)
        try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]).write(to: url)
    }

    private func validThemeDocument(
        id: String = "codegen-test",
        colors: [String: Any] = [:],
        units: [String: Any]? = nil,
        extensions: [String: Any] = [:],
        colorGroup: String = "test",
        fontGroup: String = "typography"
    ) -> [String: Any] {
        var colors = colors
        let colorDefault = colorGroup.isEmpty ? "default" : "\(colorGroup)/default"
        let fontDefault = fontGroup.isEmpty ? "default" : "\(fontGroup)/default"
        colors[colorDefault] = colorToken(group: colorGroup)
        let units = units ?? ["spacing/default": token(group: "spacing")]
        var document: [String: Any] = [
            "id": id,
            "defaults": [
                "font": fontDefault,
                "primaryTextColor": colorDefault,
            ],
            "colors": colors,
            "fonts": [fontDefault: fontToken(group: fontGroup)],
            "units": units,
        ]
        for (key, value) in extensions {
            document[key] = value
        }
        return document
    }

    private func colorToken(group: String = "test") -> [String: Any] {
        token(
            group: group,
            modes: [
                "light": ["hex": "#000000", "alpha": 1],
                "dark": ["hex": "#FFFFFF", "alpha": 1],
            ]
        )
    }

    private func fontToken(group: String = "typography") -> [String: Any] {
        token(
            group: group,
            modes: [
                "default": [
                    "fontSize": 16,
                    "fontName": "Helvetica",
                    "lineHeight": 20,
                    "letterSpacing": 0,
                    "textCase": "ORIGINAL",
                ],
            ]
        )
    }

    private func token(group: String, modes: [String: Any] = ["default": 8]) -> [String: Any] {
        [
            "name": "Token",
            "group": group,
            "description": "Generated\ndocumentation",
            "modes": modes,
        ]
    }

    private func write(_ document: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]).write(to: url)
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("gamma-codegen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try body(directory)
    }
}
