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
                colors: ["1x/foo", "icon@2x", "class", "get", "quote\"and\\slash"],
                to: input
            )

            let source = try GammaCodeGenerator.generate(
                inputURL: input,
                template: .tokens
            ).source

            #expect(source.contains("static var _1xFoo"))
            #expect(source.contains("static var icon2x"))
            #expect(source.contains("static var `class`"))
            #expect(source.contains("static var `get`"))
            #expect(source.contains(#"Self(rawValue: "quote\"and\\slash")"#))
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

    @Test("Duplicate asset basenames warn with both paths and keep one alias")
    func duplicateAssetsWarnAndKeepLast() throws {
        try withTemporaryDirectory { directory in
            let catalogue = directory.appendingPathComponent("Assets.xcassets", isDirectory: true)
            let first = catalogue.appendingPathComponent("Actions/close.imageset", isDirectory: true)
            let second = catalogue.appendingPathComponent("Navigation/close.imageset", isDirectory: true)
            let third = catalogue.appendingPathComponent("Toolbar/close.imageset", isDirectory: true)
            try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: third, withIntermediateDirectories: true)

            let output = try GammaCodeGenerator.generate(
                inputURL: catalogue,
                template: .assets
            )

            #expect(output.warnings.count == 1)
            #expect(output.warnings[0].contains(first.path))
            #expect(output.warnings[0].contains(second.path))
            #expect(output.warnings[0].contains(third.path))
            #expect(output.source.components(separatedBy: "static let close").count - 1 == 1)
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
                    "space/large": token(group: "Spacing"),
                    "space/small": token(group: "Spacing"),
                    "radius/card": token(group: "Radius"),
                ]
            )
            try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]).write(to: input)

            let first = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source
            let second = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(first == second)
            #expect(first.contains("struct SpacingAlias: @MainActor UnitAlias"))
            #expect(first.contains("static var spaceSmall"))
            #expect(first.contains("struct RadiusAlias: @MainActor UnitAlias"))
        }
    }

    @Test("Unit group type names remain valid when the group is a keyword")
    func keywordUnitGroup() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: ["value/default": token(group: "Self")]
            )
            try JSONSerialization.data(withJSONObject: document).write(to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("struct SelfAlias: @MainActor UnitAlias"))
            #expect(source.contains("Self == Theme.SelfAlias"))
        }
    }

    @Test("Generation accepts empty token groups")
    func emptyTokenGroups() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: ["space/default": token(group: "")],
                colorGroup: "",
                fontGroup: ""
            )
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("static var colorDefault"))
            #expect(source.contains("static var fontDefault"))
            #expect(source.contains("Extension == Theme.Colors"))
            #expect(source.contains("Extension == Theme.Fonts"))
            #expect(!source.contains("struct SpacingAlias: UnitAlias"))
        }
    }

    @Test("Custom token families generate markers, aliases, and accessors")
    func customTokenFamilyGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": [
                    "gradient/hero": token(group: "Brand"),
                    "something": token(group: "Brand"),
                ],
            ])
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.contains("nonisolated enum Gradients: ThemeExtensionKey"))
            #expect(source.contains(#"nonisolated public static let key = "gradients""#))
            #expect(source.contains("typealias GradientsAlias = ThemeExtensionAlias<Gradients>"))
            #expect(source.contains("Extension == Theme.Gradients"))
            #expect(source.contains(#"static var gradientHero: Self { Self(rawValue: "gradient/hero") }"#))
            #expect(source.contains(#"static var something: Self { Self(rawValue: "something") }"#))
        }
    }

    @Test("Accessor names may repeat across custom token families")
    func customAccessorNamesAreScopedByFamily() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": ["shared": token(group: "Brand")],
                "shadows": ["shared": token(group: "Elevation")],
            ])
            try write(document, to: input)

            let source = try GammaCodeGenerator.generate(inputURL: input, template: .tokens).source

            #expect(source.components(separatedBy: "static var shared").count - 1 == 2)
            #expect(source.contains("Extension == Theme.Gradients"))
            #expect(source.contains("Extension == Theme.Shadows"))
        }
    }

    @Test("Custom family aliases cannot collide with other Theme nested types")
    func customFamilyTypeCollision() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(
                units: ["space/default": token(group: "Gradients")],
                extensions: ["gradients": ["hero": token(group: "Brand")]]
            )
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected nested Theme type collision to fail generation")
            } catch {
                #expect(error.localizedDescription.contains("GradientsAlias"))
                #expect(error.localizedDescription.contains("unit group"))
                #expect(error.localizedDescription.contains("extension alias"))
            }
        }
    }

    @Test("Malformed custom token metadata fails generation")
    func malformedCustomTokenFailsGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("theme.json")
            let document = validThemeDocument(extensions: [
                "gradients": [
                    "gradient/hero": [
                        "name": "",
                        "group": "Brand",
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
                #expect(error.localizedDescription.contains("gradients.gradient/hero.name"))
            }
        }
    }

    @Test("Generation rejects a malformed theme through the shared schema")
    func malformedThemeFailsGeneration() throws {
        try withTemporaryDirectory { directory in
            let input = directory.appendingPathComponent("Broken.theme.json")
            var document = validThemeDocument()
            var colors = document["colors"] as! [String: Any]
            var color = colors["color/default"] as! [String: Any]
            var modes = color["modes"] as! [String: Any]
            modes["light"] = ["hex": "broken", "alpha": 1]
            color["modes"] = modes
            colors["color/default"] = color
            document["colors"] = colors
            try write(document, to: input)

            do {
                _ = try GammaCodeGenerator.generate(inputURL: input, template: .tokens)
                Issue.record("Expected schema validation to fail generation")
            } catch {
                #expect(error.localizedDescription.contains(input.path))
                #expect(error.localizedDescription.contains("colors.color/default.modes.light.hex"))
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

            #expect(output.source.components(separatedBy: "static var colorDefault").count - 1 == 1)
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
            colors["color/brand-only"] = colorToken()
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
                #expect(error.localizedDescription.contains("color/brand-only"))
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
                extensions: ["gradients": ["gradient/hero": token(group: "Brand")]]
            ), to: first)
            try write(validThemeDocument(
                id: "night",
                extensions: ["gradients": [
                    "gradient/hero": token(group: "Brand"),
                    "gradient/night-only": token(group: "Brand"),
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
                #expect(error.localizedDescription.contains("gradient/night-only"))
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
        let colorTokens = Dictionary(uniqueKeysWithValues: colors.map { ($0, colorToken()) })
        let document = validThemeDocument(colors: colorTokens)
        try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys]).write(to: url)
    }

    private func validThemeDocument(
        id: String = "codegen-test",
        colors: [String: Any] = [:],
        units: [String: Any]? = nil,
        extensions: [String: Any] = [:],
        colorGroup: String = "Test",
        fontGroup: String = "Typography"
    ) -> [String: Any] {
        var colors = colors
        colors["color/default"] = colorToken(group: colorGroup)
        let units = units ?? ["space/default": token(group: "Spacing")]
        var document: [String: Any] = [
            "id": id,
            "defaults": [
                "font": "font/default",
                "primaryTextColor": "color/default",
            ],
            "colors": colors,
            "fonts": ["font/default": fontToken(group: fontGroup)],
            "units": units,
        ]
        for (key, value) in extensions {
            document[key] = value
        }
        return document
    }

    private func colorToken(group: String = "Test") -> [String: Any] {
        token(
            group: group,
            modes: [
                "light": ["hex": "#000000", "alpha": 1],
                "dark": ["hex": "#FFFFFF", "alpha": 1],
            ]
        )
    }

    private func fontToken(group: String = "Typography") -> [String: Any] {
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
