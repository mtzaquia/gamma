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
    /// Gamma loads the resource and registers supplied fonts from a view task,
    /// then mounts the themed content. If the resource changes later, the
    /// currently installed theme remains active until its replacement is ready.
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
    /// Gamma loads the resource and registers supplied fonts from a view task,
    /// then mounts the themed content. If the resource changes later, the
    /// currently installed theme remains active until its replacement is ready.
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
    /// When `fontURLs` is empty, the decoded theme is available to the subtree
    /// immediately. Otherwise Gamma registers the fonts from a view task and
    /// mounts the themed content after registration completes. A later theme
    /// replacement keeps the currently installed theme active until its fonts
    /// are ready.
    ///
    /// - Parameters:
    ///   - rawTheme: The decoded theme to activate.
    ///   - fontURLs: Local font-file URLs to register before rendering.
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
    /// When `fontURLs` is empty, the decoded theme is available to the subtree
    /// immediately. Otherwise Gamma registers the fonts from a view task and
    /// mounts the themed content after registration completes. A later theme
    /// replacement keeps the currently installed theme active until its fonts
    /// are ready.
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
    @State private var installedTheme: RawTheme?

    let content: Content
    let source: ThemeInstallationSource
    let modeResolver: ModeResolver
    let extensions: ThemeExtensionRegistrations
    let fontURLs: [URL]

    var body: some View {
        Group {
            if let activeTheme {
                content
                    .modifier(ThemeModifier(defaults: activeTheme.defaults))
                    .environment(\.theme, activeTheme)
                    .environment(\.themeModeResolver, AnyThemeModeResolver(modeResolver))
                    .environment(\.themeExtensions, extensions)
            }
        }
        .task(id: installationID) {
            await Task.yield()
            guard !Task.isCancelled else { return }

            let theme = source.load()
            Registrar.registerFonts(at: fontURLs)

            guard !Task.isCancelled else { return }
            installedTheme = theme
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
        _installedTheme = State(initialValue: source.immediateTheme(fontURLs: fontURLs))
    }

    private var activeTheme: RawTheme? {
        source.immediateTheme(fontURLs: fontURLs) ?? installedTheme
    }

    private var installationID: ThemeInstallationID {
        ThemeInstallationID(source: source.id, fontURLs: fontURLs)
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

    func immediateTheme(fontURLs: [URL]) -> RawTheme? {
        guard fontURLs.isEmpty else { return nil }
        guard case let .rawTheme(theme) = self else { return nil }
        return theme
    }

    func load() -> RawTheme {
        switch self {
        case let .rawTheme(theme):
            theme
        case let .resource(resource, bundle):
            ThemeResourceCache.load(resource, from: bundle)
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
