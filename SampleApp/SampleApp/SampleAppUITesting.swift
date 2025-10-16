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

enum SampleAppUITesting {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    static let initialLayoutDirection: LayoutDirection = .leftToRight

    @MainActor
    static func configure() {
        guard isEnabled else { return }
        UIView.setAnimationsEnabled(false)
    }
}

enum SampleAppAccessibility {
    static let showcase = "sample.showcase"
    static let title = "sample.title"
    static let colorsSection = "sample.colors"
    static let typographySection = "sample.typography"
    static let spacingSection = "sample.spacing"
    static let assetsSection = "sample.assets"
    static let iconAsset = "sample.assets.icon"
    static let illustrationAsset = "sample.assets.illustration"
    static let modeStatus = "sample.mode.status"
    static let fontStatus = "sample.font.status"
    static let arabicSample = "sample.font.arabic"
    static let leftToRightButton = "sample.mode.ltr"
    static let rightToLeftButton = "sample.mode.rtl"
}
