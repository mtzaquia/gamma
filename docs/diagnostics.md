# Diagnostics

Gamma reports schema drift at the boundary where it can still be understood: theme decoding, mode selection, override application, or individual token resolution.

## Decode-time validation

`RawTheme` validates the complete schema during `Decodable` initialization. Semantic issues that can be evaluated together are returned in one `DecodingError` whose description contains every discovered path. Structural type mismatches and invalid enum values report their decoding path normally.

```swift
do {
  theme = try JSONDecoder().decode(RawTheme.self, from: data)
} catch {
  // Treat the payload as invalid; error describes all schema issues found.
}
```

This includes broken defaults, token metadata, empty mode dictionaries, invalid colors, invalid font metrics, unknown text cases, and non-finite units.

Consumer-defined root keys remain opaque at decode time because `RawTheme` does not know their token type. Passing `ThemeExtensionRegistration` values to `.theme(..., extensions:)` validates those dictionaries during installation. Missing keys, malformed shared metadata, empty modes, missing resolver selections, selected-mode drift, and consumer-specific decoding failures join the consolidated theme diagnostic.

## Font registration

`.theme(..., fontURLs:)` checks every supplied local file before rendering. Unreadable files, missing PostScript names, and Core Text registration errors are collected into one warning and one debug assertion instead of producing a stream of per-file messages. Core Text's already-registered response is treated as success.

At `.trace`, successful registration logs include both the filename and the discovered PostScript name. This makes it possible to compare the file with the theme's `fontName` without introducing a separate font manifest.

Registration diagnostics describe supplied files. A JSON `fontName` may legitimately refer to a system font or a face registered elsewhere, so Gamma does not require every theme font to appear in `fontURLs`. Keep the JSON value equal to the actual PostScript name; UIKit may substitute another face when an unavailable name reaches its font descriptor.

After registering supplied files, runtime theme validation checks every resolver-selected primary and cascade face with UIKit. An unavailable PostScript name is included in the theme's consolidated warning and triggers the same debug assertion as other selected-mode drift.

## Resolver validation

A theme can be structurally valid while still lacking modes selected by its resolver. The root `.theme(...)` modifier contains a `@ThemeReader`, so Gamma checks the complete theme against `ResolvedThemeModes` during installation and repeats that check for a new theme or resolution context.

Issues are consolidated by path and reported once for each theme, mode selection, and override identity. Repeated body evaluation does not repeat the same warning.

In debug builds, validation and resolution failures also trigger an assertion so schema drift is visible during development. The warning remains available through unified logging.

## Resolution fallbacks

After reporting a failure, release builds keep rendering with deliberately conspicuous fallbacks:

| Failure | Fallback |
| --- | --- |
| Missing or invalid color side | Black in light appearance, white in dark appearance. |
| Missing font token or primary mode | Preferred system body font. |
| Unavailable selected PostScript font name | UIKit substitutes an available face after Gamma reports it. |
| Missing unit token or mode | `0`. |
| Missing custom token, selection, or selected mode | `ThemeProxy.resolve(_:)` returns `nil`; the consumer accessor supplies its domain fallback. |

Fallbacks are a last line of defense, not schema defaults. Fix the diagnostic rather than designing around them.

## Optional debug logs

Set `Gamma.debug` during app startup to inspect successful operations in debug builds.

```swift
@main
struct ExampleApp: App {
  init() {
    Gamma.debug = .trace
  }

  var body: some Scene {
    WindowGroup { ContentView() }
  }
}
```

| Level | Output |
| --- | --- |
| `.off` | No optional success logs. Validation warnings still appear. |
| `.normal` | Theme override activity. |
| `.trace` | Normal logs plus successful theme validation and font registration. |

Logs use the `dev.gamma` subsystem and `Gamma` category.

Next: [Getting started](getting-started.md)
