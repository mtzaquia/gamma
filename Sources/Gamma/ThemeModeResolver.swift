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

/// The SwiftUI environment values that may influence theme mode selection.
nonisolated public struct ThemeModeContext: Hashable, Sendable {
    /// The current light or dark appearance.
    public let colorScheme: ColorScheme

    /// The current writing direction for the resolving view hierarchy.
    public let layoutDirection: LayoutDirection

    /// The current horizontal size class, when one is available.
    public let horizontalSizeClass: UserInterfaceSizeClass?

    /// Creates the context supplied to a theme mode resolver.
    ///
    /// - Parameters:
    ///   - colorScheme: The current appearance.
    ///   - layoutDirection: The current writing direction.
    ///   - horizontalSizeClass: The current horizontal size class, if available.
    public init(
        colorScheme: ColorScheme,
        layoutDirection: LayoutDirection,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) {
        self.colorScheme = colorScheme
        self.layoutDirection = layoutDirection
        self.horizontalSizeClass = horizontalSizeClass
    }

    /// Creates a context with light appearance.
    ///
    /// This initializer preserves the original mode-resolver API. Gamma supplies
    /// the actual environment color scheme when resolving an installed theme.
    ///
    /// - Parameters:
    ///   - layoutDirection: The current writing direction.
    ///   - horizontalSizeClass: The current horizontal size class, if available.
    public init(
        layoutDirection: LayoutDirection,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) {
        self.init(
            colorScheme: .light,
            layoutDirection: layoutDirection,
            horizontalSizeClass: horizontalSizeClass
        )
    }
}

/// The color modes used by a dynamic color in light and dark appearances.
nonisolated public struct ThemeColorModeSelection: Hashable, Sendable {
    /// The mode name used in light appearance.
    public let light: String
    /// The mode name used in dark appearance.
    public let dark: String

    /// Creates a light and dark color-mode selection.
    public init(light: String, dark: String) {
        self.light = light
        self.dark = dark
    }
}

/// The primary font mode and any modes whose font faces should be cascaded.
nonisolated public struct ThemeFontModeSelection: Hashable, Sendable {
    /// The mode that supplies metrics and the primary font face.
    public let primary: String
    /// The ordered modes whose faces are appended to the font cascade.
    public let cascades: [String]

    /// Creates a primary font-mode selection with optional cascade modes.
    public init(primary: String, cascades: [String] = []) {
        self.primary = primary
        self.cascades = cascades
    }
}

/// The complete set of modes selected for the current SwiftUI environment.
nonisolated public struct ResolvedThemeModes: Hashable, Sendable {
    private var selections: [ObjectIdentifier: AnyThemeModeSelection] = [:]

    /// Creates an empty collection of family mode selections.
    public init() {}

    /// Creates the color, font, and unit selections used by earlier Gamma releases.
    ///
    /// The values are stored under ``Theme/Colors``, ``Theme/Fonts``, and
    /// ``Theme/Units`` and remain available through the typed subscript.
    public init(
        colors: ThemeColorModeSelection,
        fonts: ThemeFontModeSelection,
        unit: String
    ) {
        self.init()
        self[Theme.Colors.self] = colors
        self[Theme.Fonts.self] = fonts
        self[Theme.Units.self] = unit
    }

    /// The color selection supplied through ``Theme/Colors``.
    ///
    /// Use the typed subscript in new resolver implementations. If the family
    /// was not assigned, this compatibility property returns `light` and `dark`.
    public var colors: ThemeColorModeSelection {
        self[Theme.Colors.self] ?? StandardThemeModeSelection.colors
    }

    /// The font selection supplied through ``Theme/Fonts``.
    ///
    /// Use the typed subscript in new resolver implementations. If the family
    /// was not assigned, this compatibility property returns `default`.
    public var fonts: ThemeFontModeSelection {
        self[Theme.Fonts.self] ?? StandardThemeModeSelection.fonts
    }

    /// The unit mode supplied through ``Theme/Units``.
    ///
    /// Use the typed subscript in new resolver implementations. If the family
    /// was not assigned, this compatibility property returns `default`.
    public var unit: String {
        self[Theme.Units.self] ?? StandardThemeModeSelection.unit
    }

    /// The resolver selection for a built-in or consumer-defined token family.
    ///
    /// Assign selections while implementing ``ThemeModeResolving/resolve(in:)``.
    /// Reading an unassigned family returns `nil`.
    public subscript<Family: ThemeExtension>(
        _ family: Family.Type
    ) -> Family.Selection? {
        get {
            selections[ObjectIdentifier(family)]?.value.base as? Family.Selection
        }
        set {
            selections[ObjectIdentifier(family)] = newValue.map(AnyThemeModeSelection.init)
        }
    }
}

/// `AnyHashable` predates `Sendable`; values entering this box are constrained
/// to `Hashable & Sendable` by `ResolvedThemeModes`' public subscript.
nonisolated private struct AnyThemeModeSelection: Hashable, @unchecked Sendable {
    let value: AnyHashable

    init<Value: Hashable & Sendable>(_ value: Value) {
        self.value = AnyHashable(value)
    }
}

nonisolated private enum StandardThemeModeSelection {
    static let colors = ThemeColorModeSelection(light: "light", dark: "dark")
    static let fonts = ThemeFontModeSelection(primary: "default")
    static let unit = "default"
}

/// Selects the raw theme modes to use for a SwiftUI environment.
///
/// Resolution runs on the main actor as part of SwiftUI's environment update,
/// so conforming application types do not need concurrency or `Hashable` annotations.
@MainActor public protocol ThemeModeResolving {
    /// Identifies state that can change the modes returned for the same context.
    /// Stateless resolvers use the default type identity.
    var cacheIdentity: AnyHashable { get }

    /// Returns the family selections for the supplied SwiftUI environment.
    ///
    /// - Parameter context: The environment values available to mode policy.
    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes
}

public extension ThemeModeResolving {
    var cacheIdentity: AnyHashable {
        AnyHashable(ObjectIdentifier(Self.self))
    }
}

/// The library's standard mode resolver.
///
/// Colors use `light` and `dark`; fonts and units use `default`.
public struct DefaultThemeModeResolver: ThemeModeResolving {
    /// Creates the standard resolver.
    public init() {}

    /// Selects `light` and `dark` colors plus `default` fonts and units.
    public func resolve(in _: ThemeModeContext) -> ResolvedThemeModes {
        var modes = ResolvedThemeModes()
        modes[Theme.Colors.self] = StandardThemeModeSelection.colors
        modes[Theme.Fonts.self] = StandardThemeModeSelection.fonts
        modes[Theme.Units.self] = StandardThemeModeSelection.unit
        return modes
    }
}

struct AnyThemeModeResolver: Hashable {
    private let identity: AnyHashable
    private let resolveImplementation: (ThemeModeContext) -> ResolvedThemeModes

    init<Resolver: ThemeModeResolving>(_ resolver: Resolver) {
        identity = AnyHashable(ThemeModeResolverIdentity(
            type: ObjectIdentifier(Resolver.self),
            state: resolver.cacheIdentity
        ))
        resolveImplementation = resolver.resolve
    }

    func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
        resolveImplementation(context)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.identity == rhs.identity
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }
}

private struct ThemeModeResolverIdentity: Hashable {
    let type: ObjectIdentifier
    let state: AnyHashable
}
