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

struct CatalogView: View {
    @ThemeReader private var theme

    var body: some View {
        List {
            Section {
                introduction
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
            }

            Section("Explore Gamma") {
                ForEach(SampleScenario.allCases) { scenario in
                    NavigationLink {
                        ScenarioDestination(scenario: scenario)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                DSText(scenario.title)
                                    .font(theme.font(.typographyBody))
                                DSText(scenario.subtitle)
                                    .font(theme.font(.typographyCaption))
                                    .foregroundStyle(theme.color(.textSecondary))
                            }
                        } icon: {
                            Image(systemName: scenario.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(theme.color(.brandAccent))
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier(SampleAppAccessibility.scenarioLink(scenario))
                }
            }

            Section("What this app proves") {
                Label("Environment-driven modes", systemImage: "switch.2")
                Label("Generated tokens and assets", systemImage: "curlybraces.square")
                Label("Registered fonts and script cascades", systemImage: "textformat")
                Label("Typed extensions and scoped overrides", systemImage: "scope")
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.color(.surfaceBackground).ignoresSafeArea())
        .navigationTitle("Gamma")
        .accessibilityIdentifier(SampleAppAccessibility.catalog)
    }

    private var introduction: some View {
        let icon: Theme.IconAlias = .themeSpark

        return VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
            HStack(alignment: .top, spacing: theme.unit(.spacingMedium)) {
                Image(icon.rawValue, bundle: icon.bundle)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: theme.unit(.spacingSmall)) {
                    DSText("Design tokens, resolved live")
                        .font(theme.font(.typographyDisplay))
                        .accessibilityIdentifier(SampleAppAccessibility.catalogTitle)
                    DSText("Five focused experiments connect Gamma's public API to an outcome you can see.")
                        .font(theme.font(.typographyBody))
                }
            }
            .foregroundStyle(.white)
            .padding(theme.unit(.spacingMedium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.gradient(.brandHero))
        .clipShape(RoundedRectangle(cornerRadius: theme.unit(.radiusCard)))
        .padding(.bottom, theme.unit(.spacingSmall))
    }
}
