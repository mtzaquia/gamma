# 🌅 Gamma

[![Tests](https://github.com/mtzaquia/gamma/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/mtzaquia/gamma/actions/workflows/tests.yml)
[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://www.swift.org/)
[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://github.com/mtzaquia/gamma/blob/main/Package.swift)
![Class A](https://img.shields.io/badge/class-A-gold)

`Gamma` is a battle-tested, streamlined design system foundation for your apps.

Describe colors, typography, and units in one JSON theme. Decide how its modes map to the current SwiftUI environment. Gamma validates the result, generates type-safe aliases, and resolves those aliases where views use them.

- Dynamic colors that follow light and dark appearance.
- Typography that scales with Dynamic Type and cascades across scripts.
- Units that can adapt to size class or any policy your design system names.
- Scoped token overrides without replacing the installed theme.
- Bundled or server-provided themes, with registration of app-supplied font files.
- Swift-native generation through Xcode, SwiftPM, or a command-line executable.

```swift
@ThemeReader private var theme

var body: some View {
  VStack(alignment: .leading, spacing: theme.unit(.spacingMedium)) {
    DSText("A coherent visual voice")
      .font(theme.font(.typographyDisplay))

    DSText("Resolved from the active theme.")
      .font(theme.font(.typographyBody))
      .foregroundStyle(theme.color(.textSecondary))
  }
}
```

## Install

Gamma 2.0.0 supports iOS 17+ and macOS 14+, and uses the Swift 6.2 package format.

```swift
dependencies: [
  .package(
    url: "https://github.com/mtzaquia/gamma.git",
    from: "2.0.0"
  ),
]
```

## Five-minute start

Add an `App.theme.json` file to the app target, with target membership enabled, then attach `GammaBuildPlugin` under **Build Phases → Run Build Tool Plug-ins**. The plugin validates the theme and turns its filename and token keys into Swift declarations during the build. It searches target folders recursively and fails the build with filename and target-membership guidance if it cannot find a `*.theme.json` input.

Install the generated resource at the root of the app:

```swift
@main
struct ExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .theme(.app)
    }
  }
}
```

The modifier loads and caches the generated bundled resource. A missing or malformed bundled theme fails immediately as an application configuration error; use the explicit throwing resource API only when the app needs recoverable loading UI.

Read the active theme in any descendant view with `@ThemeReader`. It resolves generated aliases against the current theme and SwiftUI environment.

```swift
struct ContentView: View {
  @ThemeReader private var theme

  var body: some View {
    DSText("Hello, design system")
      .font(theme.font(.typographyBody))
      .foregroundStyle(theme.color(.textPrimary))
      .padding(theme.unit(.spacingMedium))
  }
}
```

The standard resolver expects `light` and `dark` color modes plus a `default` mode for fonts and units. Use a custom resolver for script-aware font cascades, responsive units, or any other vocabulary your design system defines.

```swift
ContentView()
  .theme(.app, modeResolver: AppThemeModeResolver())
```

That is the core idea: the theme owns raw design values, the resolver chooses modes for the current environment, and views use `@ThemeReader` to retrieve concrete values.

The generated `.app` resource and token aliases come from the same `App.theme.json` input. If a target contains multiple exported themes, Gamma generates all resource handles but only one alias surface; generation fails with both file paths if their alias contracts drift.

Server themes use the same runtime path: the app downloads and stores the JSON and font files, then passes the decoded `RawTheme` and local `fontURLs` to `.theme(...)`. Gamma validates, registers, and activates them without owning networking or storage policy. After registration, it also checks that every resolver-selected primary and cascade PostScript name is available. Remote themes must preserve the alias contract compiled into the app; a runtime-only payload is schema-validated up front and a missing compiled alias is diagnosed when it is read. See [Using tokens](docs/tokens.md#server-provided-themes-and-fonts).

## Documentation

- [Getting started](docs/getting-started.md) — install a theme and render the first tokens.
- [Theme format](docs/themes.md) — defaults, colors, fonts, units, and validation rules.
- [Mode resolution](docs/modes.md) — map appearance, layout direction, and size class to theme modes.
- [Using tokens](docs/tokens.md) — resolve colors, typography, units, and assets.
- [Theme extensions](docs/theme-extensions.md) — define, generate, select, validate, and resolve custom token families.
- [Code generation](docs/code-generation.md) — build and command plugins, CLI use, naming, and troubleshooting.
- [Overrides](docs/overrides.md) — replace token modes inside one view subtree.
- [Diagnostics](docs/diagnostics.md) — validation, assertions, fallbacks, and debug logging.

## Sample app

Open [`SampleApp/SampleApp.xcodeproj`](SampleApp/SampleApp.xcodeproj) to explore day/night colors, LTR and RTL font cascading, runtime font registration, responsive units, and build-time token and asset aliases.

## License

Copyright (c) 2026 @mtzaquia

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
