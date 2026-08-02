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

struct AppearanceModesExample: View {
    @State private var appearance: SampleAppearance

    init(initiallyDark: Bool = false) {
        _appearance = State(initialValue: initiallyDark ? .dark : .light)
    }

    var body: some View {
        SamplePage(
            scenario: .appearanceModes,
            explanation: "The resolver maps SwiftUI appearance to the theme's day and night modes. The view keeps using the same generated aliases.",
            screenIdentifier: SampleAppAccessibility.appearanceScreen
        ) {
            Picker("Appearance", selection: $appearance) {
                ForEach(SampleAppearance.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(SampleAppAccessibility.appearancePicker)

            AppearancePreview()
                .environment(\.colorScheme, appearance.colorScheme)
        }
    }
}

private struct AppearancePreview: View {
    @ThemeReader private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
            SampleStatusBadge(
                text: colorScheme == .dark ? "Dark appearance → night modes" : "Light appearance → day modes",
                systemImage: colorScheme == .dark ? "moon.stars.fill" : "sun.max.fill",
                identifier: SampleAppAccessibility.appearanceStatus
            )

            HStack(spacing: theme.unit(.spacingSmall)) {
                SampleColorSwatch(name: "Accent", alias: .brandAccent)
                SampleColorSwatch(name: "Surface", alias: .surfaceSurface)
                SampleColorSwatch(name: "Text", alias: .textPrimary)
            }
            .accessibilityIdentifier(SampleAppAccessibility.appearancePalette)

            RoundedRectangle(cornerRadius: theme.unit(.radiusCard))
                .fill(theme.gradient(.brandHero))
                .frame(height: 156)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        DSText("Custom gradient family")
                            .font(theme.font(.typographyBody))
                        DSText("Theme.Gradients.BrandAlias.brandHero")
                            .font(theme.font(.typographyCaption))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                    .padding(theme.unit(.spacingMedium))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(SampleAppAccessibility.appearanceGradient)
        }
        .padding(theme.unit(.spacingMedium))
        .background(theme.color(.surfaceSurface))
        .clipShape(RoundedRectangle(cornerRadius: theme.unit(.radiusCard)))
    }
}

private enum SampleAppearance: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme { self == .dark ? .dark : .light }
}
