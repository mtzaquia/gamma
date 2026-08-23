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
    /// The content mounts immediately using its inherited theme while Gamma
    /// loads the resource. Supplied fonts register asynchronously; text uses the
    /// system fallback until registration completes and then refreshes in place.
    /// If the resource changes later, the installed theme remains active until
    /// its replacement has loaded.
    /// Use ``ThemeResource/load(from:)`` directly when loading failure is recoverable.
    ///
    /// - Parameters:
    ///   - resource: The generated theme resource to install.
    ///   - bundle: The bundle that contains the resource.
    ///   - fontURLs: Local font-file URLs to register after mounting the content.
    func theme(
        _ resource: ThemeResource,
        bundle: Bundle = .main,
        fontURLs: [URL] = []
    ) -> some View {
        ThemeInstallationView(
            content: self,
            source: .resource(resource, bundle: bundle),
            modeResolver: DefaultThemeModeResolver(),
            extensions: [],
            fontURLs: fontURLs
        )
    }

    /// Loads a generated bundled theme with custom mode and family support.
    ///
    /// The content mounts immediately using its inherited theme while Gamma
    /// loads the resource. Supplied fonts register asynchronously; text uses the
    /// system fallback until registration completes and then refreshes in place.
    /// If the resource changes later, the installed theme remains active until
    /// its replacement has loaded.
    ///
    /// - Parameters:
    ///   - resource: The generated theme resource to install.
    ///   - bundle: The bundle that contains the resource.
    ///   - modeResolver: The policy that selects built-in and custom token modes.
    ///   - extensions: Consumer-defined token families to validate during installation.
    ///   - fontURLs: Local font-file URLs to register after mounting the content.
    func theme<ModeResolver: ThemeModeResolving>(
        _ resource: ThemeResource,
        bundle: Bundle = .main,
        modeResolver: ModeResolver,
        extensions: [ThemeExtensionRegistration] = [],
        fontURLs: [URL] = []
    ) -> some View {
        ThemeInstallationView(
            content: self,
            source: .resource(resource, bundle: bundle),
            modeResolver: modeResolver,
            extensions: extensions,
            fontURLs: fontURLs
        )
    }

    /// Injects a theme into the view hierarchy, applying default font and text colors.
    ///
    /// The decoded theme is available to the subtree immediately. Supplied
    /// fonts register asynchronously; text uses the system fallback until
    /// registration completes and then refreshes without replacing the subtree.
    ///
    /// - Parameters:
    ///   - rawTheme: The decoded theme to activate.
    ///   - fontURLs: Local font-file URLs to register after mounting the content.
    func theme(
        _ rawTheme: RawTheme,
        fontURLs: [URL] = []
    ) -> some View {
        ThemeInstallationView(
            content: self,
            source: .rawTheme(rawTheme),
            modeResolver: DefaultThemeModeResolver(),
            extensions: [],
            fontURLs: fontURLs
        )
    }

    /// Injects a theme, mode resolver, and consumer-defined token families.
    ///
    /// The decoded theme is available to the subtree immediately. Supplied
    /// fonts register asynchronously; text uses the system fallback until
    /// registration completes and then refreshes without replacing the subtree.
    ///
    /// - Parameters:
    ///   - rawTheme: The decoded theme to activate.
    ///   - modeResolver: The policy that selects built-in and custom token modes.
    ///   - extensions: Consumer-defined token families to validate during installation.
    ///   - fontURLs: Local font-file URLs to register after mounting the content.
    func theme<ModeResolver: ThemeModeResolving>(
        _ rawTheme: RawTheme,
        modeResolver: ModeResolver,
        extensions: [ThemeExtensionRegistration] = [],
        fontURLs: [URL] = []
    ) -> some View {
        ThemeInstallationView(
            content: self,
            source: .rawTheme(rawTheme),
            modeResolver: modeResolver,
            extensions: extensions,
            fontURLs: fontURLs
        )
    }
}

private struct ThemeInstallationView<Content: View, ModeResolver: ThemeModeResolving>: View {
    @Environment(\.theme) private var inheritedTheme
    @State private var installedTheme: RawTheme?
    @State private var fontRegistrationRevision = 0
    @State private var completedFontInstallationID: ThemeInstallationID?

    let content: Content
    let source: ThemeInstallationSource
    let modeResolver: ModeResolver
    let extensions: ThemeExtensionRegistrations
    let fontURLs: [URL]

    var body: some View {
        content
            .modifier(ThemeModifier(defaults: activeTheme.defaults))
            .environment(\.theme, activeTheme)
            .environment(\.themeModeResolver, AnyThemeModeResolver(modeResolver))
            .environment(\.themeExtensions, extensions)
            .environment(\.themeFontRegistration, fontRegistration)
            .task(id: installationID) {
                let activeInstallationID = installationID
                let theme = await source.load()
                guard !Task.isCancelled else { return }
                installedTheme = theme

                guard !fontURLs.isEmpty else { return }
                let postScriptNames = await Registrar.registerFonts(at: fontURLs)

                guard !Task.isCancelled else { return }
                ThemeProxyCache.invalidateFonts(named: postScriptNames)

                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    fontRegistrationRevision &+= 1
                    completedFontInstallationID = activeInstallationID
                }
            }
    }

    init(
        content: Content,
        source: ThemeInstallationSource,
        modeResolver: ModeResolver,
        extensions: [ThemeExtensionRegistration],
        fontURLs: [URL]
    ) {
        self.content = content
        self.source = source
        self.modeResolver = modeResolver
        self.extensions = ThemeExtensionRegistrations(extensions)
        self.fontURLs = fontURLs
        _installedTheme = State(initialValue: source.immediateTheme)
    }

    private var activeTheme: RawTheme {
        source.immediateTheme ?? installedTheme ?? inheritedTheme
    }

    private var installationID: ThemeInstallationID {
        ThemeInstallationID(source: source.id, fontURLs: fontURLs)
    }

    private var fontRegistration: ThemeFontRegistrationContext {
        ThemeFontRegistrationContext(
            revision: fontRegistrationRevision,
            isPending: !fontURLs.isEmpty && completedFontInstallationID != installationID
        )
    }
}

private enum ThemeInstallationSource {
    case rawTheme(RawTheme)
    case resource(ThemeResource, bundle: Bundle)

    var id: ThemeInstallationSourceID {
        switch self {
        case let .rawTheme(theme):
            .rawTheme(theme)
        case let .resource(resource, bundle):
            .resource(resource, bundleURL: bundle.bundleURL.standardizedFileURL)
        }
    }

    var immediateTheme: RawTheme? {
        guard case let .rawTheme(theme) = self else { return nil }
        return theme
    }

    func load() async -> RawTheme {
        switch self {
        case let .rawTheme(theme):
            theme
        case let .resource(resource, bundle):
            await ThemeResourceCache.load(resource, from: bundle)
        }
    }
}

private struct ThemeInstallationID: Hashable {
    let source: ThemeInstallationSourceID
    let fontURLs: [URL]
}

private enum ThemeInstallationSourceID: Hashable {
    case rawTheme(RawTheme)
    case resource(ThemeResource, bundleURL: URL)
}

private struct ThemeModifier: ViewModifier {
    @ThemeReader private var theme

    let fontAlias: Theme.Alias<Theme.Fonts>
    let primaryTextColorAlias: Theme.Alias<Theme.Colors>
    let secondaryTextColorAlias: Theme.Alias<Theme.Colors>?

    func body(content: Content) -> some View {
        let themeFont = theme.font(fontAlias)
        let secondaryTextStyle = secondaryTextColorAlias.map {
            AnyShapeStyle(theme.color($0))
        } ?? AnyShapeStyle(.secondary)

        content
            .foregroundStyle(
                theme.color(primaryTextColorAlias),
                secondaryTextStyle
            )
            .font(themeFont)
    }

    init(defaults: RawDefaults) {
        fontAlias = Theme.Alias(rawValue: defaults.font)
        primaryTextColorAlias = Theme.Alias(rawValue: defaults.primaryTextColor)
        secondaryTextColorAlias = defaults.secondaryTextColor.map(Theme.Alias.init(rawValue:))
    }
}
