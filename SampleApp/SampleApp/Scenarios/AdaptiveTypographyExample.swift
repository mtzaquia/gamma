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

import Gamma
import SwiftUI
import UIKit

struct AdaptiveTypographyExample: View {
    @State private var direction: SampleWritingDirection
    @State private var typeSize: SampleTypeSize

    init(
        initiallyRightToLeft: Bool = false,
        initiallyAccessibilitySized: Bool = false
    ) {
        _direction = State(initialValue: initiallyRightToLeft ? .rightToLeft : .leftToRight)
        _typeSize = State(initialValue: initiallyAccessibilitySized ? .accessibility : .standard)
    }

    var body: some View {
        SamplePage(
            scenario: .adaptiveTypography,
            explanation: "Gamma registers app-supplied fonts, lets the resolver choose a primary face and cascade, and scales the token's metrics with Dynamic Type.",
            screenIdentifier: SampleAppAccessibility.typographyScreen
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Writing direction").font(.caption).foregroundStyle(.secondary)
                Picker("Writing direction", selection: $direction) {
                    ForEach(SampleWritingDirection.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(SampleAppAccessibility.typographyDirectionPicker)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Dynamic Type").font(.caption).foregroundStyle(.secondary)
                Picker("Dynamic Type", selection: $typeSize) {
                    ForEach(SampleTypeSize.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(SampleAppAccessibility.typographySizePicker)
            }

            TypographyPreview(typeSizeTitle: typeSize.title)
                .environment(\.layoutDirection, direction.layoutDirection)
                .environment(\.dynamicTypeSize, typeSize.dynamicTypeSize)
        }
    }
}

private struct TypographyPreview: View {
    @ThemeReader private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection

    let typeSizeTitle: String

    var body: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SampleStatusBadge(
                    text: statusDescription,
                    systemImage: "textformat.size",
                    identifier: SampleAppAccessibility.typographyStatus
                )

                Label(fontRegistrationDescription, systemImage: fontsAreRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(fontsAreRegistered ? theme.color(.brandAccent) : theme.color(.textSecondary))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: fontRegistrationDescription))
                    .accessibilityIdentifier(SampleAppAccessibility.typographyFontStatus)

                DSText("A coherent visual voice")
                    .font(theme.font(.typographyDisplay))

                DSText("Gamma يدعم النص العربي واللاتيني في السطر نفسه.")
                    .font(theme.font(.typographyBody))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(SampleAppAccessibility.typographySample)

                DSText("The other registered face remains available as a cascade.")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(theme.color(.textSecondary))
            }
        }
    }

    private var statusDescription: String {
        let direction = layoutDirection == .rightToLeft ? "RTL" : "LTR"
        let fontName = theme.font(.typographyBody).uiFont(for: dynamicTypeSize).fontName
        return "\(direction) · \(fontName) · \(typeSizeTitle)"
    }

    private var fontsAreRegistered: Bool {
        UIFont(name: SampleTheme.latinFontName, size: 17) != nil
            && UIFont(name: SampleTheme.arabicFontName, size: 17) != nil
    }

    private var fontRegistrationDescription: String {
        fontsAreRegistered ? "Bundled Noto faces registered" : "Bundled font registration failed"
    }
}

private enum SampleWritingDirection: String, CaseIterable, Identifiable {
    case leftToRight
    case rightToLeft

    var id: Self { self }
    var title: String { self == .leftToRight ? "Left to right" : "Right to left" }
    var layoutDirection: LayoutDirection { self == .leftToRight ? .leftToRight : .rightToLeft }
}

private enum SampleTypeSize: String, CaseIterable, Identifiable {
    case standard
    case accessibility

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var dynamicTypeSize: DynamicTypeSize { self == .standard ? .large : .accessibility2 }
}
