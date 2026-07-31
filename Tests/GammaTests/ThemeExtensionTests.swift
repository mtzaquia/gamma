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
import SwiftUI
import Testing
import UIKit
@testable import Gamma

@Suite("Theme extensions")
struct ThemeExtensionTests {
    @Test("A custom root key decodes directly as a keyed token dictionary")
    func flatTokenDictionaryDecodes() throws {
        let theme = try decode(Self.themeJSON)
        let decodedTokens = try ThemeExtensionTokenCache.tokens(
            for: Theme.TestGradients.self,
            in: theme
        )
        let tokens = try #require(decodedTokens)
        let hero = try #require(tokens["gradient/hero"])

        #expect(hero.name == "Hero")
        #expect(hero.group == "brand")
        #expect(hero.modes["light"]?.stops == ["color/start", "color/end"])
    }

    @Test("Registered extensions validate their shared token structure")
    func registeredExtensionStructureIsValidated() throws {
        let json = Self.themeJSON
            .replacingOccurrences(of: #""name": "Hero""#, with: #""name": """#)
            .replacingOccurrences(of: #""group": "brand","#, with: "")
            .replacingOccurrences(
                of: "        \"light\": { \"stops\": [\"color/start\", \"color/end\"] },\n",
                with: ""
            )
            .replacingOccurrences(
                of: "        \"dark\": { \"stops\": [\"color/end\", \"color/start\"] }\n",
                with: ""
            )
        let theme = try decode(json)
        let issues = theme.validationIssues(
            extensions: [ThemeExtensionRegistration(Theme.TestGradients.self)]
        )
        let paths = Set(issues.map(\.path))

        #expect(paths.contains("gradients.gradient/hero.name"))
        #expect(paths.contains("gradients.gradient/hero.group"))
        #expect(paths.contains("gradients.gradient/hero.modes"))
    }

    @Test("Registered extensions must be present in the installed theme")
    func registeredExtensionMustBePresent() throws {
        let extensionStart = try #require(Self.themeJSON.range(of: ",\n  \"gradients\":"))
        let json = String(Self.themeJSON[..<extensionStart.lowerBound]) + "\n}"
        let theme = try decode(json)
        let issues = theme.validationIssues(
            extensions: [ThemeExtensionRegistration(Theme.TestGradients.self)]
        )

        #expect(issues.contains {
            $0.path == "gradients" && $0.message == "registered extension payload is missing"
        })
    }

    @Test("Registered extensions validate their concrete token payload")
    func registeredExtensionPayloadIsValidated() throws {
        let json = Self.themeJSON.replacingOccurrences(
            of: #""stops": ["color/start", "color/end"]"#,
            with: #""stops": "invalid""#
        )
        let theme = try decode(json)
        let issues = theme.validationIssues(
            extensions: [ThemeExtensionRegistration(Theme.TestGradients.self)]
        )

        #expect(issues.contains {
            $0.path == "gradients" && $0.message.contains("TestGradientToken")
        })
    }

    @Test("ThemeProxy returns the resolver-selected concrete mode type")
    func proxyReturnsSelectedConcreteMode() async throws {
        let rawTheme = try decode(Self.themeJSON)
        var resolvedStops: [String]?
        var installedExtensionCount = 0
        let view = ExtensionProbe { mode, extensionCount in
            resolvedStops = mode?.stops
            installedExtensionCount = extensionCount
        }
            .theme(
                rawTheme,
                modeResolver: TestExtensionModeResolver(),
                extensions: [ThemeExtensionRegistration(Theme.TestGradients.self)]
            )
            .environment(\.colorScheme, .dark)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: UIScreen.main.bounds)

        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        await Task.yield()

        #expect(resolvedStops == ["color/end", "color/start"])
        #expect(installedExtensionCount == 1)
        window.isHidden = true
    }

    @Test("Registered extensions validate the resolver-selected mode")
    func registeredExtensionModeIsValidated() throws {
        let theme = try decode(Self.themeJSON)
        var missingSelection = ResolvedThemeModes()
        missingSelection[Theme.Colors.self] = .init(light: "light", dark: "dark")
        missingSelection[Theme.Fonts.self] = .init(primary: "default")
        missingSelection[Theme.Units.self] = "default"
        let registration = ThemeExtensionRegistration(Theme.TestGradients.self)

        let selectionIssues = theme.validationIssues(
            resolvedModes: missingSelection,
            extensions: [registration]
        )
        #expect(selectionIssues.contains {
            $0.path == "resolver.gradients"
        })

        missingSelection[Theme.TestGradients.self] = "highContrast"
        let modeIssues = theme.validationIssues(
            resolvedModes: missingSelection,
            extensions: [registration]
        )
        #expect(modeIssues.contains {
            $0.path == "gradients.gradient/hero.modes.highContrast"
        })
    }

    private func decode(_ json: String) throws -> RawTheme {
        try JSONDecoder().decode(RawTheme.self, from: Data(json.utf8))
    }

    private static let themeJSON = """
    {
      "id": "extension-theme",
      "defaults": {
        "font": "body",
        "primaryTextColor": "text"
      },
      "colors": {
        "text": {
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
        "body": {
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
      "units": {},
      "gradients": {
        "gradient/hero": {
          "name": "Hero",
          "group": "brand",
          "modes": {
            "light": { "stops": ["color/start", "color/end"] },
            "dark": { "stops": ["color/end", "color/start"] }
          }
        }
      }
    }
    """
}

nonisolated public struct TestGradientToken: ThemeExtensionToken {
    nonisolated public struct Mode: Decodable {
        public let stops: [String]
    }

    public let name: String
    public let group: String
    public let modes: [String: Mode]
}

public extension Theme {
    nonisolated enum TestGradients: ThemeExtensionKey {
        public static let key = "gradients"
    }

    typealias TestGradientsAlias = ThemeExtensionAlias<TestGradients>
}

extension Theme.TestGradients: ThemeExtension {
    public typealias Token = TestGradientToken
}

public extension ThemeExtensionAlias where Extension == Theme.TestGradients {
    static var gradientHero: Self { Self(rawValue: "gradient/hero") }
}

private struct ExtensionProbe: View {
    @ThemeReader private var theme
    @Environment(\.themeExtensions) private var themeExtensions

    let onResolve: (TestGradientToken.Mode?, Int) -> Void

    var body: some View {
        onResolve(theme.resolve(.gradientHero), themeExtensions.count)
        return Color.clear
    }
}

private struct TestExtensionModeResolver: ThemeModeResolving {
    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = .init(light: "light", dark: "dark")
        modes[Theme.Fonts.self] = .init(primary: "default")
        modes[Theme.Units.self] = "default"
        modes[Theme.TestGradients.self] = context.colorScheme == .dark ? "dark" : "light"
        return modes
    }
}
#endif
