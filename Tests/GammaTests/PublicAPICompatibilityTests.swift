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
import SwiftUI
import Testing
import Gamma

nonisolated private enum CompatibilityColorGroup: ThemeTokenGroup {
    typealias Family = Theme.Colors
    static let name = "compatibility"
}

nonisolated private enum CompatibilityFontGroup: ThemeTokenGroup {
    typealias Family = Theme.Fonts
    static let name = "compatibility"
}

private typealias CompatibilityColorAlias = Theme.Alias<CompatibilityColorGroup>
private typealias CompatibilityFontAlias = Theme.Alias<CompatibilityFontGroup>

public extension Theme.Alias where Scope == Theme.Colors {
    static var compatibilityFamilyColor: Self {
        Self(rawValue: "compatibility/family-color")
    }
}

private struct CompatibilityModeResolver: ThemeModeResolving {
    func resolve(in _: ThemeModeContext) -> ResolvedThemeModes {
        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = .init(light: "light", dark: "dark")
        modes[Theme.Fonts.self] = .init(primary: "default")
        modes[Theme.Units.self] = "default"
        return modes
    }
}

private func legacyThemeModifier(_ theme: RawTheme) -> some View {
    EmptyView().theme(
        theme,
        modeResolver: CompatibilityModeResolver(),
        fontURLs: []
    )
}

private func legacyResourceModifier(_ resource: ThemeResource) -> some View {
    EmptyView().theme(
        resource,
        modeResolver: CompatibilityModeResolver(),
        fontURLs: []
    )
}

@Suite("Public API contracts")
struct PublicAPICompatibilityTests {
    @Test("Alias groups retain their family and raw token key")
    func aliasesRetainGroupAndFamily() {
        let color = CompatibilityColorAlias(rawValue: "compatibility/color")
        let font = CompatibilityFontAlias(rawValue: "compatibility/font")
        let familyColor: Theme.Alias<Theme.Colors> = .compatibilityFamilyColor

        #expect(color.rawValue == "compatibility/color")
        #expect(font.rawValue == "compatibility/font")
        #expect(CompatibilityColorAlias.AliasScope.name == "compatibility")
        #expect(CompatibilityFontAlias.AliasScope.name == "compatibility")
        #expect(familyColor.rawValue == "compatibility/family-color")
    }

    @Test("Aliases decode from and encode to a plain token-key string")
    func aliasesAreSingleValueCodable() throws {
        let alias = try JSONDecoder().decode(
            Theme.Alias<Theme.Colors>.self,
            from: Data(#""foo/bar""#.utf8)
        )
        let encoded = try JSONEncoder().encode(alias)
        let encodedRawValue = try JSONDecoder().decode(String.self, from: encoded)

        #expect(alias.rawValue == "foo/bar")
        #expect(alias.tokenGroup == "foo")
        #expect(alias.tokenName == "bar")
        #expect(encodedRawValue == "foo/bar")
        #expect(Theme.Colors.groupName == nil)
    }

    @Test("Original mode initializer and properties bridge to family selections")
    @available(*, deprecated)
    func modeSurfaceBridgesToTypedFamilies() {
        let colors = ThemeColorModeSelection(light: "day", dark: "night")
        let fonts = ThemeFontModeSelection(primary: "latin", cascades: ["arabic"])
        let modes = ResolvedThemeModes(colors: colors, fonts: fonts, unit: "compact")

        #expect(modes.colors == colors)
        #expect(modes.fonts == fonts)
        #expect(modes.unit == "compact")
        #expect(modes[Theme.Colors.self] == colors)
        #expect(modes[Theme.Fonts.self] == fonts)
        #expect(modes[Theme.Units.self] == "compact")
    }

    @Test("Original context initializer remains available")
    @available(*, deprecated)
    func contextInitializerRemainsAvailable() {
        let context = ThemeModeContext(
            layoutDirection: .rightToLeft,
            horizontalSizeClass: .compact
        )

        #expect(context.colorScheme == .light)
        #expect(context.layoutDirection == .rightToLeft)
        #expect(context.horizontalSizeClass == .compact)
    }
}
#endif
