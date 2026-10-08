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

import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import CoreText
import UIKit
#endif
@testable import Gamma

@Suite("Theme resource modifier", .serialized)
struct ThemeResourceModifierTests {
    @Test("Synchronous cache hits retain the single decoded identity")
    func cacheRetainsIdentity() throws {
        ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        let first = ThemeResourceCache.load(resource, from: .module)
        let second = ThemeResourceCache.load(resource, from: .module)

        #expect(first == second)
        #expect(ThemeResourceCache.count() == 1)
        // Each uncached decode has a distinct identity, even for the same JSON.
        #expect(try resource.load(from: .module) != first)

        ThemeResourceCache.removeAll()
        #expect(ThemeResourceCache.count() == 0)
        #expect(ThemeResourceCache.load(resource, from: .module) != first)
    }

    @Test("Concurrent cache misses all receive one decoded identity")
    func concurrentCacheAccess() async throws {
        ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        let bundle = Bundle.module
        let themes = await withTaskGroup(of: RawTheme.self, returning: [RawTheme].self) { group in
            for _ in 0..<64 {
                group.addTask { ThemeResourceCache.load(resource, from: bundle) }
            }
            var results: [RawTheme] = []
            for await theme in group {
                results.append(theme)
            }
            return results
        }

        let first = try #require(themes.first)
        #expect(themes.count == 64)
        #expect(themes.allSatisfy { $0 == first })
        #expect(ThemeResourceCache.count() == 1)
    }

    @Test("Cache keys separate bundles and normalize their URLs")
    func cacheKeysIncludeBundle() throws {
        ThemeResourceCache.removeAll()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let copiedURL = directory.appendingPathComponent("Copy.bundle")
        try FileManager.default.copyItem(at: Bundle.module.bundleURL, to: copiedURL)
        let copiedBundle = try #require(Bundle(url: copiedURL))
        let equivalentBundle = try #require(Bundle(url: directory.appendingPathComponent("./Copy.bundle")))
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        let original = ThemeResourceCache.load(resource, from: .module)
        let copy = ThemeResourceCache.load(resource, from: copiedBundle)

        #expect(original != copy)
        #expect(ThemeResourceCache.load(resource, from: equivalentBundle) == copy)
        #expect(ThemeResourceCache.count() == 2)
    }

#if canImport(UIKit)
    @Test("A bundled resource resolves real tokens on its first render without awaiting a task")
    func bundledResourceModifier() throws {
        ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        var observations: [ResourceObservation] = []
        let view = ResourceUnitProbe { observations.append($0) }
            .theme(resource, bundle: .module)
        #expect(ThemeResourceCache.count() == 1)

        let window = makeWindow(view)
        defer { window.isHidden = true }
        let first = try #require(observations.first)
        #expect(first.unit == 12)
        #expect(first.colorAlpha == 1)
        #expect(first.theme == ThemeResourceCache.load(resource, from: .module))
        #expect(first.registration == .ready)
    }

    @Test("Separate installations share a cached RawTheme identity")
    func installationsShareIdentity() throws {
        ThemeResourceCache.removeAll()
        let resource = ThemeResource(fileName: "Modifier.theme.json")
        var observations: [ResourceObservation] = []
        let window = makeWindow(VStack {
            ResourceUnitProbe { observations.append($0) }.theme(resource, bundle: .module)
            ResourceUnitProbe { observations.append($0) }.theme(resource, bundle: .module)
        })
        defer { window.isHidden = true }
        #expect(Set(observations.map(\.identity)).count == 2)
        let first = try #require(observations.first)
        #expect(observations.allSatisfy { $0.theme == first.theme && $0.unit == 12 })
        #expect(ThemeResourceCache.count() == 1)
    }

    @Test("Nested resources install their own complete policy on the first render")
    func nestedResourceInstallsPolicyImmediately() throws {
        ThemeResourceCache.removeAll()
        let inherited = try ThemeResource(fileName: "Modifier.theme.json").load(from: .module)
        var observations: [ResourceObservation] = []
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
        let first = try #require(observations.first)
        #expect(first.unit == 36)
        #expect(first.colorAlpha == 1)
        #expect(first.extra == 1)
        #expect(first.registration == .ready)
        #expect(observations.allSatisfy { $0.unit == 36 })
    }

    @Test("Resource and policy replacements activate in the same update and preserve state")
    func resourceReplacementInstallsPolicyImmediately() throws {
        ThemeResourceCache.removeAll()
        let model = ResourceSelection()
        var observations: [ResourceObservation] = []
        let controller = UIHostingController(rootView: ResourceSwitchingView(model: model) { observations.append($0) })
        let window = makeWindow(controller: controller)
        defer { window.isHidden = true }
        let first = try #require(observations.first)
        #expect(first.unit == 12)
        let count = observations.count

        model.alternate = true
        controller.rootView = ResourceSwitchingView(model: model) { observations.append($0) }
        controller.view.setNeedsLayout()
        window.layoutIfNeeded()
        #expect(observations.count > count)
        #expect(observations.dropFirst(count).allSatisfy { $0.unit == 36 && $0.extra == 1 })
        #expect(observations.last?.theme != first.theme)
        #expect(Set(observations.map(\.identity)).count == 1)

        // A policy-only change also takes effect without a task or another decode.
        let replacementCount = observations.count
        model.otherUnitMode = true
        controller.rootView = ResourceSwitchingView(model: model) { observations.append($0) }
        controller.view.setNeedsLayout()
        window.layoutIfNeeded()
        #expect(observations.count > replacementCount)
        #expect(observations.dropFirst(replacementCount).allSatisfy { $0.unit == 48 })
        #expect(ThemeResourceCache.count() == 2)
    }

    @Test("Bundled font registration refreshes once and preserves theme and descendant state")
    func fontRegistrationRefreshesInPlace() async throws {
        let font = UIFont.systemFont(ofSize: 12)
        let coreTextFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        let fontURL = try #require(CTFontCopyAttribute(coreTextFont, kCTFontURLAttribute) as? URL)
        let model = ResourceSelection()
        var observations: [ResourceObservation] = []
        let controller = UIHostingController(rootView: ResourceSwitchingView(
            model: model, fontURLs: [fontURL]
        ) { observations.append($0) })
        let window = makeWindow(controller: controller)
        defer { window.isHidden = true }
        let first = try #require(observations.first)
        #expect(first.unit == 12)
        #expect(first.registration == .init(revision: 0, isPending: true))

        for _ in 0..<100 where observations.last?.registration.isPending != false {
            try await Task.sleep(for: .milliseconds(10))
            window.layoutIfNeeded()
        }
        #expect(observations.last?.registration == .init(revision: 1, isPending: false))

        // A subsequent body evaluation must not restart the completed task.
        model.renderPass += 1
        controller.rootView = ResourceSwitchingView(model: model, fontURLs: [fontURL]) { observations.append($0) }
        controller.view.setNeedsLayout()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(30))
        window.layoutIfNeeded()
        #expect(observations.last?.renderPass == 1)
        #expect(observations.last?.registration == .init(revision: 1, isPending: false))
        #expect(observations.allSatisfy { $0.unit == 12 && $0.theme == first.theme })
        #expect(Set(observations.map(\.identity)).count == 1)
    }

    private func makeWindow(_ view: some View) -> UIWindow {
        makeWindow(controller: UIHostingController(rootView: view))
    }

    private func makeWindow(controller: UIViewController) -> UIWindow {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return window
    }
#endif
}

#if canImport(UIKit)
private struct ResourceObservation {
    let unit: CGFloat
    let colorAlpha: CGFloat
    let extra: Int?
    let theme: RawTheme
    let identity: UUID
    let registration: ThemeFontRegistrationContext
    let renderPass: Int
}

nonisolated private enum ResourceUnitGroup: ThemeTokenGroup {
    typealias Family = Theme.Units
    static let name = "spacing"
}

private typealias ResourceUnitAlias = Theme.Alias<ResourceUnitGroup>

private struct ResourceUnitProbe: View {
    @ThemeReader private var theme
    @State private var identity = UUID()
    @Environment(\.theme) private var rawTheme
    @Environment(\.themeFontRegistration) private var registration

    var renderPass = 0
    let onResolve: (ResourceObservation) -> Void

    var body: some View {
        let value = theme.unit(ResourceUnitAlias(rawValue: "spacing/default"))
        let color = UIColor(theme.color(Theme.Alias<Theme.Colors>(rawValue: "content/text")))
        let extra = rawTheme.extensionPayloads[ResourceExtras.key] == nil
            ? nil : theme.resolve(Theme.Alias<ResourceExtras>(rawValue: "extra"))
        onResolve(ResourceObservation(
            unit: value,
            colorAlpha: color.cgColor.alpha,
            extra: extra,
            theme: rawTheme,
            identity: identity,
            registration: registration,
            renderPass: renderPass
        ))
        return Color.clear
    }
}

@Observable private final class ResourceSelection {
    var alternate = false
    var otherUnitMode = false
    var renderPass = 0
}

private struct ResourceSwitchingView: View {
    let model: ResourceSelection
    var fontURLs: [URL] = []
    let onResolve: (ResourceObservation) -> Void

    var body: some View {
        ResourceUnitProbe(renderPass: model.renderPass, onResolve: onResolve)
            .theme(
                ThemeResource(fileName: model.alternate ? "Alternate.theme.json" : "Modifier.theme.json"),
                bundle: .module,
                modeResolver: ResourceModeResolver(alternate: model.alternate, otherUnitMode: model.otherUnitMode),
                extensions: model.alternate ? [ThemeExtensionRegistration(ResourceExtras.self)] : [],
                fontURLs: fontURLs
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
