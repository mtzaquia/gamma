# Getting started

At runtime, Gamma has three moving parts: a decoded `RawTheme`, a mode resolver, and `@ThemeReader` for resolving aliases in views. At build time, the optional generator turns theme keys and asset names into typed Swift declarations.

## Add the package

Add Gamma to the app target. For a Swift package target, include the library and build plugin together:

```swift
dependencies: [
  .package(
    url: "https://github.com/mtzaquia/gamma.git",
    exact: "2.0.0-beta.3"
  ),
],
targets: [
  .target(
    name: "MyFeature",
    dependencies: [
      .product(name: "Gamma", package: "Gamma"),
    ],
    resources: [
      .process("App.theme.json"),
    ],
    plugins: [
      .plugin(name: "GammaBuildPlugin", package: "Gamma"),
    ]
  ),
]
```

For an Xcode app target, add `https://github.com/mtzaquia/gamma.git` with the exact `2.0.0-beta.3` requirement, then:

1. Add the `Gamma` library product to the target.
2. Add the theme file with target membership enabled so it is copied into the app bundle.
3. Add `GammaBuildPlugin` under **Build Phases → Run Build Tool Plug-ins** and approve the plug-in when Xcode asks.

The plug-in searches the target's folders recursively and fails the build when it cannot find a file ending exactly in `.theme.json`, even when it finds an `.xcassets` catalogue. Treat that error as a target-membership or filename problem; generation should not silently disappear from the build.

## Create a theme

Add `App.theme.json` to the target. The `.theme.json` suffix lets the build plugin discover it.

```json
{
  "id": "app-default",
  "defaults": {
    "font": "typography/body",
    "primaryTextColor": "text/primary"
  },
  "colors": {
    "text/primary": {
      "name": "Primary text",
      "group": "text",
      "description": "Default foreground",
      "modes": {
        "light": { "hex": "#171A21", "alpha": 1 },
        "dark": { "hex": "#F6F7FB", "alpha": 1 }
      }
    }
  },
  "fonts": {
    "typography/body": {
      "name": "Body",
      "group": "typography",
      "description": "ios:body",
      "modes": {
        "default": {
          "fontSize": 17,
          "fontName": "Helvetica",
          "lineHeight": 24,
          "letterSpacing": 0,
          "textCase": "ORIGINAL"
        }
      }
    }
  },
  "units": {
    "spacing/medium": {
      "name": "Medium",
      "group": "spacing",
      "description": "Default content spacing",
      "modes": { "default": 16 }
    }
  }
}
```

The build plugin generates `.textPrimary`, `.typographyBody`, and `.spacingMedium` on the `TextAlias`, `TypographyAlias`, and `SpacingAlias` scopes. A grouped key is always exactly `<group>/<name>`; the first path component must match the `group` field.

This example follows the standard resolver contract: `light` and `dark` colors, plus `default` font and unit modes. Additional named modes require a custom resolver.

## Install it

Install the generated resource directly at the application boundary. The modifier loads and caches the bundled JSON, then fails immediately with a descriptive precondition if the resource is missing or invalid.

```swift
import Gamma
import SwiftUI

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

Installing a theme also applies its default font and foreground colors to the subtree.

`ThemeResource.app` is generated from the unchanged `App.theme.json` filename. Type inference lets the modifier spell it as `.app`, keeping resource lookup and token aliases tied to the same validated build input without requiring a second manifest or application wrapper.

The example is an Xcode app target, where the modifier defaults to `Bundle.main`. Inside a Swift package target, point it at that module's processed resources:

```swift
ContentView()
  .theme(.app, bundle: .module)
```

Custom resolution policy and bundled fonts stay part of the same installation call:

```swift
ContentView()
  .theme(
    .app,
    modeResolver: AppThemeModeResolver(),
    fontURLs: AppFonts.urls
  )
```

Gamma registers the supplied files before rendering, then checks that the resolver-selected primary and cascade PostScript names are available. The app only needs to provide local URLs; it does not need a second font manifest.

Use `try ThemeResource.app.load(from:)` directly only when missing or malformed bundled configuration is recoverable and the app wants to present its own fallback UI.

## Resolve tokens in a view

`@ThemeReader` participates in SwiftUI's dynamic-property lifecycle. It reads the active theme and current environment whenever the view updates.

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

## Multiple exported themes

You can add more than one Figma-exported `*.theme.json` file to a target without changing the individual file format. The build plugin emits a generated resource for each file:

```swift
DefaultRoot()
  .theme(.brandDefault)

HighContrastRoot()
  .theme(.brandHighContrast)
```

Those files form one theme family and therefore generate one shared alias surface. Every variant must define the same aliases and group assignment for colors, fonts, units, and custom families. If they drift, generation fails with the paths and exact missing, extra, or moved aliases.

This contract check applies to files visible to the generator. If a theme exists only on a server, it must preserve the aliases compiled into the client. Its schema and resolver-selected modes are validated at runtime; a missing compiled token that was not otherwise required by the schema is diagnosed when `@ThemeReader` tries to resolve it.

## Isolation and platform boundary

The `Gamma` SwiftUI target uses main-actor isolation by default, matching view and environment lifecycle. The shared schema target and code generator are platform-neutral. `RawTheme` and its raw token values are `Sendable`, so server JSON can be decoded and schema-validated away from the UI actor before the resulting value is installed. `ThemeOverrides` is also `Sendable`, but belongs to the iOS runtime target. Mode resolution runs on the main actor during SwiftUI's environment update, so an ordinary application `struct` can conform without concurrency annotations.

Host `swift test` exercises the portable schema and generator. Runtime and DynamicProperty tests execute against an iOS Simulator through the package workspace.

Next: [Theme format](themes.md) · [Mode resolution](modes.md)
