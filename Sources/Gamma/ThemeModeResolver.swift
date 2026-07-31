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
    ///   - colorScheme: The current appearance. Defaults to `.light`.
    ///   - layoutDirection: The current writing direction.
    ///   - horizontalSizeClass: The current horizontal size class, if available.
    public init(
        colorScheme: ColorScheme = .light,
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
    public let light: String
    public let dark: String

    public init(light: String, dark: String) {
        self.light = light
        self.dark = dark
    }
}

/// The primary font mode and any modes whose font faces should be cascaded.
nonisolated public struct ThemeFontModeSelection: Hashable, Sendable {
    public let primary: String
    public let cascades: [String]

    public init(primary: String, cascades: [String] = []) {
        self.primary = primary
        self.cascades = cascades
    }
}

/// The complete set of modes selected for the current SwiftUI environment.
nonisolated public struct ResolvedThemeModes: Hashable, Sendable {
    public let colors: ThemeColorModeSelection
    public let fonts: ThemeFontModeSelection
    public let unit: String
    private var extensionModes: [ObjectIdentifier: String]

    public init(
        colors: ThemeColorModeSelection,
        fonts: ThemeFontModeSelection,
        unit: String
    ) {
        self.colors = colors
        self.fonts = fonts
        self.unit = unit
        extensionModes = [:]
    }

    /// The mode selected for a consumer-defined token family.
    ///
    /// Assign selections while implementing ``ThemeModeResolving/resolve(in:)``.
    /// A family may use any mode name and any input from ``ThemeModeContext``;
    /// custom modes are not restricted to appearance variants.
    public subscript<Extension: ThemeExtensionKey>(
        _ family: Extension.Type
    ) -> String? {
        get { extensionModes[ObjectIdentifier(family)] }
        set { extensionModes[ObjectIdentifier(family)] = newValue }
    }
}

/// Selects the raw theme modes to use for a SwiftUI environment.
///
/// Resolution runs on the main actor as part of SwiftUI's environment update,
/// so conforming application types do not need concurrency or `Hashable` annotations.
@MainActor public protocol ThemeModeResolving {
    /// Identifies state that can change the modes returned for the same context.
    /// Stateless resolvers use the default type identity.
    var cacheIdentity: AnyHashable { get }

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
    public init() {}

    public func resolve(in _: ThemeModeContext) -> ResolvedThemeModes {
        ResolvedThemeModes(
            colors: ThemeColorModeSelection(light: "light", dark: "dark"),
            fonts: ThemeFontModeSelection(primary: "default"),
            unit: "default"
        )
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
