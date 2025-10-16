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

import GammaSchema
import SwiftUI

public typealias RawFont = GammaSchema.RawFont

extension RawFont {
    var textStyle: UIFont.TextStyle {
        switch description {
        case /\bios:largeTitle\b/: return .largeTitle
        case /\bios:title(?:1)?\b/: return .title1
        case /\bios:title2\b/: return .title2
        case /\bios:title3\b/: return .title3
        case /\bios:headline\b/: return .headline
        case /\bios:subheadline\b/: return .subheadline
        case /\bios:callout\b/: return .callout
        case /\bios:footnote\b/: return .footnote
        case /\bios:caption(?:1)?\b/: return .caption1
        case /\bios:caption2\b/: return .caption2
        default: return .body
        }
    }
}
