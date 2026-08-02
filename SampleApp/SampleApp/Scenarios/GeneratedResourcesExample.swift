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

struct GeneratedResourcesExample: View {
    @State private var resource: SampleResource

    init(initiallyShowingIllustration: Bool = false) {
        _resource = State(initialValue: initiallyShowingIllustration ? .illustration : .icon)
    }

    var body: some View {
        SamplePage(
            scenario: .generatedResources,
            explanation: "Gamma's build plug-in generates a bundled theme handle, grouped token aliases, and typed asset aliases from the target's theme and asset catalogue.",
            screenIdentifier: SampleAppAccessibility.resourcesScreen
        ) {
            Picker("Generated resource", selection: $resource) {
                ForEach(SampleResource.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(SampleAppAccessibility.resourcesPicker)

            ResourcePreview(resource: resource)
        }
    }
}

private struct ResourcePreview: View {
    @ThemeReader private var theme
    let resource: SampleResource

    var body: some View {
        SampleCard {
            VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
                SampleStatusBadge(
                    text: resource.aliasDescription,
                    systemImage: "curlybraces.square",
                    identifier: SampleAppAccessibility.resourcesStatus
                )

                Group {
                    switch resource {
                    case .icon:
                        let icon: Theme.IconAlias = .themeSpark
                        Image(icon.rawValue, bundle: icon.bundle)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(theme.color(.brandAccent))
                            .padding(theme.unit(.spacingLarge))
                            .accessibilityLabel("Generated theme spark icon")
                            .accessibilityIdentifier(SampleAppAccessibility.resourcesIcon)

                    case .illustration:
                        let illustration: Theme.AssetAlias<IllustrationAsset> = .tokenFlow
                        Image(illustration.rawValue, bundle: illustration.bundle)
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel("Generated token flow illustration")
                            .accessibilityIdentifier(SampleAppAccessibility.resourcesIllustration)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
            }
        }
    }
}

private enum SampleResource: String, CaseIterable, Identifiable {
    case icon
    case illustration

    var id: Self { self }
    var title: String { rawValue.capitalized }

    var aliasDescription: String {
        switch self {
        case .icon: "Theme.IconAlias.themeSpark"
        case .illustration: "Theme.AssetAlias<IllustrationAsset>.tokenFlow"
        }
    }
}
