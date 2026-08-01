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
            LazyVStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                introduction
                directionControls
                colorSection
                gradientSection
                assetsSection
                typographySection
                spacingSection
            }
            .padding(theme.unit(.spacingMedium))
        }
        .background(theme.color(.surfaceBackground).ignoresSafeArea())
        .navigationTitle("Gamma")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(SampleAppAccessibility.showcase)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
            Text("Design tokens, resolved live")
                .font(theme.font(.typographyDisplay))
                .accessibilityIdentifier(SampleAppAccessibility.title)

            DSText("A small catalogue for exploring themes, mode resolution, typography, and responsive units.")
                .font(theme.font(.typographyBody))
                .foregroundStyle(theme.color(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var directionControls: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                SectionTitle("Mode resolver")

                HStack {
                    directionButton("Left to right", direction: .leftToRight)
                    directionButton("Right to left", direction: .rightToLeft)
                }

                Text(statusDescription)
                    .font(theme.font(.typographyBody))
                    .foregroundStyle(theme.color(.textSecondary))
                    .accessibilityIdentifier(SampleAppAccessibility.modeStatus)

                Label(fontRegistrationDescription, systemImage: fontsAreRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(fontsAreRegistered ? theme.color(.brandAccent) : theme.color(.textSecondary))
                    .accessibilityIdentifier(SampleAppAccessibility.fontStatus)
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
            SectionTitle("Colors")
                .accessibilityIdentifier(SampleAppAccessibility.colorsSection)

            HStack(spacing: theme.unit(.spacingSmall)) {
                ColorSwatch(name: "Accent", alias: .brandAccent)
                ColorSwatch(name: "Surface", alias: .surfaceSurface)
                ColorSwatch(name: "Text", alias: .textPrimary)
            }
        }
    }

    private var typographySection: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SectionTitle("Typography")
                    .accessibilityIdentifier(SampleAppAccessibility.typographySection)

                typographyRow("Display", sample: "A coherent visual voice", font: .typographyDisplay)
                typographyRow("Body", sample: "Readable at every Dynamic Type size.", font: .typographyBody)
                typographyRow(
                    "Arabic",
                    sample: "نظام تصميم واحد، تجربة متناسقة.",
                    font: .typographyBody,
                    accessibilityIdentifier: SampleAppAccessibility.arabicSample
                )
                typographyRow("Mixed-script cascade", sample: "Gamma يدعم النص العربي واللاتيني.", font: .typographyBody)
                typographyRow("Caption", sample: "Supporting context", font: .typographyCaption)
            }
        }
    }

    private var gradientSection: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
            SectionTitle("Gradient extension")
                .accessibilityIdentifier(SampleAppAccessibility.gradientsSection)

            RoundedRectangle(cornerRadius: theme.unit(.radiusCard))
                .fill(theme.gradient(.brandHero))
                .frame(height: 132)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Brand hero")
                            .font(theme.font(.typographyDisplay))
                        Text("Resolved through Theme.Gradients.BrandAlias")
                            .font(theme.font(.typographyCaption))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .padding(theme.unit(.spacingMedium))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(SampleAppAccessibility.heroGradient)

            WithThemeOverrides(overrides: SampleTheme.gradientOverrides) {
                OverriddenGradientPreview()
            }
        }
    }

    private var assetsSection: some View {
        let icon: Theme.IconAlias = .themeSpark
        let illustration: Theme.AssetAlias<IllustrationAsset> = .tokenFlow

        return SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SectionTitle("Generated assets")
                    .accessibilityIdentifier(SampleAppAccessibility.assetsSection)

                HStack(spacing: theme.unit(.spacingMedium)) {
                    Image(icon.rawValue, bundle: icon.bundle)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(theme.color(.brandAccent))
                        .frame(width: 52, height: 52)
                        .accessibilityLabel("Generated theme spark icon")
                        .accessibilityIdentifier(SampleAppAccessibility.iconAsset)

                    VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                        DSText("Theme icon")
                            .font(theme.font(.typographyBody))
                        DSText("Loaded through Theme.IconAlias.themeSpark")
                            .font(theme.font(.typographyCaption))
                            .foregroundStyle(theme.color(.textSecondary))
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
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SectionTitle("Responsive units")
                    .accessibilityIdentifier(SampleAppAccessibility.spacingSection)

                unitRow("Small", alias: .spacingSmall)
                unitRow("Medium", alias: .spacingMedium)
                unitRow("Large", alias: .spacingLarge)
            }
        }
    }

    private var statusDescription: String {
        let direction = layoutDirection == .rightToLeft ? "RTL" : "LTR"
        let fontName = theme.font(.typographyBody).uiFont(for: dynamicTypeSize).fontName
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
        .tint(layoutDirection == direction ? theme.color(.brandAccent) : theme.color(.textSecondary))
        .accessibilityIdentifier(
            direction == .rightToLeft
                ? SampleAppAccessibility.rightToLeftButton
                : SampleAppAccessibility.leftToRightButton
        )
    }

    private func typographyRow(
        _ name: String,
        sample: String,
        font: Theme.Fonts.TypographyAlias,
        accessibilityIdentifier: String = ""
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(theme.font(.typographyCaption))
                .foregroundStyle(theme.color(.brandAccent))
            DSText(sample)
                .font(theme.font(font))
                .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private func unitRow<Group: ThemeTokenGroup>(
        _ name: String,
        alias: Theme.Alias<Group>
    ) -> some View where Group.Family == Theme.Units {
        let value = theme.unit(alias)

        return HStack(spacing: theme.unit(.spacingSmall)) {
            Text(name)
                .font(theme.font(.typographyBody))
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.color(.brandAccent))
                .frame(width: value, height: 12)
            Text("\(value.formatted()) pt")
                .font(theme.font(.typographyCaption))
                .foregroundStyle(theme.color(.textSecondary))
                .monospacedDigit()
        }
    }
}

private struct OverriddenGradientPreview: View {
    @ThemeReader private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: theme.unit(.radiusCard))
            .fill(theme.gradient(.brandHero))
            .frame(height: 72)
            .overlay(alignment: .bottomLeading) {
                Text("Scoped gradient override")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(theme.color(.textPrimary))
                    .padding(theme.unit(.spacingSmall))
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(SampleAppAccessibility.overriddenGradient)
    }
}

private struct SampleCard<Content: View>: View {
    @ThemeReader private var theme

    let background: Theme.Colors.SurfaceAlias
    let padding: Theme.Units.SpacingAlias
    let cornerRadius: Theme.Units.RadiusAlias
    @ViewBuilder let content: Content

    init(
        background: Theme.Colors.SurfaceAlias = .surfaceSurface,
        padding: Theme.Units.SpacingAlias = .spacingMedium,
        cornerRadius: Theme.Units.RadiusAlias = .radiusCard,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.unit(padding))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color(background))
            .clipShape(RoundedRectangle(cornerRadius: theme.unit(cornerRadius)))
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
            .font(theme.font(.typographyCaption))
            .foregroundStyle(theme.color(.textSecondary))
    }
}

private struct ColorSwatch<Group: ThemeTokenGroup>: View where Group.Family == Theme.Colors {
    @ThemeReader private var theme
    let name: String
    let alias: Theme.Alias<Group>

    var body: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
            RoundedRectangle(cornerRadius: theme.unit(.spacingSmall))
                .fill(theme.color(alias))
                .frame(height: 72)
            Text(name)
                .font(theme.font(.typographyCaption))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
