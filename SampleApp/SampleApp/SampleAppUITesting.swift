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
import UIKit

enum SampleScenario: String, CaseIterable, Identifiable {
    case appearanceModes = "appearance-modes"
    case adaptiveTypography = "adaptive-typography"
    case responsiveUnits = "responsive-units"
    case scopedOverrides = "scoped-overrides"
    case generatedResources = "generated-resources"

    var id: Self { self }

    var title: String {
        switch self {
        case .appearanceModes: "Palette follows appearance"
        case .adaptiveTypography: "Type fits every reader"
        case .responsiveUnits: "Spacing fits the canvas"
        case .scopedOverrides: "Restyle one subtree"
        case .generatedResources: "Resources stay type-safe"
        }
    }

    var subtitle: String {
        switch self {
        case .appearanceModes:
            "Switch light and dark context while colors and a custom gradient resolve in place."
        case .adaptiveTypography:
            "Change writing direction and text size to see registered faces, cascades, and metrics adapt."
        case .responsiveUnits:
            "Compare compact and regular spacing without changing the token aliases used by the view."
        case .scopedOverrides:
            "Apply color, radius, and gradient replacements inside one view subtree."
        case .generatedResources:
            "Select artwork loaded through generated icon and illustration aliases."
        }
    }

    var systemImage: String {
        switch self {
        case .appearanceModes: "circle.lefthalf.filled"
        case .adaptiveTypography: "character.book.closed"
        case .responsiveUnits: "rectangle.3.group"
        case .scopedOverrides: "paintbrush.pointed"
        case .generatedResources: "shippingbox"
        }
    }
}

struct ScenarioDestination: View {
    let scenario: SampleScenario

    var body: some View {
        switch scenario {
        case .appearanceModes:
            AppearanceModesExample(initiallyDark: SampleAppUITesting.appearanceIsInitiallyDark)
        case .adaptiveTypography:
            AdaptiveTypographyExample(
                initiallyRightToLeft: SampleAppUITesting.typographyIsInitiallyRightToLeft,
                initiallyAccessibilitySized: SampleAppUITesting.typographyIsInitiallyAccessibilitySized
            )
        case .responsiveUnits:
            ResponsiveUnitsExample(initiallyRegular: SampleAppUITesting.unitsAreInitiallyRegular)
        case .scopedOverrides:
            ScopedOverridesExample(initiallyActive: SampleAppUITesting.overrideIsInitiallyActive)
        case .generatedResources:
            GeneratedResourcesExample(initiallyShowingIllustration: SampleAppUITesting.resourceIsInitiallyIllustration)
        }
    }
}

enum SampleAppUITesting {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    static let initialScenario: SampleScenario? = {
        guard isEnabled else { return nil }
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("--scenario=") })
            .flatMap { SampleScenario(rawValue: String($0.dropFirst("--scenario=".count))) }
    }()

    static let overrideIsInitiallyActive = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--overrides=active")
    static let appearanceIsInitiallyDark = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--appearance=dark")
    static let typographyIsInitiallyRightToLeft = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--direction=rtl")
    static let typographyIsInitiallyAccessibilitySized = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--type-size=accessibility")
    static let unitsAreInitiallyRegular = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--width=regular")
    static let resourceIsInitiallyIllustration = isEnabled
        && ProcessInfo.processInfo.arguments.contains("--resource=illustration")

    @MainActor
    static func configure() {
        guard isEnabled else { return }
        UIView.setAnimationsEnabled(false)
    }
}

enum SampleAppAccessibility {
    static let catalog = "sample.catalog"
    static let catalogTitle = "sample.catalog.title"
    static func scenarioLink(_ scenario: SampleScenario) -> String {
        "sample.catalog.\(scenario.rawValue)"
    }

    static let appearanceScreen = "sample.appearance.screen"
    static let appearancePicker = "sample.appearance.picker"
    static let appearanceStatus = "sample.appearance.status"
    static let appearancePalette = "sample.appearance.palette"
    static let appearanceGradient = "sample.appearance.gradient"

    static let typographyScreen = "sample.typography.screen"
    static let typographyDirectionPicker = "sample.typography.direction"
    static let typographySizePicker = "sample.typography.size"
    static let typographyStatus = "sample.typography.status"
    static let typographyFontStatus = "sample.typography.font-status"
    static let typographySample = "sample.typography.sample"

    static let unitsScreen = "sample.units.screen"
    static let unitsPicker = "sample.units.picker"
    static let unitsStatus = "sample.units.status"
    static let unitsPreview = "sample.units.preview"

    static let overridesScreen = "sample.overrides.screen"
    static let overridesToggle = "sample.overrides.toggle"
    static let overridesStatus = "sample.overrides.status"
    static let overridesBase = "sample.overrides.base"
    static let overridesInactive = "sample.overrides.inactive"
    static let overridesActive = "sample.overrides.active"

    static let resourcesScreen = "sample.resources.screen"
    static let resourcesPicker = "sample.resources.picker"
    static let resourcesStatus = "sample.resources.status"
    static let resourcesIcon = "sample.resources.icon"
    static let resourcesIllustration = "sample.resources.illustration"
}
