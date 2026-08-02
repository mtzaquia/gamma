# Gamma Sample App

The sample app is a small component catalogue that exercises the complete Gamma path: build-time alias generation, bundled theme decoding, mode resolution, custom font registration, and SwiftUI token use.

Open `SampleApp.xcodeproj` and run the shared `SampleApp` scheme. The library supports iOS 17+ and macOS 14+, while this sample project currently targets iOS 17.5+.

## What to try

- Switch between LTR and RTL. The active body face changes from `NotoSans-Regular` to `NotoSansArabic-Regular`, with the other face retained as a cascade.
- Change the simulator appearance. Colors resolve from the theme's `day` and `night` modes.
- Run on an iPhone and an iPad, or otherwise change horizontal size class. Spacing and radius values use compact and regular unit modes respectively.
- Inspect typography, color, gradient, and responsive-unit sections built entirely from generated aliases.
- Inspect the theme spark and token-flow artwork loaded through generated icon and illustration aliases.

`SampleThemeModeResolver` owns those mappings. The theme itself only declares named modes, including the custom `gradients` family. The app registers `Theme.Gradients`, decodes its stop aliases through `GradientToken`, and renders the generated `.brandHero` alias as a SwiftUI `LinearGradient`. The second gradient preview uses `ThemeTokenOverride` and `WithThemeOverrides` to replace that extension token inside one subtree.

## Code generation

The app target has `GammaBuildPlugin` attached. A normal build discovers `SampleTheme.theme.json` and `Assets.xcassets`, generates the `.sampleTheme` resource handle, group-scoped token aliases such as `.surfaceBackground`, `.typographyBody`, and `.spacingMedium`, plus asset aliases `.themeSpark` and `.tokenFlow`, then compiles them with the app.

Generated files do not appear in the project navigator. The build log should contain:

```text
Apply build tool plug-in “GammaBuildPlugin” to target “SampleApp”
Generated Gamma+Tokens.generated.swift
```

If Xcode compiled the plugin but aliases are missing, use **Product → Clean Build Folder** and reopen the project. See [Code generation](../docs/code-generation.md#troubleshooting-xcode) for the full checklist.

## Fonts

The bundled Noto Sans and Noto Sans Arabic files come from the official [Noto Fonts repository](https://github.com/notofonts/noto-fonts). They are redistributed under the SIL Open Font License 1.1 included in [OFL.txt](SampleApp/Fonts/OFL.txt).

The root installs the generated theme resource and both bundled font URLs in one call: `.theme(ThemeResource.sampleTheme, modeResolver: SampleThemeModeResolver(), fontURLs: SampleTheme.fontURLs)`. Naming `ThemeResource` explicitly keeps Swift's overload resolution unambiguous while the declaration itself remains build-plug-in generated. Gamma caches the decoded resource, discovers the PostScript names, registers each face before rendering, and avoids repeating successful work during later body evaluations.

## UI test

The shared UI-test scheme verifies that the catalogue launches, fonts register, RTL changes the resolver's primary face, and both generated asset aliases load images.

```sh
xcodebuildmcp simulator test \
  --project-path SampleApp/SampleApp.xcodeproj \
  --scheme SampleAppUITests \
  --simulator-name "iPhone 15 Pro"
```
