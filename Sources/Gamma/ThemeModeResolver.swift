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

/// One type-safe mode assignment for a token family.
///
/// Use assignments for consumer-defined families passed to
/// ``ThemeModes/init(colors:fonts:units:extensions:)``. The family determines
/// the required mode-selection type.
nonisolated public struct ThemeModeAssignment: Hashable, Sendable {
    fileprivate let familyIdentifier: ObjectIdentifier
    fileprivate let selection: AnyThemeModeSelection

    /// Creates an assignment for a built-in or consumer-defined token family.
    ///
    /// - Parameters:
    ///   - family: The family that will resolve using this mode selection.
    ///   - mode: The family-specific selection to store.
    public init<Family: ThemeExtension>(
        _ family: Family.Type,
        mode: Family.Selection
    ) {
        familyIdentifier = ObjectIdentifier(family)
        selection = AnyThemeModeSelection(mode)
    }
}

/// The complete mode selection for one SwiftUI environment.
nonisolated public struct ThemeModes: Hashable, Sendable {
    private let selections: [ObjectIdentifier: AnyThemeModeSelection]

    /// Creates a complete selection for the built-in families and any extensions.
    ///
    /// When `extensions` contains more than one assignment for the same family,
    /// the last assignment wins.
    ///
    /// - Parameters:
    ///   - colors: The light and dark color modes.
    ///   - fonts: The primary and cascade font modes.
    ///   - units: The selected numeric-unit mode.
    ///   - extensions: Mode assignments for consumer-defined token families.
    public init(
        colors: ThemeColorModeSelection,
        fonts: ThemeFontModeSelection,
        units: String,
        extensions: [ThemeModeAssignment] = []
    ) {
        var selections = [
            ObjectIdentifier(Theme.Colors.self): AnyThemeModeSelection(colors),
            ObjectIdentifier(Theme.Fonts.self): AnyThemeModeSelection(fonts),
            ObjectIdentifier(Theme.Units.self): AnyThemeModeSelection(units),
        ]
        for assignment in extensions {
            selections[assignment.familyIdentifier] = assignment.selection
        }
        self.selections = selections
    }

    /// The resolver selection for a built-in or consumer-defined token family.
    ///
    /// A family without an assignment returns `nil`. Resolver implementations
    /// provide custom family selections through
    /// ``init(colors:fonts:units:extensions:)``; resolution code uses this
    /// subscript to recover the family-specific selection type.
    public subscript<Family: ThemeExtension>(
        _ family: Family.Type
    ) -> Family.Selection? {
        selections[ObjectIdentifier(family)]?.value.base as? Family.Selection
    }
}

/// `AnyHashable` predates `Sendable`; values entering this box are constrained
/// to `Hashable & Sendable` by ``ThemeModeAssignment`` and ``ThemeModes``.
nonisolated private struct AnyThemeModeSelection: Hashable, @unchecked Sendable {
    let value: AnyHashable

    init<Value: Hashable & Sendable>(_ value: Value) {
        self.value = AnyHashable(value)
    }
}

nonisolated private enum StandardThemeModeSelection {
    static let colors = ThemeColorModeSelection(light: "light", dark: "dark")
    static let fonts = ThemeFontModeSelection(primary: "default")
    static let units = "default"
}

/// Selects the raw theme modes to use for a SwiftUI environment.
///
/// Resolution runs on the main actor as part of SwiftUI's environment update,
/// so conforming application types do not need concurrency or `Hashable`
/// annotations. Return built-in modes through ``ThemeModes`` and add custom
/// families through ``ThemeModeAssignment``.
@MainActor public protocol ThemeModeResolving {
    /// Identifies state that can change the modes returned for the same context.
    /// Stateless resolvers use the default type identity.
    var cacheIdentity: AnyHashable { get }

    /// Returns the family selections for the supplied SwiftUI environment.
    ///
    /// - Parameter context: The environment values available to mode policy.
    func modes(for context: ThemeModeContext) -> ThemeModes
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
    public func modes(for _: ThemeModeContext) -> ThemeModes {
        ThemeModes(
            colors: StandardThemeModeSelection.colors,
            fonts: StandardThemeModeSelection.fonts,
            units: StandardThemeModeSelection.units
        )
    }
}

struct AnyThemeModeResolver: Hashable {
    private let identity: AnyHashable
    private let modesImplementation: (ThemeModeContext) -> ThemeModes

    init<Resolver: ThemeModeResolving>(_ resolver: Resolver) {
        identity = AnyHashable(ThemeModeResolverIdentity(
            type: ObjectIdentifier(Resolver.self),
            state: resolver.cacheIdentity
        ))
        modesImplementation = resolver.modes
    }

    func modes(for context: ThemeModeContext) -> ThemeModes {
        modesImplementation(context)
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
