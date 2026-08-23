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
    @Test("Bundled resources mount immediately and resolve without replacing content")
    func bundledResourceModifier() async {
        await ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        var observations: [(unit: CGFloat, identity: UUID)] = []

        let view = ResourceUnitProbe { observations.append($0) }
            .theme(resource, bundle: .module)
        #expect(await ThemeResourceCache.count() == 0)

        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let initialIdentity = observations.first?.identity

        for _ in 0..<20 where observations.last?.unit != 12 {
            await Task.yield()
            window.layoutIfNeeded()
        }

        let first = await ThemeResourceCache.load(resource, from: .module)
        let second = await ThemeResourceCache.load(resource, from: .module)

        #expect(initialIdentity != nil)
        #expect(observations.first?.unit == 0)
        #expect(observations.last?.unit == 12)
        #expect(observations.last?.identity == initialIdentity)
        #expect(await ThemeResourceCache.count() == 1)
        #expect(first == second)
        window.isHidden = true
    }
}

nonisolated private enum ResourceUnitGroup: ThemeTokenGroup {
    typealias Family = Theme.Units
    static let name = "spacing"
}

private typealias ResourceUnitAlias = Theme.Alias<ResourceUnitGroup>

private struct ResourceUnitProbe: View {
    @ThemeReader private var theme
    @State private var identity = UUID()

    let onResolve: ((unit: CGFloat, identity: UUID)) -> Void

    var body: some View {
        let value = theme.unit(ResourceUnitAlias(rawValue: "spacing/default"))
        onResolve((value, identity))
        return Color.clear
    }
}
#endif
