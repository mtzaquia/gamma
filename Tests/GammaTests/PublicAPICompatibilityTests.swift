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

public extension Theme.ColorAlias {
    static let compatibilityColor = Self(rawValue: "color/compatibility")
}

public extension Theme.FontAlias {
    static let compatibilityFont = Self(rawValue: "font/compatibility")
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

@Suite("Public API compatibility")
struct PublicAPICompatibilityTests {
    @Test("Original alias declarations remain extensible nominal types")
    func aliasesRemainExtensible() {
        #expect(Theme.ColorAlias.compatibilityColor.rawValue == "color/compatibility")
        #expect(Theme.FontAlias.compatibilityFont.rawValue == "font/compatibility")
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
