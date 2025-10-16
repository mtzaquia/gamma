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
    @MainActor
    func testShowcaseModeResolutionAndGeneratedAssets() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        XCTAssertTrue(app.scrollViews["sample.showcase"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["sample.title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["sample.colors"].exists)

        let fontStatus = app.staticTexts["sample.font.status"]
        XCTAssertTrue(fontStatus.label.contains("registered"))

        let modeStatus = app.staticTexts["sample.mode.status"]
        XCTAssertTrue(modeStatus.label.contains("LTR"))
        XCTAssertTrue(modeStatus.label.contains("NotoSans-Regular"))

        app.buttons["sample.mode.rtl"].tap()

        XCTAssertTrue(modeStatus.label.contains("RTL"))
        XCTAssertTrue(modeStatus.label.contains("NotoSansArabic-Regular"))

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["sample.assets"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["sample.assets.icon"].exists)
        XCTAssertTrue(app.images["sample.assets.illustration"].exists)

        app.swipeUp()
        XCTAssertTrue(app.staticTexts["sample.typography"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["sample.font.arabic"].waitForExistence(timeout: 2))
    }
}
