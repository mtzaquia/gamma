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

nonisolated private enum SurfaceColorGroup: ThemeTokenGroup {
    typealias Family = Theme.Colors
    static let name = "surface"
}

nonisolated private enum TextFontGroup: ThemeTokenGroup {
    typealias Family = Theme.Fonts
    static let name = "text"
}

nonisolated private enum OnSurfaceColorGroup: ThemeTokenGroup {
    typealias Family = Theme.Colors
    static let name = "onSurface"
}

private typealias SurfaceColorAlias = Theme.Alias<SurfaceColorGroup>
private typealias TextFontAlias = Theme.Alias<TextFontGroup>

public extension Theme.Alias where Scope == Theme.Colors {
    static var canvas: Self {
        Self(rawValue: "canvas")
    }

    @_disfavoredOverload
    static var surfacePrimary: Self {
        Self(rawValue: "surface/primary")
    }

    @_disfavoredOverload
    static var onSurfaceLink: Self {
        Self(rawValue: "onSurface/link")
    }
}

private extension Theme.Alias where Scope == SurfaceColorGroup {
    static var surfacePrimary: Self {
        Self(rawValue: "surface/primary")
    }
}

private extension Theme.Alias where Scope == OnSurfaceColorGroup {
    static var onSurfaceLink: Self {
        Self(rawValue: "onSurface/link")
    }
}

@Suite("Public API contracts")
struct PublicAPIContractTests {
    @Test("Alias groups retain their family and raw token key")
    func aliasesRetainGroupAndFamily() {
        let color: SurfaceColorAlias = .surfacePrimary
        let font = TextFontAlias(rawValue: "text/body")
        let familyColor: Theme.Alias<Theme.Colors> = .canvas

        #expect(color.rawValue == "surface/primary")
        #expect(font.rawValue == "text/body")
        #expect(SurfaceColorAlias.AliasScope.name == "surface")
        #expect(TextFontAlias.AliasScope.name == "text")
        #expect(familyColor.rawValue == "canvas")
    }

    @Test("Grouped members compose through family aliases without weakening inference")
    func groupedMembersComposeThroughFamilyAliases() {
        let primary = foregroundToken(for: .primary)
        let secondary = foregroundToken(for: .secondary)

        #expect(primary.rawValue == "surface/primary")
        #expect(secondary.rawValue == "onSurface/link")
        #expect(inferredColorScope(.surfacePrimary) == "surface")
        #expect(inferredColorScope(.onSurfaceLink) == "onSurface")
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

    @Test("Mode initializer stores built-in family selections")
    func modeInitializerStoresBuiltInFamilies() {
        let colors = ThemeColorModeSelection(light: "day", dark: "night")
        let fonts = ThemeFontModeSelection(primary: "latin", cascades: ["arabic"])
        let modes = ThemeModes(colors: colors, fonts: fonts, units: "compact")

        #expect(modes[Theme.Colors.self] == colors)
        #expect(modes[Theme.Fonts.self] == fonts)
        #expect(modes[Theme.Units.self] == "compact")
    }

}

private enum ColorVariant {
    case primary
    case secondary
}

private func foregroundToken(for variant: ColorVariant) -> Theme.Alias<Theme.Colors> {
    switch variant {
    case .primary:
        .surfacePrimary
    case .secondary:
        .onSurfaceLink
    }
}

private func inferredColorScope<Scope: ThemeAliasScope>(
    _ alias: Theme.Alias<Scope>
) -> String? where Scope.Family == Theme.Colors {
    Scope.groupName
}
#endif
