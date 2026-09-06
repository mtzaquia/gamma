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

@Suite("Theme resource modifier", .serialized)
struct ThemeResourceModifierTests {
    @Test("Bundled resources mount immediately and resolve without replacing content")
    func bundledResourceModifier() async {
        await ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        var observations: [(unit: CGFloat, identity: UUID, registration: ThemeFontRegistrationContext)] = []

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

    @Test("Nested resources inherit the complete policy until their resource loads")
    func nestedResourceRetainsInheritedPolicy() async throws {
        let inherited = try ThemeResource(fileName: "Modifier.theme.json").load(from: .module)
        var observations: [(unit: CGFloat, identity: UUID, registration: ThemeFontRegistrationContext)] = []
        let view = ResourceUnitProbe { observations.append($0) }
            .theme(
                ThemeResource(fileName: "Alternate.theme.json"), bundle: .module,
                modeResolver: ResourceModeResolver(alternate: true),
                extensions: [ThemeExtensionRegistration(ResourceExtras.self)]
            )
            .environment(\.theme, inherited)
            .environment(\.themeFontRegistration, .init(revision: 7, isPending: true))
        let window = makeWindow(view)
        defer { window.isHidden = true }
        #expect(observations.first?.unit == 12)
        #expect(observations.first?.registration == .init(revision: 7, isPending: true))
        await render(window, until: { observations.last?.unit == 36 })
        #expect(observations.last?.unit == 36)
        #expect(observations.last?.registration == .ready)
        #expect(Set(observations.map(\.identity)).count == 1)
        #expect(observations.allSatisfy { [12, 36].contains($0.unit) })
    }

    @Test("Resource and policy replacements activate together and preserve descendant state")
    func resourceReplacementRetainsPolicy() async throws {
        let model = ResourceSelection()
        var observations: [(unit: CGFloat, identity: UUID, registration: ThemeFontRegistrationContext)] = []
        let window = makeWindow(ResourceSwitchingView(model: model) { observations.append($0) })
        defer { window.isHidden = true }
        await render(window, until: { observations.last?.unit == 12 })
        #expect(observations.last?.unit == 12)
        let count = observations.count
        model.alternate = true
        window.layoutIfNeeded()
        await render(window, until: { observations.last?.unit == 36 })
        #expect(observations.last?.unit == 36)
        #expect(observations.dropFirst(count).allSatisfy { [12, 36].contains($0.unit) })
        #expect(Set(observations.map(\.identity)).count == 1)

        // A policy-only update to an already loaded resource must still take effect.
        model.otherUnitMode = true
        await render(window, until: { observations.last?.unit == 48 })
        #expect(observations.last?.unit == 48)
    }

    private func makeWindow(_ view: some View) -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }

    private func render(_ window: UIWindow, until ready: () -> Bool) async {
        for _ in 0..<100 where !ready() {
            try? await Task.sleep(for: .milliseconds(10))
            window.layoutIfNeeded()
        }
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
    @Environment(\.themeFontRegistration) private var registration

    let onResolve: ((unit: CGFloat, identity: UUID, registration: ThemeFontRegistrationContext)) -> Void

    var body: some View {
        let value = theme.unit(ResourceUnitAlias(rawValue: "spacing/default"))
        onResolve((value, identity, registration))
        return Color.clear
    }
}

@Observable private final class ResourceSelection {
    var alternate = false
    var otherUnitMode = false
}

private struct ResourceSwitchingView: View {
    let model: ResourceSelection
    let onResolve: ((unit: CGFloat, identity: UUID, registration: ThemeFontRegistrationContext)) -> Void

    var body: some View {
        ResourceUnitProbe(onResolve: onResolve)
            .theme(
                ThemeResource(fileName: model.alternate ? "Alternate.theme.json" : "Modifier.theme.json"),
                bundle: .module,
                modeResolver: ResourceModeResolver(alternate: model.alternate, otherUnitMode: model.otherUnitMode),
                extensions: model.alternate ? [ThemeExtensionRegistration(ResourceExtras.self)] : []
            )
    }
}

private struct ResourceModeResolver: ThemeModeResolving {
    let alternate: Bool
    var otherUnitMode = false
    var cacheIdentity: AnyHashable { [alternate, otherUnitMode] }

    func modes(for _: ThemeModeContext) -> ThemeModes {
        ThemeModes(
            colors: alternate ? .init(light: "alternate", dark: "alternate") : .init(light: "light", dark: "dark"),
            fonts: .init(primary: alternate ? "alternate" : "default"),
            units: alternate ? (otherUnitMode ? "other" : "alternate") : "default",
            extensions: alternate ? [.init(ResourceExtras.self, mode: "alternate")] : []
        )
    }
}

nonisolated private enum ResourceExtras: ThemeExtension {
    static let key = "resourceExtras"
    nonisolated struct Token: ThemeExtensionToken {
        let name: String
        let group: String
        let modes: [String: Int]
    }
}
#endif
