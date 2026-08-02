# Gamma Sample App

The sample app is a guided catalogue of five focused experiments. Together they exercise the complete Gamma path: build-time alias generation, bundled theme decoding, mode resolution, custom font registration, consumer-defined token families, scoped overrides, and SwiftUI token use.

Open `SampleApp.xcodeproj` and run the shared `SampleApp` scheme. The library supports iOS 17+ and macOS 14+, while this sample project currently targets iOS 17.5+.

## Scenario catalogue

| User promise | Public API | Primary action | Visible outcome | Important alternate state | UI-test assertion |
| --- | --- | --- | --- | --- | --- |
| Colors and custom families follow appearance | `ThemeModeResolving`, `ThemeProxy.color(_:)`, `ThemeProxy.resolve(_:)` | Switch Light/Dark | Palette and brand gradient resolve day/night modes in place | Both appearances | Status identifies the selected modes and both previews remain present |
| Typography adapts to readers and scripts | `.theme(..., fontURLs:)`, `ThemeFontModeSelection`, `DSText` | Switch writing direction and text size | Primary Noto face, cascade direction, and scaled metrics update | RTL and accessibility Dynamic Type | Status reports the Arabic face and accessibility size; bundled faces are registered |
| Units adapt without changing component code | `ThemeProxy.unit(_:)` | Switch Compact/Regular | Spacing bars, padding, and corner radius resolve new values | Regular size class | Status changes from `8 / 16 / 24` to `12 / 24 / 36` points |
| Overrides remain scoped | `ThemeTokenOverride`, `ThemeOverrides`, `WithThemeOverrides` | Apply campaign override | Accent, radius, and custom gradient change only inside one subtree | Override removed again | Status moves active and inactive while the base preview remains |
| Generated resources stay typed | `ThemeResource`, `Theme.IconAlias`, `Theme.AssetAlias` | Select Icon/Illustration | Generated aliases load their matching catalogue artwork | Both asset kinds | Each generated image appears after selection |

`SampleThemeModeResolver` owns the appearance, direction, size-class, and custom-family mappings. The theme itself only declares named modes. The app registers `Theme.Gradients`, decodes its stop aliases through `GradientToken`, and renders the generated `.brandHero` alias as a SwiftUI `LinearGradient`.

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

## Deterministic UI tests

The shared UI-test scheme keeps a catalogue smoke test and launches every scenario directly for focused behavior checks. Test-only routing is enabled only when `UI_TESTING` is present; normal app launches always open the catalogue.

Available direct paths are:

- `--scenario=appearance-modes`
- `--scenario=adaptive-typography`
- `--scenario=responsive-units`
- `--scenario=scoped-overrides`
- `--scenario=generated-resources`

For deterministic visual inspection, combine a direct scenario with its relevant alternate-state seeds:

- `--appearance=dark`
- `--direction=rtl --type-size=accessibility`
- `--width=regular`
- `--overrides=active`
- `--resource=illustration`

Seeds are ignored unless `UI_TESTING` is also present.

```sh
xcodebuildmcp simulator test \
  --project-path SampleApp/SampleApp.xcodeproj \
  --scheme SampleAppUITests \
  --simulator-name "iPhone 16 Pro"
```
