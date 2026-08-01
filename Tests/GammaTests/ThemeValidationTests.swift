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

#if canImport(UIKit)
import Foundation
import Testing
@testable import Gamma

@Suite("Theme validation")
struct ThemeValidationTests {
    @Test("Valid themes pass schema and selected-mode validation")
    func validThemePassesValidation() throws {
        let theme = try decode(Self.validThemeJSON)
        let modes = ThemeModes(
            colors: .init(light: "light", dark: "dark"),
            fonts: .init(primary: "default"),
            units: "default"
        )

        #expect(theme.validationIssues(modes: modes).isEmpty)
    }

    @Test("Malformed theme schemas are rejected with consolidated paths")
    func malformedThemeIsRejectedWithConsolidatedPaths() {
        let json = """
        {
          "id": "broken",
          "defaults": {
            "font": "missing-font",
            "primaryTextColor": "missing-color"
          },
          "colors": {
            "content/text": {
              "name": "Text",
              "group": "content",
              "description": "",
              "modes": {
                "light": { "hex": "not-a-color", "alpha": 2 }
              }
            }
          },
          "fonts": {
            "typography/body": {
              "name": "Body",
              "group": "typography",
              "description": "",
              "modes": {
                "default": {
                  "fontSize": 0,
                  "fontName": "",
                  "lineHeight": -1,
                  "letterSpacing": 0,
                  "textCase": "ORIGINAL"
                }
              }
            }
          },
          "units": {
            "spacing": {
              "name": "Spacing",
              "group": "",
              "description": "",
              "modes": {}
            }
          }
        }
        """

        do {
            _ = try decode(json)
            Issue.record("Expected malformed theme decoding to fail")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.debugDescription.contains("defaults.font"))
            #expect(context.debugDescription.contains("defaults.primaryTextColor"))
            #expect(context.debugDescription.contains("colors.content/text.modes.light.hex"))
            #expect(context.debugDescription.contains("colors.content/text.modes.light.alpha"))
            #expect(context.debugDescription.contains("fonts.typography/body.modes.default.fontName"))
            #expect(context.debugDescription.contains("fonts.typography/body.modes.default.fontSize"))
            #expect(context.debugDescription.contains("fonts.typography/body.modes.default.lineHeight"))
            #expect(context.debugDescription.contains("units.spacing.modes"))
        } catch {
            Issue.record("Unexpected decoding error: \(error)")
        }
    }

    @Test("Empty token groups are accepted")
    func emptyTokenGroupsAreAccepted() throws {
        let json = Self.validThemeJSON
            .replacingOccurrences(of: #""font": "typography/body""#, with: #""font": "body""#)
            .replacingOccurrences(of: #""primaryTextColor": "content/text""#, with: #""primaryTextColor": "text""#)
            .replacingOccurrences(of: #""content/text": {"#, with: #""text": {"#)
            .replacingOccurrences(of: #""typography/body": {"#, with: #""body": {"#)
            .replacingOccurrences(of: #""spacing/default": {"#, with: #""spacing": {"#)
            .replacingOccurrences(of: #""group": "content""#, with: #""group": """#)
            .replacingOccurrences(of: #""group": "typography""#, with: #""group": """#)
            .replacingOccurrences(of: #""group": "spacing""#, with: #""group": """#)

        _ = try decode(json)
    }

    @Test("A grouped token key must begin with its exact group")
    func groupedTokenKeyMustMatchGroup() {
        let json = Self.validThemeJSON.replacingOccurrences(
            of: #""group": "content""#,
            with: #""group": "surface""#
        )

        do {
            _ = try decode(json)
            Issue.record("Expected mismatched token group decoding to fail")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.debugDescription.contains("colors.content/text.group"))
            #expect(context.debugDescription.contains(#"expected token key "surface"/<name>"#))
        } catch {
            Issue.record("Unexpected decoding error: \(error)")
        }
    }

    @Test("An empty token group requires a single-component key")
    func emptyTokenGroupRequiresSingleComponentKey() {
        let json = Self.validThemeJSON.replacingOccurrences(
            of: #""group": "content""#,
            with: #""group": """#
        )

        do {
            _ = try decode(json)
            Issue.record("Expected grouped key with an empty group to fail")
        } catch let DecodingError.dataCorrupted(context) {
            #expect(context.debugDescription.contains("colors.content/text.group"))
            #expect(context.debugDescription.contains("empty group requires a single-component token key"))
        } catch {
            Issue.record("Unexpected decoding error: \(error)")
        }
    }

    @Test("Unknown font text cases are rejected")
    func unknownFontTextCaseIsRejected() {
        let json = Self.validThemeJSON.replacingOccurrences(
            of: "\"textCase\": \"ORIGINAL\"",
            with: "\"textCase\": \"TITLE\""
        )

        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    @Test("Resolver-selected modes are validated before token resolution")
    func selectedModesAreValidated() throws {
        let theme = try decode(Self.validThemeJSON)
        let modes = ThemeModes(
            colors: .init(light: "day", dark: "night"),
            fonts: .init(primary: "primary", cascades: ["fallback"]),
            units: "tablet"
        )

        let paths = Set(theme.validationIssues(modes: modes).map(\.path))

        #expect(paths.contains("colors.content/text.modes.day"))
        #expect(paths.contains("colors.content/text.modes.night"))
        #expect(paths.contains("fonts.typography/body.modes.primary"))
        #expect(paths.contains("fonts.typography/body.modes.fallback"))
        #expect(paths.contains("units.spacing/default.modes.tablet"))
    }

    @Test("Resolver-selected font faces must be available to UIKit")
    func unavailableSelectedFontsAreReported() throws {
        let unavailableName = "Gamma-Definitely-Not-Installed"
        let theme = try decode(
            Self.validThemeJSON.replacingOccurrences(of: "Helvetica", with: unavailableName)
        )
        let modes = ThemeModes(
            colors: .init(light: "light", dark: "dark"),
            fonts: .init(primary: "default"),
            units: "default"
        )

        let issues = theme.validationIssues(modes: modes)
            .filter { $0.path.hasSuffix(".fontName") }

        #expect(issues.count == 1)
        #expect(issues.allSatisfy { $0.message.contains(unavailableName) })
    }

    @Test("Separately decoded payloads with the same logical ID have distinct runtime identity")
    func sameIDPayloadsHaveDistinctRuntimeIdentity() throws {
        let first = try decode(Self.validThemeJSON)
        let second = try decode(Self.validThemeJSON)

        #expect(first.id == second.id)
        #expect(first != second)
    }

    @Test("Malformed eight-digit colors are rejected instead of becoming black")
    func malformedHexaIsRejected() {
        #expect(RawColor.Mode(hexa: "not-a-color") == nil)
        #expect(RawColor.Mode(hexa: "#112233CC")?.hex == "#112233")
    }

    private func decode(_ json: String) throws -> RawTheme {
        try JSONDecoder().decode(RawTheme.self, from: Data(json.utf8))
    }

    private static let validThemeJSON = """
    {
      "id": "valid-theme",
      "defaults": {
        "font": "typography/body",
        "primaryTextColor": "content/text"
      },
      "colors": {
        "content/text": {
          "name": "Text",
          "group": "content",
          "description": "",
          "modes": {
            "light": { "hex": "#111111", "alpha": 1 },
            "dark": { "hex": "#EEEEEE", "alpha": 1 }
          }
        }
      },
      "fonts": {
        "typography/body": {
          "name": "Body",
          "group": "typography",
          "description": "ios:body",
          "modes": {
            "default": {
              "fontSize": 16,
              "fontName": "Helvetica",
              "lineHeight": 20,
              "letterSpacing": 0,
              "textCase": "ORIGINAL"
            }
          }
        }
      },
      "units": {
        "spacing/default": {
          "name": "Spacing",
          "group": "spacing",
          "description": "",
          "modes": { "default": 12 }
        }
      }
    }
    """
}
#endif
