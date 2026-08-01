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

@Suite("Theme mode resolver")
struct ThemeModeResolverTests {
    @Test("Default resolver uses default font and unit modes")
    func defaultResolverUsesDefaultFontAndUnitModes() {
        let modes = DefaultThemeModeResolver().resolve(
            in: ThemeModeContext(
                colorScheme: .light,
                layoutDirection: .leftToRight,
                horizontalSizeClass: .compact
            )
        )

        #expect(
            modes[Theme.Colors.self]
                == ThemeColorModeSelection(light: "light", dark: "dark")
        )
        #expect(modes[Theme.Fonts.self] == ThemeFontModeSelection(primary: "default"))
        #expect(modes[Theme.Units.self] == "default")
    }

    @Test("Default font and unit modes do not vary with resolver context")
    func defaultFontAndUnitModesDoNotVaryWithContext() {
        let modes = DefaultThemeModeResolver().resolve(
            in: ThemeModeContext(
                colorScheme: .light,
                layoutDirection: .rightToLeft,
                horizontalSizeClass: .regular
            )
        )

        #expect(modes[Theme.Fonts.self] == ThemeFontModeSelection(primary: "default"))
        #expect(modes[Theme.Units.self] == "default")
    }

    @Test("Custom resolver can use horizontal size class")
    func customResolverCanUseHorizontalSizeClass() {
        let resolver = ResponsiveModeResolver()

        let compactModes = resolver.resolve(
            in: ThemeModeContext(
                colorScheme: .light,
                layoutDirection: .leftToRight,
                horizontalSizeClass: .compact
            )
        )
        let regularModes = resolver.resolve(
            in: ThemeModeContext(
                colorScheme: .light,
                layoutDirection: .leftToRight,
                horizontalSizeClass: .regular
            )
        )

        #expect(compactModes[Theme.Units.self] == "compact")
        #expect(regularModes[Theme.Units.self] == "regular")
    }

    @Test("Custom family modes are selected dynamically by typed family")
    func customFamilyModesAreDynamicallySelected() {
        let resolver = ExtensionModeResolver()
        let lightModes = resolver.resolve(
            in: ThemeModeContext(
                colorScheme: .light,
                layoutDirection: .leftToRight,
                horizontalSizeClass: .compact
            )
        )
        let darkModes = resolver.resolve(
            in: ThemeModeContext(
                colorScheme: .dark,
                layoutDirection: .leftToRight,
                horizontalSizeClass: .regular
            )
        )

        #expect(lightModes[Theme.TestGradients.self] == "day")
        #expect(darkModes[Theme.TestGradients.self] == "night")
        #expect(lightModes[TestMotion.self] == "reduced")
        #expect(darkModes[TestMotion.self] == "expressive")
    }

    @Test("Type-erased resolvers compare using resolver state")
    func typeErasedResolversCompareUsingResolverState() {
        let compact = AnyThemeModeResolver(ResponsiveModeResolver(fallbackUnitMode: "compact"))
        let sameCompact = AnyThemeModeResolver(ResponsiveModeResolver(fallbackUnitMode: "compact"))
        let spacious = AnyThemeModeResolver(ResponsiveModeResolver(fallbackUnitMode: "spacious"))

        #expect(compact == sameCompact)
        #expect(compact != spacious)
    }

    @Test("Token cache scope follows theme, resolver, and environment rather than mode names")
    func cacheScopeTracksResolutionInputs() {
        let themeID = UUID()
        let compact = ThemeCacheScope(
            themeInstanceID: themeID,
            overrideHash: 0,
            modeResolver: AnyThemeModeResolver(ResponsiveModeResolver()),
            colorScheme: .light,
            layoutDirection: .leftToRight,
            horizontalSizeClass: .compact
        )
        let regular = ThemeCacheScope(
            themeInstanceID: themeID,
            overrideHash: 0,
            modeResolver: AnyThemeModeResolver(ResponsiveModeResolver()),
            colorScheme: .light,
            layoutDirection: .leftToRight,
            horizontalSizeClass: .regular
        )
        let dark = ThemeCacheScope(
            themeInstanceID: themeID,
            overrideHash: 0,
            modeResolver: AnyThemeModeResolver(ResponsiveModeResolver()),
            colorScheme: .dark,
            layoutDirection: .leftToRight,
            horizontalSizeClass: .compact
        )
        let replacementTheme = ThemeCacheScope(
            themeInstanceID: UUID(),
            overrideHash: 0,
            modeResolver: AnyThemeModeResolver(ResponsiveModeResolver()),
            colorScheme: .light,
            layoutDirection: .leftToRight,
            horizontalSizeClass: .compact
        )

        #expect(compact != regular)
        #expect(compact != dark)
        #expect(compact != replacementTheme)
        #expect(
            ThemeTokenCacheKey(scope: compact, alias: "background")
                == ThemeTokenCacheKey(scope: compact, alias: "background")
        )
    }

    @Test("Theme modifier injects the resolver used by ThemeProxy")
    func themeModifierInjectsResolverUsedByThemeProxy() async throws {
        let rawTheme = try JSONDecoder().decode(
            RawTheme.self,
            from: Data(Self.themeJSON.utf8)
        )
        var resolvedUnit: CGFloat?

        let view = UnitProbe { resolvedUnit = $0 }
            .theme(rawTheme, modeResolver: ResponsiveModeResolver())
            .environment(\.horizontalSizeClass, .regular)
        let hostingController = UIHostingController(rootView: view)
        let window = UIWindow(frame: UIScreen.main.bounds)

        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        await Task.yield()

        #expect(resolvedUnit == 24)
        window.isHidden = true
    }

    private static let themeJSON = """
        {
          "id": "test-theme",
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
                "day": { "hex": "#111111", "alpha": 1 },
                "night": { "hex": "#EEEEEE", "alpha": 1 }
              }
            }
          },
          "fonts": {
            "typography/body": {
              "name": "Body",
              "group": "typography",
              "description": "ios:body",
              "modes": {
                "primary": {
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
              "name": "spacing",
              "group": "spacing",
              "description": "",
              "modes": {
                "compact": 12,
                "regular": 24
              }
            }
          }
        }
        """
}

private struct ResponsiveModeResolver: ThemeModeResolving {
    var fallbackUnitMode = "default"

    var cacheIdentity: AnyHashable { fallbackUnitMode }

    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
        let unitMode: String
        switch context.horizontalSizeClass {
        case .compact:
            unitMode = "compact"
        case .regular:
            unitMode = "regular"
        case nil:
            unitMode = fallbackUnitMode
        @unknown default:
            unitMode = fallbackUnitMode
        }

        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = ThemeColorModeSelection(light: "day", dark: "night")
        modes[Theme.Fonts.self] = ThemeFontModeSelection(primary: "primary")
        modes[Theme.Units.self] = unitMode
        return modes
    }
}

private struct ExtensionModeResolver: ThemeModeResolving {
    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = .init(light: "light", dark: "dark")
        modes[Theme.Fonts.self] = .init(primary: "default")
        modes[Theme.Units.self] = "default"
        modes[Theme.TestGradients.self] = context.colorScheme == .dark ? "night" : "day"
        modes[TestMotion.self] = context.horizontalSizeClass == .compact
            ? "reduced"
            : "expressive"
        return modes
    }
}

nonisolated private enum TestMotion: ThemeExtension {
    typealias Token = TestMotionToken

    static let key = "motion"
}

nonisolated private struct TestMotionToken: ThemeExtensionToken {
    let name: String
    let group: String
    let modes: [String: String]
}

nonisolated private enum SpacingGroup: ThemeTokenGroup {
    typealias Family = Theme.Units
    static let name = "spacing"
}

private typealias SpacingAlias = Theme.Alias<SpacingGroup>

private struct UnitProbe: View {
    @ThemeReader private var theme

    let onResolve: (CGFloat) -> Void

    var body: some View {
        let resolvedUnit = theme.unit(SpacingAlias(rawValue: "spacing/default"))
        onResolve(resolvedUnit)
        return Color.clear
    }
}
#endif
