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

struct ResponsiveUnitsExample: View {
    @State private var widthProfile: SampleWidthProfile

    init(initiallyRegular: Bool = false) {
        _widthProfile = State(initialValue: initiallyRegular ? .regular : .compact)
    }

    var body: some View {
        SamplePage(
            scenario: .responsiveUnits,
            explanation: "The resolver maps horizontal size class to compact or regular unit modes. Components keep their spacing and radius aliases unchanged.",
            screenIdentifier: SampleAppAccessibility.unitsScreen
        ) {
            Picker("Width profile", selection: $widthProfile) {
                ForEach(SampleWidthProfile.allCases) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(SampleAppAccessibility.unitsPicker)

            ResponsiveUnitsPreview()
                .environment(\.horizontalSizeClass, widthProfile.sizeClass)
        }
    }
}

private struct ResponsiveUnitsPreview: View {
    @ThemeReader private var theme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SampleStatusBadge(
                    text: statusDescription,
                    systemImage: "ruler",
                    identifier: SampleAppAccessibility.unitsStatus
                )

                unitRow("Small", alias: .spacingSmall)
                unitRow("Medium", alias: .spacingMedium)
                unitRow("Large", alias: .spacingLarge)

                DSText("This card's padding and corners use the same selected mode.")
                    .font(theme.font(.typographyBody))
                    .padding(theme.unit(.spacingMedium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.color(.brandAccent).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: theme.unit(.radiusCard)))
                    .accessibilityIdentifier(SampleAppAccessibility.unitsPreview)
            }
        }
    }

    private var statusDescription: String {
        let profile = horizontalSizeClass == .regular ? "Regular" : "Compact"
        let values = [
            theme.unit(.spacingSmall),
            theme.unit(.spacingMedium),
            theme.unit(.spacingLarge),
        ]
        .map { $0.formatted() }
        .joined(separator: " / ")
        return "\(profile) → \(values) pt"
    }

    private func unitRow<Scope: ThemeAliasScope>(
        _ name: String,
        alias: Theme.Alias<Scope>
    ) -> some View where Scope.Family == Theme.Units {
        let value = theme.unit(alias)

        return HStack(spacing: theme.unit(.spacingSmall)) {
            DSText(name)
                .font(theme.font(.typographyBody))
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.color(.brandAccent))
                .frame(width: value, height: 12)
            DSText("\(value.formatted()) pt")
                .font(theme.font(.typographyCaption))
                .foregroundStyle(theme.color(.textSecondary))
                .monospacedDigit()
        }
    }
}

private enum SampleWidthProfile: String, CaseIterable, Identifiable {
    case compact
    case regular

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var sizeClass: UserInterfaceSizeClass { self == .regular ? .regular : .compact }
}
