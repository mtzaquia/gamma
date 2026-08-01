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
import Foundation
import os
import SwiftUI
import Testing
import UIKit
@testable import Gamma

@Suite("Theme reader lifecycle")
struct ThemeReaderLifecycleTests {
    @Test("One environment snapshot resolves every token in a body evaluation")
    func resolvesOncePerBodyEvaluation() async throws {
        let counter = ResolutionCounter()
        let model = try LifecycleModel(themeJSON: Self.themeJSON(compactUnit: 12))
        var observations: [LifecycleObservation] = []
        let window = makeWindow(
            model: model,
            resolver: CountingModeResolver(counter: counter)
        ) { observations.append($0) }

        await render(window)

        #expect(observations.first?.resolverInvocation == 1)
        #expect(observations.first?.unit == 12)
        #expect(observations.first?.fontName == "Helvetica")
        window.isHidden = true
    }

    @Test("System environment and same-ID server theme changes update immediately")
    func environmentAndThemeChangesUpdateImmediately() async throws {
        let counter = ResolutionCounter()
        let model = try LifecycleModel(themeJSON: Self.themeJSON(compactUnit: 12))
        var observations: [LifecycleObservation] = []
        let window = makeWindow(
            model: model,
            resolver: CountingModeResolver(counter: counter)
        ) { observations.append($0) }

        await render(window)
        let initialFontSize = try #require(observations.last?.fontSize)

        model.horizontalSizeClass = .regular
        await render(window)
        #expect(observations.last?.unit == 24)

        model.layoutDirection = .rightToLeft
        await render(window)
        #expect(observations.last?.fontName == "Courier")

        model.dynamicTypeSize = .accessibility3
        await render(window)
        #expect(try #require(observations.last?.fontSize) > initialFontSize)

        let replacement = try JSONDecoder().decode(
            RawTheme.self,
            from: Data(Self.themeJSON(compactUnit: 18).utf8)
        )
        #expect(replacement.id == model.theme.id)
        #expect(replacement != model.theme)
        model.horizontalSizeClass = .compact
        model.theme = replacement
        await render(window)
        #expect(observations.last?.unit == 18)

        window.isHidden = true
    }

    @Test("Resolved colors contain both selected appearances")
    func colorsRemainDynamic() async throws {
        let counter = ResolutionCounter()
        let model = try LifecycleModel(themeJSON: Self.themeJSON(compactUnit: 12))
        var observations: [LifecycleObservation] = []
        let window = makeWindow(
            model: model,
            resolver: CountingModeResolver(counter: counter)
        ) { observations.append($0) }

        await render(window)
        let observation = try #require(observations.first)

        #expect(observation.lightWhiteComponent < 0.01)
        #expect(observation.darkWhiteComponent > 0.99)
        window.isHidden = true
    }

    @Test("Bounded caches evict least-recently-used entries")
    func boundedCacheEvictsLeastRecentlyUsedEntry() {
        let cache = BoundedCache<Int, String>(countLimit: 2)
        cache[1] = "one"
        cache[2] = "two"
        _ = cache[1]
        cache[3] = "three"

        #expect(cache.count == 2)
        #expect(cache[1] == "one")
        #expect(cache[2] == nil)
        #expect(cache[3] == "three")
    }

    private func makeWindow(
        model: LifecycleModel,
        resolver: CountingModeResolver,
        onResolve: @escaping (LifecycleObservation) -> Void
    ) -> UIWindow {
        let rootView = LifecycleHost(model: model, resolver: resolver, onResolve: onResolve)
        let controller = UIHostingController(rootView: rootView)
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return window
    }

    private func render(_ window: UIWindow) async {
        window.layoutIfNeeded()
        await Task.yield()
        window.layoutIfNeeded()
        await Task.yield()
    }

    private static func themeJSON(compactUnit: Int) -> String {
        """
        {
          "id": "live-theme",
          "defaults": { "font": "typography/body", "primaryTextColor": "content/text" },
          "colors": {
            "content/text": {
              "name": "Text", "group": "content", "description": "",
              "modes": {
                "day": { "hex": "#000000", "alpha": 1 },
                "night": { "hex": "#FFFFFF", "alpha": 1 }
              }
            }
          },
          "fonts": {
            "typography/body": {
              "name": "Body", "group": "typography", "description": "ios:body",
              "modes": {
                "latin": {
                  "fontSize": 16, "fontName": "Helvetica", "lineHeight": 20,
                  "letterSpacing": 0, "textCase": "ORIGINAL"
                },
                "arabic": {
                  "fontSize": 16, "fontName": "Courier", "lineHeight": 20,
                  "letterSpacing": 0, "textCase": "ORIGINAL"
                }
              }
            }
          },
          "units": {
            "spacing/default": {
              "name": "Spacing", "group": "spacing", "description": "",
              "modes": { "compact": \(compactUnit), "regular": 24 }
            }
          }
        }
        """
    }
}

@MainActor
private final class LifecycleModel: ObservableObject {
    @Published var theme: RawTheme
    @Published var layoutDirection: LayoutDirection = .leftToRight
    @Published var horizontalSizeClass: UserInterfaceSizeClass? = .compact
    @Published var dynamicTypeSize: DynamicTypeSize = .medium

    init(themeJSON: String) throws {
        theme = try JSONDecoder().decode(RawTheme.self, from: Data(themeJSON.utf8))
    }
}

private struct LifecycleHost: View {
    @ObservedObject var model: LifecycleModel
    let resolver: CountingModeResolver
    let onResolve: (LifecycleObservation) -> Void

    var body: some View {
        LifecycleProbe(counter: resolver.counter, onResolve: onResolve)
            .environment(\.theme, model.theme)
            .environment(\.themeModeResolver, AnyThemeModeResolver(resolver))
            .environment(\.layoutDirection, model.layoutDirection)
            .environment(\.horizontalSizeClass, model.horizontalSizeClass)
            .environment(\.dynamicTypeSize, model.dynamicTypeSize)
    }
}

private struct LifecycleProbe: View {
    @ThemeReader private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let counter: ResolutionCounter
    let onResolve: (LifecycleObservation) -> Void

    var body: some View {
        let color = theme.color(LifecycleColorAlias(rawValue: "content/text"))
        let font = theme.font(LifecycleFontAlias(rawValue: "typography/body"))
        let unit = theme.unit(LifecycleUnitAlias(rawValue: "spacing/default"))
        let uiColor = UIColor(color)
        let light = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = uiColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))

        onResolve(LifecycleObservation(
            resolverInvocation: counter.value,
            unit: unit,
            fontName: font.uiFont(for: dynamicTypeSize).fontName,
            fontSize: font.uiFont(for: dynamicTypeSize).pointSize,
            lightWhiteComponent: light.rgba.white,
            darkWhiteComponent: dark.rgba.white
        ))
        return Color.clear
    }
}

private struct LifecycleObservation {
    let resolverInvocation: Int
    let unit: CGFloat
    let fontName: String
    let fontSize: CGFloat
    let lightWhiteComponent: CGFloat
    let darkWhiteComponent: CGFloat
}

private struct CountingModeResolver: ThemeModeResolving {
    let counter: ResolutionCounter

    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
        counter.increment()
        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = .init(light: "day", dark: "night")
        modes[Theme.Fonts.self] = context.layoutDirection == .rightToLeft
            ? .init(primary: "arabic", cascades: ["latin"])
            : .init(primary: "latin", cascades: ["arabic"])
        modes[Theme.Units.self] = context.horizontalSizeClass == .regular
            ? "regular"
            : "compact"
        return modes
    }
}

nonisolated private final class ResolutionCounter: @unchecked Sendable, Hashable {
    private let state = OSAllocatedUnfairLock(initialState: 0)

    var value: Int { state.withLock { $0 } }

    func increment() {
        state.withLock { $0 += 1 }
    }

    static func == (lhs: ResolutionCounter, rhs: ResolutionCounter) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

nonisolated private enum LifecycleColorGroup: ThemeTokenGroup {
    typealias Family = Theme.Colors
    static let name = "content"
}

private typealias LifecycleColorAlias = Theme.Alias<LifecycleColorGroup>

nonisolated private enum LifecycleFontGroup: ThemeTokenGroup {
    typealias Family = Theme.Fonts
    static let name = "typography"
}

private typealias LifecycleFontAlias = Theme.Alias<LifecycleFontGroup>

nonisolated private enum LifecycleUnitGroup: ThemeTokenGroup {
    typealias Family = Theme.Units
    static let name = "spacing"
}

private typealias LifecycleUnitAlias = Theme.Alias<LifecycleUnitGroup>

private extension UIColor {
    var rgba: (white: CGFloat, alpha: CGFloat) {
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        getWhite(&white, alpha: &alpha)
        return (white, alpha)
    }
}
#endif
