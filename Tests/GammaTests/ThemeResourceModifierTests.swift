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
import SwiftUI
import Testing
import UIKit
@testable import Gamma

@Suite("Theme resource modifier")
struct ThemeResourceModifierTests {
    @Test("Bundled resources are cached and can be installed directly")
    func bundledResourceModifier() async {
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        let first = ThemeResourceCache.load(resource, from: .module)
        let second = ThemeResourceCache.load(resource, from: .module)
        var resolvedUnit: CGFloat?

        #expect(first == second)

        let view = ResourceUnitProbe { resolvedUnit = $0 }
            .theme(resource, bundle: .module)
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        await Task.yield()

        #expect(resolvedUnit == 12)
        window.isHidden = true
    }
}

private struct ResourceUnitAlias: UnitAlias {
    let rawValue: String
}

private struct ResourceUnitProbe: View {
    @ThemeReader private var theme
    let onResolve: (CGFloat) -> Void

    var body: some View {
        let value = theme.unit(ResourceUnitAlias(rawValue: "spacing"))
        onResolve(value)
        return Color.clear
    }
}
#endif
