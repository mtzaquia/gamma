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

public extension View {
    /// Loads a generated bundled theme and injects it into the view hierarchy.
    ///
    /// The decoded value is cached by resource and bundle so repeated SwiftUI
    /// body evaluations do not reread the JSON or create new theme identities.
    /// Use ``ThemeResource/load(from:)`` directly when loading failure is recoverable.
    ///
    /// - Parameters:
    ///   - resource: The generated theme resource to install.
    ///   - bundle: The bundle that contains the resource.
    ///   - fontURLs: Local font-file URLs to register before rendering.
    func theme(
        _ resource: ThemeResource,
        bundle: Bundle = .main,
        fontURLs: [URL] = []
    ) -> some View {
        theme(
            ThemeResourceCache.load(resource, from: bundle),
            fontURLs: fontURLs
        )
    }

    /// Loads a generated bundled theme with custom mode and family support.
    ///
    /// - Parameters:
    ///   - resource: The generated theme resource to install.
    ///   - bundle: The bundle that contains the resource.
    ///   - modeResolver: The policy that selects built-in and custom token modes.
    ///   - extensions: Consumer-defined token families to validate during installation.
    ///   - fontURLs: Local font-file URLs to register before rendering.
    func theme<ModeResolver: ThemeModeResolving>(
        _ resource: ThemeResource,
        bundle: Bundle = .main,
        modeResolver: ModeResolver,
        extensions: [ThemeExtensionRegistration] = [],
        fontURLs: [URL] = []
    ) -> some View {
        theme(
            ThemeResourceCache.load(resource, from: bundle),
            modeResolver: modeResolver,
            extensions: extensions,
            fontURLs: fontURLs
        )
    }

    /// Injects a theme into the view hierarchy, applying default font and text colors.
    ///
    /// - Parameters:
    ///   - rawTheme: The decoded theme to activate.
    ///   - fontURLs: Local font-file URLs to register before rendering.
    func theme(
        _ rawTheme: RawTheme,
        fontURLs: [URL] = []
    ) -> some View {
        theme(
            rawTheme,
            modeResolver: DefaultThemeModeResolver(),
            fontURLs: fontURLs
        )
    }

    /// Injects a theme, mode resolver, and consumer-defined token families.
    ///
    /// - Parameters:
    ///   - rawTheme: The decoded theme to activate.
    ///   - modeResolver: The policy that selects built-in and custom token modes.
    ///   - extensions: Consumer-defined token families to validate during installation.
    ///   - fontURLs: Local font-file URLs to register before rendering.
    func theme<ModeResolver: ThemeModeResolving>(
        _ rawTheme: RawTheme,
        modeResolver: ModeResolver,
        extensions: [ThemeExtensionRegistration] = [],
        fontURLs: [URL] = []
    ) -> some View {
        self
            .modifier(ThemeModifier(defaults: rawTheme.defaults, fontURLs: fontURLs))
            .environment(\.theme, rawTheme)
            .environment(\.themeModeResolver, AnyThemeModeResolver(modeResolver))
            .environment(\.themeExtensions, extensions)
    }
}

private struct ThemeModifier: ViewModifier {
    @ThemeReader private var theme

    let fontAlias: Theme.Alias<Theme.Fonts>
    let primaryTextColorAlias: Theme.Alias<Theme.Colors>
    let secondaryTextColorAlias: Theme.Alias<Theme.Colors>?

    func body(content: Content) -> some View {
        let themeFont = theme.font(fontAlias)

        Group {
            if let secondaryTextColorAlias {
                content
                    .foregroundStyle(
                        theme.color(primaryTextColorAlias),
                        theme.color(secondaryTextColorAlias)
                    )
            } else {
                content
                    .foregroundStyle(theme.color(primaryTextColorAlias))
            }
        }
        .font(themeFont)
    }

    init(defaults: RawDefaults, fontURLs: [URL]) {
        fontAlias = Theme.Alias(rawValue: defaults.font)
        primaryTextColorAlias = Theme.Alias(rawValue: defaults.primaryTextColor)
        secondaryTextColorAlias = defaults.secondaryTextColor.map(Theme.Alias.init(rawValue:))
        Registrar.registerFonts(at: fontURLs)
    }
}
