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

@Suite("Raw theme overrides")
struct RawThemeOverridesTests {
    @Test("Nested identity includes its parent override")
    func nestedIdentityIncludesParentOverride() throws {
        let firstParent = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(.spacingDefault, modes: ["default": 12])]
        )
        let secondParent = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(.spacingDefault, modes: ["default": 24])]
        )
        let inner = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(
                .surfaceBackground,
                modes: ["light": .init(hex: "#FFFFFF", alpha: 1)]
            )]
        )

        let firstParentHash = firstParent.combinedHash(with: 0)
        let secondParentHash = secondParent.combinedHash(with: 0)
        let firstNestedHash = inner.combinedHash(with: firstParentHash)
        let secondNestedHash = inner.combinedHash(with: secondParentHash)

        #expect(firstNestedHash != secondNestedHash)
    }

    @Test("Override identity is stable for the same scope chain")
    func overrideIdentityIsStableForSameScopeChain() throws {
        let parent = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(.spacingDefault, modes: ["default": 12])]
        )
        let inner = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(
                .surfaceBackground,
                modes: ["light": .init(hex: "#FFFFFF", alpha: 1)]
            )]
        )

        let first = inner.combinedHash(with: parent.combinedHash(with: 0))
        let second = inner.combinedHash(with: parent.combinedHash(with: 0))

        #expect(first == second)
    }

    @Test("Override identity preserves scope order")
    func overrideIdentityPreservesScopeOrder() throws {
        let outer = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(.spacingDefault, modes: ["default": 12])]
        )
        let inner = RawThemeOverrides(
            tokens: [try ThemeTokenOverride(
                .surfaceBackground,
                modes: ["light": .init(hex: "#FFFFFF", alpha: 1)]
            )]
        )

        let outerThenInner = inner.combinedHash(with: outer.combinedHash(with: 0))
        let innerThenOuter = outer.combinedHash(with: inner.combinedHash(with: 0))

        #expect(outerThenInner != innerThenOuter)
    }

    @Test("Programmatic overrides retain the alias family and token key")
    func programmaticOverridesAreTyped() throws {
        let overrides = RawThemeOverrides(tokens: [
            try ThemeTokenOverride(.surfaceBackground, modes: [
                "light": .init(hex: "#FFFFFF", alpha: 1),
            ]),
            try ThemeTokenOverride(.spacingDefault, modes: ["default": 16]),
        ])

        #expect(Set(overrides.tokens(for: Theme.Colors.key).keys) == ["surface/background"])
        #expect(Set(overrides.tokens(for: Theme.Units.key).keys) == ["spacing/default"])
    }

    @Test("Programmatic overrides reject raw keys outside their alias group")
    func programmaticOverridesRejectAliasGroupMismatch() {
        let alias = Theme.Alias<OverrideSurfaceGroup>(rawValue: "brand/accent")

        #expect(throws: ThemeTokenOverrideError.aliasGroupMismatch(
            alias: "brand/accent",
            expectedGroup: "surface"
        )) {
            try ThemeTokenOverride(alias, modes: [
                "light": RawColor.Mode(hex: "#FFFFFF", alpha: 1),
            ])
        }
    }

    @Test("Decoded overrides preserve consumer-defined family keys")
    func decodedOverridesPreserveExtensionFamilies() throws {
        let overrides = try JSONDecoder().decode(
            RawThemeOverrides.self,
            from: Data(#"{"gradients":{"brand/hero":{"day":{"stops":["brand/start","brand/end"]}}}}"#.utf8)
        )

        #expect(Set(overrides.tokens(for: "gradients").keys) == ["brand/hero"])
        #expect(overrides.extensionTokenCount == 1)
    }

    @Test("Override diagnostics count extension tokens without exposing payloads")
    func overrideDiagnosticIncludesExtensionCount() {
        let event = GammaLogEvent.overridesApplied(
            themeID: "sample",
            colors: 1,
            fonts: 2,
            units: 3,
            extensions: 4
        )

        #expect(event.logLevel == .normal)
        #expect(
            event.message
                == "[override] ✓ applied | theme=sample colors=1 fonts=2 units=3 extensions=4"
        )
    }
}

nonisolated private enum OverrideSurfaceGroup: ThemeTokenGroup {
    typealias Family = Theme.Colors
    static let name = "surface"
}

nonisolated private enum OverrideSpacingGroup: ThemeTokenGroup {
    typealias Family = Theme.Units
    static let name = "spacing"
}

private extension Theme.Alias where Scope == OverrideSurfaceGroup {
    static var surfaceBackground: Self { Self(rawValue: "surface/background") }
}

private extension Theme.Alias where Scope == OverrideSpacingGroup {
    static var spacingDefault: Self { Self(rawValue: "spacing/default") }
}
#endif
