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
import Foundation
import SwiftUI

enum SampleTheme {
    static let latinFontName = "NotoSans-Regular"
    static let arabicFontName = "NotoSansArabic-Regular"

    static let fontURLs: [URL] = {
        ["NotoSans-Regular", "NotoSansArabic-Regular"].map { resource in
            guard let url = Bundle.main.url(
                forResource: resource,
                withExtension: "ttf",
                subdirectory: "Fonts"
            ) ?? Bundle.main.url(forResource: resource, withExtension: "ttf") else {
                preconditionFailure("Missing bundled sample font: \(resource).ttf")
            }
            return url
        }
    }()
}

struct SampleThemeModeResolver: ThemeModeResolving {
    func modes(for context: ThemeModeContext) -> ThemeModes {
        ThemeModes(
            colors: ThemeColorModeSelection(light: "day", dark: "night"),
            fonts: context.layoutDirection == .rightToLeft
                ? ThemeFontModeSelection(primary: "arabic", cascades: ["latin"])
                : ThemeFontModeSelection(primary: "latin", cascades: ["arabic"]),
            units: context.horizontalSizeClass == .regular ? "regular" : "compact",
            extensions: [
                ThemeModeAssignment(
                    Theme.Gradients.self,
                    mode: context.colorScheme == .dark ? "night" : "day"
                ),
            ]
        )
    }
}
