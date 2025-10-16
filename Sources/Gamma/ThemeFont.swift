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

import SwiftUI

/// A resolved font from the active theme that scales with Dynamic Type.
///
/// `ThemeFont` carries the font name, size, line height, letter spacing, and
/// text case for a single design token. Obtain one through ``ThemeReader``:
/// `theme.font(.fontBody)`.
public struct ThemeFont: Hashable {
    private let fontName: String
    private let cascadeFontNames: [String]
    private let baseFontSize: CGFloat
    private let baseLineHeight: CGFloat?
    private let baseLetterSpacing: CGFloat?
    private let metrics: UIFontMetrics

    let textCase: Text.Case?

    private func traitCollection(for dynamicTypeSize: DynamicTypeSize) -> UITraitCollection {
        UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory)
    }

    private func fontSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        metrics.scaledValue(for: baseFontSize, compatibleWith: traitCollection(for: dynamicTypeSize))
    }

    /// Returns the line height scaled to the given Dynamic Type size.
    public func lineHeight(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        metrics.scaledValue(for: baseLineHeight ?? baseFontSize, compatibleWith: traitCollection(for: dynamicTypeSize))
    }

    private func letterSpacing(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        metrics.scaledValue(for: baseLetterSpacing ?? 0, compatibleWith: traitCollection(for: dynamicTypeSize))
    }

    func lineSpacing(for dynamicTypeSize: DynamicTypeSize) -> CGFloat? {
        guard baseLineHeight != nil else { return nil }
        let candidate = lineHeight(for: dynamicTypeSize) - uiFont(for: dynamicTypeSize).lineHeight
        guard candidate >= 0 else { return nil }
        return candidate
    }

    /// Returns the kerning (letter spacing) scaled to the given Dynamic Type size.
    public func kerning(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        guard baseLetterSpacing != nil else { return 0 }
        let letterSpacingPercentage = letterSpacing(for: dynamicTypeSize) / 100
        return fontSize(for: dynamicTypeSize) * letterSpacingPercentage
    }

    /// Returns the SwiftUI `Font` scaled to the given Dynamic Type size.
    public func font(for dynamicTypeSize: DynamicTypeSize) -> Font {
        let cacheKey = ThemeFontCacheKey(
            fontName: fontName,
            cascadeFontNames: cascadeFontNames,
            size: baseFontSize,
            dynamicTypeSize: dynamicTypeSize
        )

        if let cached = ThemeProxyCache.swiftUIFontCache[cacheKey] {
            return cached
        }

        let result = Font(uiFont(for: dynamicTypeSize))
        ThemeProxyCache.swiftUIFontCache[cacheKey] = result
        return result
    }

    /// Returns the `UIFont` scaled to the given Dynamic Type size.
    public func uiFont(for dynamicTypeSize: DynamicTypeSize) -> UIFont {
        let cacheKey = ThemeFontCacheKey(
            fontName: fontName,
            cascadeFontNames: cascadeFontNames,
            size: baseFontSize,
            dynamicTypeSize: dynamicTypeSize
        )

        if let cached = ThemeProxyCache.uiFontCache[cacheKey] {
            return cached
        }

        let traitCollection = traitCollection(for: dynamicTypeSize)
        let descriptor = UIFontDescriptor(name: fontName, size: baseFontSize)
        let combinedDescriptor = descriptor.addingAttributes([
            .cascadeList: cascadeFontNames.map {
                UIFontDescriptor(name: $0, size: baseFontSize)
            }.compactMap(\.self)
        ])
        let baseFont = UIFont(descriptor: combinedDescriptor, size: baseFontSize)
        let result = metrics.scaledFont(for: baseFont, compatibleWith: traitCollection)

        ThemeProxyCache.uiFontCache[cacheKey] = result
        return result
    }

    /// Returns an `AttributeContainer` with the font, kerning, and line height applied for the given Dynamic Type size.
    public func attributes(for dynamicTypeSize: DynamicTypeSize) -> AttributeContainer {
        var container = AttributeContainer()
        container.font = font(for: dynamicTypeSize)
        container.kern = kerning(for: dynamicTypeSize)
        if #available(iOS 26, *) {
            container.lineHeight = .exact(points: lineHeight(for: dynamicTypeSize))
        }
        return container
    }

    init(
        fontName: String,
        cascadeFontNames: [String],
        fontSize: CGFloat,
        lineHeight: CGFloat?,
        letterSpacing: CGFloat?,
        textCase: Text.Case?,
        textStyle: UIFont.TextStyle
    ) {
        self.fontName = fontName
        self.cascadeFontNames = cascadeFontNames
        self.baseFontSize = fontSize
        self.baseLineHeight = lineHeight
        self.baseLetterSpacing = letterSpacing
        self.textCase = textCase
        self.metrics = UIFontMetrics(forTextStyle: textStyle)
    }

    static let fallback: Self = ThemeFont(
        fontName: UIFont.preferredFont(forTextStyle: .body).fontName,
        cascadeFontNames: [],
        fontSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
        lineHeight: nil,
        letterSpacing: nil,
        textCase: nil,
        textStyle: .body
    )
}

private extension DynamicTypeSize {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}
