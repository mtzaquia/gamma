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

struct ScopedOverridesExample: View {
    @ThemeReader private var theme
    @State private var overrideIsActive: Bool

    init(initiallyActive: Bool = false) {
        _overrideIsActive = State(initialValue: initiallyActive)
    }

    var body: some View {
        SamplePage(
            scenario: .scopedOverrides,
            explanation: "A campaign can replace selected token modes inside one subtree while the base theme remains active everywhere else.",
            screenIdentifier: SampleAppAccessibility.overridesScreen
        ) {
            SampleCard {
                Toggle("Apply campaign override", isOn: $overrideIsActive)
                    .font(theme.font(.typographyBody))
                    .tint(theme.color(.brandAccent))
                    .accessibilityIdentifier(SampleAppAccessibility.overridesToggle)

                SampleStatusBadge(
                    text: overrideIsActive ? "Scoped override active" : "Scoped override inactive",
                    systemImage: overrideIsActive ? "checkmark.circle.fill" : "circle.dashed",
                    identifier: SampleAppAccessibility.overridesStatus
                )
                .padding(.top, theme.unit(.spacingSmall))
            }

            VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                DSText("Outside the scope")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(theme.color(.textSecondary))
                CampaignCard(
                    label: "Base theme",
                    accessibilityIdentifier: SampleAppAccessibility.overridesBase
                )
            }

            VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                DSText("Inside the scope")
                    .font(theme.font(.typographyCaption))
                    .foregroundStyle(theme.color(.textSecondary))

                if overrideIsActive {
                    WithThemeOverrides(overrides: SampleTheme.campaignOverrides) {
                        CampaignCard(
                            label: "Campaign override",
                            accessibilityIdentifier: SampleAppAccessibility.overridesActive
                        )
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(SampleAppAccessibility.overridesActive)
                } else {
                    CampaignCard(
                        label: "Base theme repeated",
                        accessibilityIdentifier: SampleAppAccessibility.overridesInactive
                    )
                }
            }
        }
    }
}

private struct CampaignCard: View {
    @ThemeReader private var theme
    let label: String
    let accessibilityIdentifier: String

    var body: some View {
        RoundedRectangle(cornerRadius: theme.unit(.radiusCard))
            .fill(theme.gradient(.brandHero))
            .frame(height: 144)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    DSText(label)
                        .font(theme.font(.typographyBody))
                        .accessibilityIdentifier(accessibilityIdentifier)
                    DSText("Accent, radius, and gradient resolve here")
                        .font(theme.font(.typographyCaption))
                }
                .foregroundStyle(.white)
                .padding(theme.unit(.spacingMedium))
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(theme.color(.brandAccent))
                    .frame(width: theme.unit(.spacingLarge), height: theme.unit(.spacingLarge))
                    .padding(theme.unit(.spacingSmall))
            }
    }
}
