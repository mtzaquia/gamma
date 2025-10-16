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

#if canImport(UIKit)
import Testing
import UIKit
@testable import Gamma

@Suite("Raw font")
struct RawFontTests {
    @Test("Text-style markers use exact token boundaries")
    func textStyleMarkersUseExactTokenBoundaries() {
        #expect(textStyle(for: "ios:largeTitle") == .largeTitle)
        #expect(textStyle(for: "ios:title") == .title1)
        #expect(textStyle(for: "ios:title1") == .title1)
        #expect(textStyle(for: "ios:title2") == .title2)
        #expect(textStyle(for: "ios:title3") == .title3)
        #expect(textStyle(for: "ios:headline") == .headline)
        #expect(textStyle(for: "ios:subheadline") == .subheadline)
        #expect(textStyle(for: "ios:callout") == .callout)
        #expect(textStyle(for: "ios:footnote") == .footnote)
        #expect(textStyle(for: "ios:caption") == .caption1)
        #expect(textStyle(for: "ios:caption1") == .caption1)
        #expect(textStyle(for: "ios:caption2") == .caption2)
        #expect(textStyle(for: "prefix ios:title2 suffix") == .title2)
        #expect(textStyle(for: "ios:title20") == .body)
        #expect(textStyle(for: "unmarked") == .body)
    }

    private func textStyle(for description: String) -> UIFont.TextStyle {
        RawFont(
            name: "test",
            group: "test",
            description: description,
            modes: [:]
        ).textStyle
    }
}
#endif
