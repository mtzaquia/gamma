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
@testable import Gamma

@Suite("Raw theme overrides")
struct RawThemeOverridesTests {
    @Test("Nested identity includes its parent override")
    func nestedIdentityIncludesParentOverride() {
        let firstParent = RawThemeOverrides(
            units: ["spacing": ["default": 12]]
        )
        let secondParent = RawThemeOverrides(
            units: ["spacing": ["default": 24]]
        )
        let inner = RawThemeOverrides(
            colors: ["background": ["light": .init(hex: "#FFFFFF", alpha: 1)]]
        )

        let firstParentHash = firstParent.combinedHash(with: 0)
        let secondParentHash = secondParent.combinedHash(with: 0)
        let firstNestedHash = inner.combinedHash(with: firstParentHash)
        let secondNestedHash = inner.combinedHash(with: secondParentHash)

        #expect(firstNestedHash != secondNestedHash)
    }

    @Test("Override identity is stable for the same scope chain")
    func overrideIdentityIsStableForSameScopeChain() {
        let parent = RawThemeOverrides(
            units: ["spacing": ["default": 12]]
        )
        let inner = RawThemeOverrides(
            colors: ["background": ["light": .init(hex: "#FFFFFF", alpha: 1)]]
        )

        let first = inner.combinedHash(with: parent.combinedHash(with: 0))
        let second = inner.combinedHash(with: parent.combinedHash(with: 0))

        #expect(first == second)
    }

    @Test("Override identity preserves scope order")
    func overrideIdentityPreservesScopeOrder() {
        let outer = RawThemeOverrides(
            units: ["spacing": ["default": 12]]
        )
        let inner = RawThemeOverrides(
            colors: ["background": ["light": .init(hex: "#FFFFFF", alpha: 1)]]
        )

        let outerThenInner = inner.combinedHash(with: outer.combinedHash(with: 0))
        let innerThenOuter = outer.combinedHash(with: inner.combinedHash(with: 0))

        #expect(outerThenInner != innerThenOuter)
    }
}
#endif
