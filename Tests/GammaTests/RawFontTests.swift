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

import Testing
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
@testable import Gamma

@Suite("Raw font")
struct RawFontTests {
    @Test("Text-style markers use exact token boundaries")
    func textStyleMarkersUseExactTokenBoundaries() {
        #expect(textStyle(for: "ios:largeTitle") == .largeTitle)
        #expect(textStyle(for: "ios:title") == .title1)
        #expect(textStyle(for: "ios:title1") == .title1)
        #expect(textStyle(for: "ios:title2") == .title2)
        #expect(textStyle(for: "ios:title3") == .title3)
        #expect(textStyle(for: "ios:headline") == .headline)
        #expect(textStyle(for: "ios:subheadline") == .subheadline)
        #expect(textStyle(for: "ios:callout") == .callout)
        #expect(textStyle(for: "ios:footnote") == .footnote)
        #expect(textStyle(for: "ios:caption") == .caption1)
        #expect(textStyle(for: "ios:caption1") == .caption1)
        #expect(textStyle(for: "ios:caption2") == .caption2)
        #expect(textStyle(for: "prefix ios:title2 suffix") == .title2)
        #expect(textStyle(for: "ios:title20") == .body)
        #expect(textStyle(for: "unmarked") == .body)
    }

#if canImport(AppKit)
    @Test("Resolved theme fonts expose an AppKit font on macOS")
    func themeFontExposesAppKitFont() throws {
        let installedFont = try #require(NSFont(name: "Helvetica", size: 17))
        let themeFont = ThemeFont(
            fontName: installedFont.fontName,
            cascadeFontNames: [],
            fontSize: 17,
            lineHeight: 24,
            letterSpacing: 0,
            textCase: nil,
            textStyle: .body
        )

        let resolved = themeFont.nsFont(for: .large)

        #expect(resolved.fontName == installedFont.fontName)
        #expect(resolved.pointSize == 17)
        #expect(themeFont.lineHeight(for: .large) == 24)
    }
#endif

    @Test("Percentage kerning scales once", arguments: [DynamicTypeSize.large, .accessibility3])
    func percentageKerningScalesOnce(size: DynamicTypeSize) {
        let font = makeFont(style: .body, size: 21.125, spacing: 10)
#if canImport(UIKit)
        let pointSize = font.uiFont(for: size).pointSize
#else
        let pointSize = font.nsFont(for: size).pointSize
#endif
        #expect(abs(font.kerning(for: size) - pointSize * 0.1) < 0.05)
    }

#if canImport(UIKit)
    @Test("Concrete fonts retain each text style's scaling curve in either lookup order", arguments: [false, true])
    func fontCacheSeparatesTextStyles(reverse: Bool) throws {
        // Distinct sizes keep both orders independent of the process-wide caches.
        let size: CGFloat = reverse ? 19.125 : 19.625
        let styles: [(ThemeFontTextStyle, UIFont.TextStyle)] = reverse
            ? [(.caption2, .caption2), (.body, .body)]
            : [(.body, .body), (.caption2, .caption2)]
        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)
        let baseFont = try #require(UIFont(name: "Helvetica", size: size))
        for (style, platformStyle) in styles {
            let font = makeFont(style: style, size: size, spacing: 0)
            let expected = UIFontMetrics(forTextStyle: platformStyle)
                .scaledFont(for: baseFont, compatibleWith: traits)
            #expect(font.uiFont(for: .accessibility3).pointSize == expected.pointSize)
            #expect(font.font(for: .accessibility3) == Font(font.uiFont(for: .accessibility3)))
        }
    }
#endif

    private func makeFont(style: ThemeFontTextStyle, size: CGFloat, spacing: CGFloat) -> ThemeFont {
        ThemeFont(
            fontName: "Helvetica", cascadeFontNames: [], fontSize: size,
            lineHeight: 30, letterSpacing: spacing, textCase: nil, textStyle: style
        )
    }

    private func textStyle(for description: String) -> ThemeFontTextStyle {
        RawFont(
            name: "test",
            group: "test",
            description: description,
            modes: [:]
        ).textStyle
    }
}
