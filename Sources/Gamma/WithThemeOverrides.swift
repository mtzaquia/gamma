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
import SwiftUI

/// A set of token value overrides decoded from JSON, keyed by token name then mode name.
nonisolated public struct RawThemeOverrides: Decodable, Hashable, Sendable {
    let colors: [String: [String: RawColor.Mode]]
    let fonts: [String: [String: RawFont.Mode]]
    let units: [String: [String: RawUnit.Mode]]

    /// Creates a set of theme overrides for a given scope of ``WithThemeOverrides``.
    /// - Parameters:
    ///   - colors: Replacement color-mode dictionaries keyed by existing token name.
    ///   - fonts: Replacement font-mode dictionaries keyed by existing token name.
    ///   - units: Replacement unit-mode dictionaries keyed by existing token name.
    public init(
        colors: [String : [String : RawColor.Mode]] = [:],
        fonts: [String : [String : RawFont.Mode]] = [:],
        units: [String : [String : RawUnit.Mode]] = [:]
    ) {
        self.colors = colors
        self.fonts = fonts
        self.units = units
    }

    func combinedHash(with parentHash: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(parentHash)
        hasher.combine(self)
        return hasher.finalize()
    }
}

/// A view that applies decoded token overrides to the theme environment of its content.
///
/// Use this to hot-swap specific design tokens (colors, fonts, units) within a
/// subtree without replacing the entire theme.
public struct WithThemeOverrides<Content: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.themeModeResolver) private var modeResolver

    let overrides: RawThemeOverrides
    let content: Content

    public var body: some View {
        let resolvedModes = modeResolver.resolve(
            in: ThemeModeContext(
                layoutDirection: layoutDirection,
                horizontalSizeClass: horizontalSizeClass
            )
        )

        content
            .transformEnvironment(\.theme) { theme in
                let issues = theme.apply(overrides)
                ThemeDiagnostics.validate(
                    theme,
                    resolvedModes: resolvedModes,
                    additionalIssues: issues
                )
                ThemeDiagnostics.overridesApplied(theme, overrides: overrides)
            }

    }

    /// Creates the view with the given token overrides applied to all content.
    public init(overrides: RawThemeOverrides, @ViewBuilder content: () -> Content) {
        self.overrides = overrides
        self.content = content()
    }
}

private extension RawTheme {
    mutating func apply(_ overrides: RawThemeOverrides) -> [ThemeValidationIssue] {
        var issues: [ThemeValidationIssue] = []

        for (token, modes) in overrides.colors {
            guard var color = colors[token] else {
                issues.append(.init(
                    path: "overrides.colors.\(token)",
                    message: "references a color token that does not exist"
                ))
                continue
            }
            color.modes = modes
            colors[token] = color
        }

        for (token, modes) in overrides.fonts {
            guard var font = fonts[token] else {
                issues.append(.init(
                    path: "overrides.fonts.\(token)",
                    message: "references a font token that does not exist"
                ))
                continue
            }
            font.modes = modes
            fonts[token] = font
        }

        for (token, modes) in overrides.units {
            guard var unit = units[token] else {
                issues.append(.init(
                    path: "overrides.units.\(token)",
                    message: "references a unit token that does not exist"
                ))
                continue
            }
            unit.modes = modes
            units[token] = unit
        }

        overrideHash = overrides.combinedHash(with: overrideHash)
        return issues
    }
}
