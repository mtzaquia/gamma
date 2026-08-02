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

struct SamplePage<Content: View>: View {
    @ThemeReader private var theme

    let scenario: SampleScenario
    let explanation: String
    let screenIdentifier: String
    @ViewBuilder let content: Content

    init(
        scenario: SampleScenario,
        explanation: String,
        screenIdentifier: String,
        @ViewBuilder content: () -> Content
    ) {
        self.scenario = scenario
        self.explanation = explanation
        self.screenIdentifier = screenIdentifier
        self.content = content()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                    DSText(scenario.title)
                        .font(theme.font(.typographyDisplay))
                    DSText(explanation)
                        .font(theme.font(.typographyBody))
                        .foregroundStyle(theme.color(.textSecondary))
                }

                content
            }
            .padding(theme.unit(.spacingMedium))
        }
        .background(theme.color(.surfaceBackground).ignoresSafeArea())
        .navigationTitle(scenario.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(screenIdentifier)
    }
}

struct SampleCard<Content: View>: View {
    @ThemeReader private var theme

    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.unit(.spacingMedium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.color(.surfaceSurface))
            .clipShape(RoundedRectangle(cornerRadius: theme.unit(.radiusCard)))
    }
}

struct SampleStatusBadge: View {
    @ThemeReader private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let text: String
    let systemImage: String
    let identifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: theme.unit(.spacingSmall)) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            DSText(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(theme.font(.typographyCaption))
        .foregroundStyle(theme.color(.brandAccent))
        .padding(.horizontal, theme.unit(.spacingSmall))
        .padding(.vertical, 6)
        .background(
            theme.color(.brandAccent).opacity(0.12),
            in: RoundedRectangle(cornerRadius: theme.unit(.spacingSmall))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
        .accessibilityIdentifier(identifier)
    }
}

struct SampleColorSwatch<Scope: ThemeAliasScope>: View where Scope.Family == Theme.Colors {
    @ThemeReader private var theme

    let name: String
    let alias: Theme.Alias<Scope>

    var body: some View {
        VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
            RoundedRectangle(cornerRadius: theme.unit(.spacingSmall))
                .fill(theme.color(alias))
                .frame(height: 76)
            DSText(name)
                .font(theme.font(.typographyCaption))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
