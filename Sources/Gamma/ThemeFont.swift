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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import CoreText
#endif

/// A resolved font from the active theme that scales with Dynamic Type.
///
/// `ThemeFont` carries the font name, size, line height, letter spacing, and
/// text case for a single design token. Obtain one through ``ThemeReader``:
/// `theme.font(.typographyBody)`.
public struct ThemeFont: Hashable {
    private let fontName: String
    private let cascadeFontNames: [String]
    private let baseFontSize: CGFloat
    private let baseLineHeight: CGFloat?
    private let baseLetterSpacing: CGFloat?
    private let textStyle: ThemeFontTextStyle

    let textCase: Text.Case?

    private func fontSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        scaledValue(baseFontSize, for: dynamicTypeSize)
    }

    /// Returns the line height scaled to the given Dynamic Type size.
    public func lineHeight(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        scaledValue(baseLineHeight ?? baseFontSize, for: dynamicTypeSize)
    }

    func lineSpacing(for dynamicTypeSize: DynamicTypeSize) -> CGFloat? {
        guard baseLineHeight != nil else { return nil }
        let candidate = lineHeight(for: dynamicTypeSize) - platformFontLineHeight(for: dynamicTypeSize)
        guard candidate >= 0 else { return nil }
        return candidate
    }

    /// Returns the kerning (letter spacing) scaled to the given Dynamic Type size.
    public func kerning(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        guard let baseLetterSpacing else { return 0 }
        let letterSpacingPercentage = baseLetterSpacing / 100
        return fontSize(for: dynamicTypeSize) * letterSpacingPercentage
    }

    /// Returns the SwiftUI `Font` scaled to the given Dynamic Type size.
    public func font(for dynamicTypeSize: DynamicTypeSize) -> Font {
        font(for: dynamicTypeSize, registrationRevision: 0)
    }

    func font(
        for dynamicTypeSize: DynamicTypeSize,
        registrationRevision: Int
    ) -> Font {
        let cacheKey = ThemeFontCacheKey(
            fontName: fontName,
            cascadeFontNames: cascadeFontNames,
            size: baseFontSize,
            dynamicTypeSize: dynamicTypeSize,
            registrationRevision: registrationRevision,
            textStyle: textStyle
        )

        if let cached = ThemeProxyCache.swiftUIFontCache[cacheKey] {
            return cached
        }

#if canImport(UIKit)
        let result = Font(uiFont(
            for: dynamicTypeSize,
            registrationRevision: registrationRevision
        ))
#elseif canImport(AppKit)
        let result = Font(nsFont(
            for: dynamicTypeSize,
            registrationRevision: registrationRevision
        ) as CTFont)
#endif
        ThemeProxyCache.swiftUIFontCache[cacheKey] = result
        return result
    }

#if canImport(UIKit)
    /// Returns the `UIFont` scaled to the given Dynamic Type size.
    public func uiFont(for dynamicTypeSize: DynamicTypeSize) -> UIFont {
        uiFont(for: dynamicTypeSize, registrationRevision: 0)
    }

    private func uiFont(
        for dynamicTypeSize: DynamicTypeSize,
        registrationRevision: Int
    ) -> UIFont {
        let cacheKey = ThemeFontCacheKey(
            fontName: fontName,
            cascadeFontNames: cascadeFontNames,
            size: baseFontSize,
            dynamicTypeSize: dynamicTypeSize,
            registrationRevision: registrationRevision,
            textStyle: textStyle
        )

        if let cached = ThemeProxyCache.uiFontCache[cacheKey] {
            return cached
        }

        let traitCollection = UITraitCollection(
            preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory
        )
        let descriptor = UIFontDescriptor(name: fontName, size: baseFontSize)
        let combinedDescriptor = descriptor.addingAttributes([
            .cascadeList: cascadeFontNames.map {
                UIFontDescriptor(name: $0, size: baseFontSize)
            }.compactMap(\.self)
        ])
        let baseFont = UIFont(descriptor: combinedDescriptor, size: baseFontSize)
        let result = UIFontMetrics(forTextStyle: textStyle.uiTextStyle)
            .scaledFont(for: baseFont, compatibleWith: traitCollection)

        ThemeProxyCache.uiFontCache[cacheKey] = result
        return result
    }
#elseif canImport(AppKit)
    /// Returns the `NSFont` scaled to the given Dynamic Type size.
    public func nsFont(for dynamicTypeSize: DynamicTypeSize) -> NSFont {
        nsFont(for: dynamicTypeSize, registrationRevision: 0)
    }

    private func nsFont(
        for dynamicTypeSize: DynamicTypeSize,
        registrationRevision: Int
    ) -> NSFont {
        let cacheKey = ThemeFontCacheKey(
            fontName: fontName,
            cascadeFontNames: cascadeFontNames,
            size: baseFontSize,
            dynamicTypeSize: dynamicTypeSize,
            registrationRevision: registrationRevision,
            textStyle: textStyle
        )

        if let cached = ThemeProxyCache.nsFontCache[cacheKey] {
            return cached
        }

        let size = fontSize(for: dynamicTypeSize)
        let descriptor = NSFontDescriptor(name: fontName, size: size)
        let combinedDescriptor = descriptor.addingAttributes([
            .cascadeList: cascadeFontNames.map {
                NSFontDescriptor(name: $0, size: size)
            },
        ])
        let result = NSFont(descriptor: combinedDescriptor, size: size)
            ?? NSFont(name: fontName, size: size)
            ?? .systemFont(ofSize: size)

        ThemeProxyCache.nsFontCache[cacheKey] = result
        return result
    }
#endif

    /// Returns an `AttributeContainer` with the font, kerning, and line height applied for the given Dynamic Type size.
    public func attributes(for dynamicTypeSize: DynamicTypeSize) -> AttributeContainer {
        var container = AttributeContainer()
        container.font = font(for: dynamicTypeSize)
        container.kern = kerning(for: dynamicTypeSize)
        if #available(iOS 26, macOS 26, *) {
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
        textStyle: ThemeFontTextStyle
    ) {
        self.fontName = fontName
        self.cascadeFontNames = cascadeFontNames
        self.baseFontSize = fontSize
        self.baseLineHeight = lineHeight
        self.baseLetterSpacing = letterSpacing
        self.textCase = textCase
        self.textStyle = textStyle
    }

#if canImport(UIKit)
    static let fallback: Self = ThemeFont(
        fontName: UIFont.preferredFont(forTextStyle: .body).fontName,
        cascadeFontNames: [],
        fontSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
        lineHeight: nil,
        letterSpacing: nil,
        textCase: nil,
        textStyle: .body
    )
#elseif canImport(AppKit)
    static let fallback: Self = {
        let font = NSFont.preferredFont(forTextStyle: .body, options: [:])
        return ThemeFont(
            fontName: font.fontName,
            cascadeFontNames: [],
            fontSize: font.pointSize,
            lineHeight: nil,
            letterSpacing: nil,
            textCase: nil,
            textStyle: .body
        )
    }()
#endif

    private func scaledValue(
        _ value: CGFloat,
        for dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
#if canImport(UIKit)
        let traits = UITraitCollection(
            preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory
        )
        return UIFontMetrics(forTextStyle: textStyle.uiTextStyle)
            .scaledValue(for: value, compatibleWith: traits)
#elseif canImport(AppKit)
        value * dynamicTypeSize.gammaScaleFactor
#endif
    }

    private func platformFontLineHeight(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
#if canImport(UIKit)
        uiFont(for: dynamicTypeSize).lineHeight
#elseif canImport(AppKit)
        let font = nsFont(for: dynamicTypeSize)
        return font.ascender - font.descender + font.leading
#endif
    }
}

#if canImport(UIKit)
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

private extension ThemeFontTextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title1: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption1: .caption1
        case .caption2: .caption2
        }
    }
}
#elseif canImport(AppKit)
private extension DynamicTypeSize {
    var gammaScaleFactor: CGFloat {
        switch self {
        case .xSmall: 14 / 17
        case .small: 15 / 17
        case .medium: 16 / 17
        case .large: 1
        case .xLarge: 19 / 17
        case .xxLarge: 21 / 17
        case .xxxLarge: 23 / 17
        case .accessibility1: 28 / 17
        case .accessibility2: 33 / 17
        case .accessibility3: 40 / 17
        case .accessibility4: 47 / 17
        case .accessibility5: 53 / 17
        @unknown default: 1
        }
    }
}
#endif
