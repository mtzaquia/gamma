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

import XCTest

nonisolated final class SampleAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    @MainActor
    func testCatalogListsEveryScenario() {
        launch()

        XCTAssertTrue(element(A11y.catalog).waitForExistence(timeout: 3))
        XCTAssertTrue(element(A11y.catalogTitle).waitForExistence(timeout: 3))
        for scenario in Scenario.allCases {
            XCTAssertTrue(scrollUntilVisible(element(A11y.scenarioLink(scenario))))
        }
    }

    @MainActor
    func testAppearanceModesResolveDayAndNight() {
        launch(.appearanceModes)

        XCTAssertTrue(element(A11y.appearanceScreen).waitForExistence(timeout: 3))
        let status = element(A11y.appearanceStatus)
        XCTAssertTrue(waitForLabelContaining("Light appearance → day modes", on: status))
        XCTAssertTrue(element(A11y.appearanceGradient).exists)

        app.segmentedControls[A11y.appearancePicker].buttons["Dark"].tap()

        XCTAssertTrue(waitForLabelContaining("Dark appearance → night modes", on: status))
        XCTAssertTrue(element(A11y.appearancePalette).exists)
    }

    @MainActor
    func testTypographyAdaptsToDirectionAndDynamicType() {
        launch(.adaptiveTypography)

        XCTAssertTrue(element(A11y.typographyScreen).waitForExistence(timeout: 3))
        let status = element(A11y.typographyStatus)
        XCTAssertTrue(waitForLabelContaining("LTR · NotoSans-Regular · Standard", on: status))
        XCTAssertTrue(waitForLabelContaining("registered", on: element(A11y.typographyFontStatus)))
        XCTAssertTrue(element(A11y.typographySample).exists)

        app.segmentedControls[A11y.typographyDirectionPicker].buttons["Right to left"].tap()
        XCTAssertTrue(waitForLabelContaining("RTL · NotoSansArabic-Regular", on: status))

        app.segmentedControls[A11y.typographySizePicker].buttons["Accessibility"].tap()
        XCTAssertTrue(waitForLabelContaining("Accessibility", on: status))
    }

    @MainActor
    func testResponsiveUnitsResolveCompactAndRegularValues() {
        launch(.responsiveUnits)

        XCTAssertTrue(element(A11y.unitsScreen).waitForExistence(timeout: 3))
        let status = element(A11y.unitsStatus)
        XCTAssertTrue(waitForLabelContaining("Compact → 8 / 16 / 24 pt", on: status))
        XCTAssertTrue(element(A11y.unitsPreview).exists)

        app.segmentedControls[A11y.unitsPicker].buttons["Regular"].tap()

        XCTAssertTrue(waitForLabelContaining("Regular → 12 / 24 / 36 pt", on: status))
    }

    @MainActor
    func testScopedOverrideCanBeAppliedAndRemoved() {
        launch(.scopedOverrides)

        XCTAssertTrue(element(A11y.overridesScreen).waitForExistence(timeout: 3))
        XCTAssertTrue(element(A11y.overridesBase).exists)
        XCTAssertTrue(element(A11y.overridesInactive).exists)
        let status = element(A11y.overridesStatus)
        XCTAssertTrue(waitForLabelContaining("inactive", on: status))

        let toggle = app.switches[A11y.overridesToggle]
        toggle.tap()

        XCTAssertTrue(waitForLabelContaining("active", on: status))
        XCTAssertTrue(element(A11y.overridesBase).exists, "The base preview changed scope")

        toggle.tap()
        XCTAssertTrue(waitForLabelContaining("inactive", on: status))
    }

    @MainActor
    func testGeneratedAliasesSelectBothAssets() {
        launch(.generatedResources)

        XCTAssertTrue(element(A11y.resourcesScreen).waitForExistence(timeout: 3))
        XCTAssertTrue(element(A11y.resourcesIcon).waitForExistence(timeout: 2))
        XCTAssertTrue(waitForLabelContaining("Theme.IconAlias.themeSpark", on: element(A11y.resourcesStatus)))

        app.segmentedControls[A11y.resourcesPicker].buttons["Illustration"].tap()

        XCTAssertTrue(element(A11y.resourcesIllustration).waitForExistence(timeout: 2))
        XCTAssertTrue(waitForLabelContaining("IllustrationAsset", on: element(A11y.resourcesStatus)))
    }

    @MainActor
    private func launch(_ scenario: Scenario? = nil) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        if let scenario {
            app.launchArguments.append("--scenario=\(scenario.rawValue)")
        }
        app.launch()
    }

    @MainActor
    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func waitForLabelContaining(_ text: String, on element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        return XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
            timeout: 3
        ) == .completed
    }

    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, attempts: Int = 6) -> Bool {
        for _ in 0..<attempts where !element.exists {
            app.swipeUp()
        }
        return element.exists
    }

}

private enum Scenario: String, CaseIterable {
    case appearanceModes = "appearance-modes"
    case adaptiveTypography = "adaptive-typography"
    case responsiveUnits = "responsive-units"
    case scopedOverrides = "scoped-overrides"
    case generatedResources = "generated-resources"
}

private enum A11y {
    static let catalog = "sample.catalog"
    static let catalogTitle = "sample.catalog.title"
    static func scenarioLink(_ scenario: Scenario) -> String { "sample.catalog.\(scenario.rawValue)" }

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
