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

struct ShowcaseView: View {
    @ThemeReader private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var layoutDirection: LayoutDirection

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.unit(.spaceMedium)) {
                introduction
                directionControls
                colorSection
                assetsSection
                typographySection
                spacingSection
            }
            .padding(theme.unit(.spaceMedium))
        }
        .background(theme.color(.colorBackground).ignoresSafeArea())
        .navigationTitle("Gamma")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(SampleAppAccessibility.showcase)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spaceSmall)) {
            Text("Design tokens, resolved live")
                .font(theme.font(.fontDisplay))
                .accessibilityIdentifier(SampleAppAccessibility.title)

            DSText("A small catalogue for exploring themes, mode resolution, typography, and responsive units.")
                .font(theme.font(.fontBody))
                .foregroundStyle(theme.color(.colorTextSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var directionControls: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spaceSmall)) {
                SectionTitle("Mode resolver")

                HStack {
                    directionButton("Left to right", direction: .leftToRight)
                    directionButton("Right to left", direction: .rightToLeft)
                }

                Text(statusDescription)
                    .font(theme.font(.fontBody))
                    .foregroundStyle(theme.color(.colorTextSecondary))
                    .accessibilityIdentifier(SampleAppAccessibility.modeStatus)

                Label(fontRegistrationDescription, systemImage: fontsAreRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(theme.font(.fontCaption))
                    .foregroundStyle(fontsAreRegistered ? theme.color(.colorAccent) : theme.color(.colorTextSecondary))
                    .accessibilityIdentifier(SampleAppAccessibility.fontStatus)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spaceSmall)) {
            SectionTitle("Colors")
                .accessibilityIdentifier(SampleAppAccessibility.colorsSection)

            HStack(spacing: theme.unit(.spaceSmall)) {
                ColorSwatch(name: "Accent", alias: .colorAccent)
                ColorSwatch(name: "Surface", alias: .colorSurface)
                ColorSwatch(name: "Text", alias: .colorTextPrimary)
            }
        }
    }

    private var typographySection: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spaceMedium)) {
                SectionTitle("Typography")
                    .accessibilityIdentifier(SampleAppAccessibility.typographySection)

                typographyRow("Display", sample: "A coherent visual voice", font: .fontDisplay)
                typographyRow("Body", sample: "Readable at every Dynamic Type size.", font: .fontBody)
                typographyRow(
                    "Arabic",
                    sample: "نظام تصميم واحد، تجربة متناسقة.",
                    font: .fontBody,
                    accessibilityIdentifier: SampleAppAccessibility.arabicSample
                )
                typographyRow("Mixed-script cascade", sample: "Gamma يدعم النص العربي واللاتيني.", font: .fontBody)
                typographyRow("Caption", sample: "Supporting context", font: .fontCaption)
            }
        }
    }

    private var assetsSection: some View {
        let icon: Theme.IconAlias = .themeSpark
        let illustration: Theme.AssetAlias<IllustrationAsset> = .tokenFlow

        return SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spaceMedium)) {
                SectionTitle("Generated assets")
                    .accessibilityIdentifier(SampleAppAccessibility.assetsSection)

                HStack(spacing: theme.unit(.spaceMedium)) {
                    Image(icon.rawValue, bundle: icon.bundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(theme.color(.colorAccent))
                        .frame(width: 52, height: 52)
                        .accessibilityLabel("Generated theme spark icon")
                        .accessibilityIdentifier(SampleAppAccessibility.iconAsset)

                    VStack(alignment: .leading, spacing: theme.unit(.spaceSmall)) {
                        DSText("Theme icon")
                            .font(theme.font(.fontBody))
                        DSText("Loaded through Theme.IconAlias.themeSpark")
                            .font(theme.font(.fontCaption))
                            .foregroundStyle(theme.color(.colorTextSecondary))
                    }
                }

                Image(illustration.rawValue, bundle: illustration.bundle)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("Generated token flow illustration")
                    .accessibilityIdentifier(SampleAppAccessibility.illustrationAsset)
            }
        }
    }

    private var spacingSection: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spaceMedium)) {
                SectionTitle("Responsive units")
                    .accessibilityIdentifier(SampleAppAccessibility.spacingSection)

                unitRow("Small", alias: .spaceSmall)
                unitRow("Medium", alias: .spaceMedium)
                unitRow("Large", alias: .spaceLarge)
            }
        }
    }

    private var statusDescription: String {
        let direction = layoutDirection == .rightToLeft ? "RTL" : "LTR"
        let fontName = theme.font(.fontBody).uiFont(for: dynamicTypeSize).fontName
        let width = horizontalSizeClass == .regular ? "regular units" : "compact units"
        return "\(direction) · \(fontName) primary · \(width)"
    }

    private var fontsAreRegistered: Bool {
        UIFont(name: SampleTheme.latinFontName, size: 17) != nil
            && UIFont(name: SampleTheme.arabicFontName, size: 17) != nil
    }

    private var fontRegistrationDescription: String {
        fontsAreRegistered ? "Bundled Noto fonts registered" : "Bundled font registration failed"
    }

    private func directionButton(_ title: String, direction: LayoutDirection) -> some View {
        Button(title) {
            layoutDirection = direction
        }
        .buttonStyle(.borderedProminent)
        .tint(layoutDirection == direction ? theme.color(.colorAccent) : theme.color(.colorTextSecondary))
        .accessibilityIdentifier(
            direction == .rightToLeft
                ? SampleAppAccessibility.rightToLeftButton
                : SampleAppAccessibility.leftToRightButton
        )
    }

    private func typographyRow(
        _ name: String,
        sample: String,
        font: Theme.FontAlias,
        accessibilityIdentifier: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(theme.font(.fontCaption))
                .foregroundStyle(theme.color(.colorAccent))
            DSText(sample)
                .font(theme.font(font))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private func unitRow<Alias: UnitAlias>(_ name: String, alias: Alias) -> some View {
        let value = theme.unit(alias)

        return HStack(spacing: theme.unit(.spaceSmall)) {
            Text(name)
                .font(theme.font(.fontBody))
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.color(.colorAccent))
                .frame(width: value, height: 12)
            Text("\(value.formatted()) pt")
                .font(theme.font(.fontCaption))
                .foregroundStyle(theme.color(.colorTextSecondary))
                .monospacedDigit()
        }
    }
}

private struct SampleCard<Content: View>: View {
    @ThemeReader private var theme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(theme.unit(.spaceMedium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color(.colorSurface))
            .clipShape(RoundedRectangle(cornerRadius: theme.unit(.radiusCard)))
    }
}

private struct SectionTitle: View {
    @ThemeReader private var theme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(theme.font(.fontCaption))
            .foregroundStyle(theme.color(.colorTextSecondary))
    }
}

private struct ColorSwatch: View {
    @ThemeReader private var theme
    let name: String
    let alias: Theme.ColorAlias

    var body: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spaceSmall)) {
            RoundedRectangle(cornerRadius: theme.unit(.spaceSmall))
                .fill(theme.color(alias))
                .frame(height: 72)
            Text(name)
                .font(theme.font(.fontCaption))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
