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

/// Provides access to the active theme's resolved design tokens.
///
/// Obtain a ``ThemeProxy`` via the ``ThemeReader`` property wrapper. The proxy
/// resolves aliases to their concrete values and adapts to color scheme,
/// layout direction, and Dynamic Type size automatically.
public struct ThemeProxy: DynamicProperty {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.theme) private var theme
    @Environment(\.themeModeResolver) private var modeResolver
    @Environment(\.themeExtensions) private var themeExtensions

    private var snapshot: Snapshot?

    private struct Snapshot {
        let theme: RawTheme
        let modes: ThemeModes
        let cacheScope: ThemeCacheScope
    }

    private func makeSnapshot() -> Snapshot {
        let modes = modeResolver.modes(
            for: ThemeModeContext(
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                horizontalSizeClass: horizontalSizeClass
            )
        )
        ThemeDiagnostics.validate(
            theme,
            modes: modes,
            extensions: themeExtensions
        )
        return Snapshot(
            theme: theme,
            modes: modes,
            cacheScope: ThemeCacheScope(
                themeInstanceID: theme.instanceID,
                overrideHash: theme.overrideHash,
                modeResolver: modeResolver,
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                horizontalSizeClass: horizontalSizeClass
            )
        )
    }

    private var currentSnapshot: Snapshot {
        snapshot ?? makeSnapshot()
    }

    /// You do not initialise this entity directly. Use ``ThemeReader`` to acquire an instance instead.
    public init() {}

    /// Captures one coherent environment snapshot for the upcoming body evaluation.
    /// SwiftUI calls this after updating the nested environment properties.
    public mutating func update() {
        snapshot = makeSnapshot()
    }
}

public extension ThemeProxy {
    /// Resolves one consumer-defined token alias to its selected mode payload.
    ///
    /// The active ``ThemeModeResolving`` implementation selects the mode name
    /// for each custom family. This method decodes the token and returns that
    /// mode's concrete payload type. Failures produce a Gamma resolution
    /// diagnostic and return `nil` in release builds.
    ///
    /// - Parameter alias: The typed token alias to resolve.
    /// - Returns: The selected mode payload, or `nil` when the family, token,
    ///   selection, or selected mode is unavailable or invalid.
    func resolve<Scope: ThemeAliasScope>(
        _ alias: Theme.Alias<Scope>
    ) -> Scope.Family.Token.Mode?
    where Scope.Family: ThemeExtension, Scope.Family.Selection == String {
        let snapshot = currentSnapshot

        guard let selectedMode = selection(
            for: Scope.Family.self,
            alias: alias.rawValue,
            in: snapshot
        ) else {
            return nil
        }
        guard !selectedMode.isEmpty else {
            ThemeDiagnostics.resolutionFailure(
                kind: Scope.Family.key,
                alias: alias.rawValue,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the resolver selected an empty mode name"
            )
            return nil
        }

        do {
            guard let token = try ThemeExtensionTokenCache.tokens(
                for: Scope.Family.self,
                in: snapshot.theme
            )?[alias.rawValue] else {
                ThemeDiagnostics.resolutionFailure(
                    kind: Scope.Family.key,
                    alias: alias.rawValue,
                    themeInstanceID: snapshot.theme.instanceID,
                    detail: "the token does not exist in theme \(snapshot.theme.id)"
                )
                return nil
            }

            if let groupName = Scope.groupName, token.group != groupName {
                ThemeDiagnostics.resolutionFailure(
                    kind: Scope.Family.key,
                    alias: alias.rawValue,
                    themeInstanceID: snapshot.theme.instanceID,
                    detail: "the token belongs to group \(token.group.debugDescription), not \(groupName.debugDescription)"
                )
                return nil
            }

            guard let mode = token.modes[selectedMode] else {
                ThemeDiagnostics.resolutionFailure(
                    kind: Scope.Family.key,
                    alias: alias.rawValue,
                    themeInstanceID: snapshot.theme.instanceID,
                    detail: "mode \(selectedMode) is missing"
                )
                return nil
            }
            return mode
        } catch {
            ThemeDiagnostics.resolutionFailure(
                kind: Scope.Family.key,
                alias: alias.rawValue,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the payload is invalid: \(themeDecodingDescription(error))"
            )
            return nil
        }
    }

    /// Resolves a color alias to a `Color` that adapts to light and dark mode.
    ///
    /// - Parameter alias: An alias from any group owned by ``Theme/Colors``.
    /// - Returns: The resolved dynamic color, or Gamma's color fallback when
    ///   resolution fails.
    func color<Scope: ThemeAliasScope>(_ alias: Theme.Alias<Scope>) -> Color
    where Scope.Family == Theme.Colors {
        let key = alias.rawValue
        let snapshot = currentSnapshot
        let cacheKey = ThemeTokenCacheKey(scope: snapshot.cacheScope, alias: key)

        guard let selectedModes = selection(
            for: Theme.Colors.self,
            alias: key,
            in: snapshot
        ) else {
            return fallbackColor(light: .black, dark: .white, cacheKey: cacheKey)
        }

        guard let rawColor = snapshot.theme.colors[key] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Colors.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token does not exist in theme \(snapshot.theme.id)"
            )
            return fallbackColor(light: .black, dark: .white, cacheKey: cacheKey)
        }

        if let groupName = Scope.groupName, rawColor.group != groupName {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Colors.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token belongs to group \(rawColor.group.debugDescription), not \(groupName.debugDescription)"
            )
            return fallbackColor(light: .black, dark: .white, cacheKey: cacheKey)
        }

        if let color = ThemeProxyCache.colorCache[cacheKey] {
            return color
        }

        let lightMode = rawColor.modes[selectedModes.light]
        let darkMode = rawColor.modes[selectedModes.dark]

        if lightMode == nil {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Colors.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "mode \(selectedModes.light) is missing"
            )
        }
        if darkMode == nil {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Colors.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "mode \(selectedModes.dark) is missing"
            )
        }

        let uiLight = lightMode.flatMap { UIColor(hex: $0.hex)?.withAlphaComponent($0.alpha) } ?? .black
        let uiDark = darkMode.flatMap { UIColor(hex: $0.hex)?.withAlphaComponent($0.alpha) } ?? .white
        return fallbackColor(light: uiLight, dark: uiDark, cacheKey: cacheKey)
    }

    /// Resolves a font alias to a ``ThemeFont`` for the current layout direction.
    /// Pass the result to Gamma's `View.font(_:)` modifier.
    ///
    /// - Parameter alias: An alias from any group owned by ``Theme/Fonts``.
    /// - Returns: The resolved theme font, or a system-font fallback when
    ///   resolution fails.
    func font<Scope: ThemeAliasScope>(_ alias: Theme.Alias<Scope>) -> ThemeFont
    where Scope.Family == Theme.Fonts {
        let key = alias.rawValue
        let snapshot = currentSnapshot
        let cacheKey = ThemeTokenCacheKey(scope: snapshot.cacheScope, alias: key)

        guard let selectedModes = selection(
            for: Theme.Fonts.self,
            alias: key,
            in: snapshot
        ) else {
            return .fallback
        }

        guard let rawFont = snapshot.theme.fonts[key] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Fonts.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token does not exist in theme \(snapshot.theme.id)"
            )
            return .fallback
        }

        if let groupName = Scope.groupName, rawFont.group != groupName {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Fonts.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token belongs to group \(rawFont.group.debugDescription), not \(groupName.debugDescription)"
            )
            return .fallback
        }

        if let cached = ThemeProxyCache.fontCache[cacheKey] {
            return cached
        }

        guard let primaryMode = rawFont.modes[selectedModes.primary] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Fonts.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "primary mode \(selectedModes.primary) is missing"
            )
            return .fallback
        }

        let missingCascades = selectedModes.cascades.filter { rawFont.modes[$0] == nil }
        if !missingCascades.isEmpty {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Fonts.key,
                alias: key,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "cascade modes \(missingCascades.joined(separator: ", ")) are missing"
            )
        }

        let cascadeFontNames = selectedModes.cascades.compactMap {
            rawFont.modes[$0]?.fontName
        }

        let result = ThemeFont(
            fontName: primaryMode.fontName,
            cascadeFontNames: cascadeFontNames,
            fontSize: primaryMode.fontSize,
            lineHeight: primaryMode.lineHeight,
            letterSpacing: primaryMode.letterSpacing,
            textCase: .init(primaryMode.textCase),
            textStyle: rawFont.textStyle
        )

        ThemeProxyCache.fontCache[cacheKey] = result
        return result
    }

    /// Resolves a unit alias to a `CGFloat` for this platform.
    ///
    /// - Parameter alias: An alias from any group owned by ``Theme/Units``.
    /// - Returns: The resolved unit, or `0` when resolution fails.
    func unit<Scope: ThemeAliasScope>(_ alias: Theme.Alias<Scope>) -> CGFloat
    where Scope.Family == Theme.Units {
        let snapshot = currentSnapshot
        let cacheKey = ThemeTokenCacheKey(scope: snapshot.cacheScope, alias: alias.rawValue)

        guard let selectedMode = selection(
            for: Theme.Units.self,
            alias: alias.rawValue,
            in: snapshot
        ) else {
            return 0
        }

        guard let rawUnit = snapshot.theme.units[alias.rawValue] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Units.key,
                alias: alias.rawValue,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token does not exist in theme \(snapshot.theme.id)"
            )
            return 0
        }

        if let groupName = Scope.groupName, rawUnit.group != groupName {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Units.key,
                alias: alias.rawValue,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the token belongs to group \(rawUnit.group.debugDescription), not \(groupName.debugDescription)"
            )
            return 0
        }

        if let cached = ThemeProxyCache.unitCache[cacheKey] {
            return cached
        }

        guard let result = rawUnit.modes[selectedMode] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Theme.Units.key,
                alias: alias.rawValue,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "mode \(selectedMode) is missing"
            )
            return 0
        }

        ThemeProxyCache.unitCache[cacheKey] = result
        return result
    }

    private func fallbackColor(
        light: UIColor,
        dark: UIColor,
        cacheKey: ThemeTokenCacheKey
    ) -> Color {
        let uiColor = UIColor { @Sendable trait in // @Sendable prevents a crash in SwiftUI.AsyncRenderer.
            switch trait.userInterfaceStyle {
            case .dark: dark
            default: light
            }
        }

        let result = Color(uiColor: uiColor)
        ThemeProxyCache.colorCache[cacheKey] = result
        return result
    }

    private func selection<Extension: ThemeExtension>(
        for _: Extension.Type,
        alias: String,
        in snapshot: Snapshot
    ) -> Extension.Selection? {
        guard let selection = snapshot.modes[Extension.self] else {
            ThemeDiagnostics.resolutionFailure(
                kind: Extension.key,
                alias: alias,
                themeInstanceID: snapshot.theme.instanceID,
                detail: "the resolver did not provide a selection"
            )
            return nil
        }
        return selection
    }
}
