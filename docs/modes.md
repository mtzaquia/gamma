# Mode resolution

Mode names belong to the design system, not the library. A resolver translates the current SwiftUI environment into the names used by one theme.

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
    var modes = ResolvedThemeModes(
      colors: ThemeColorModeSelection(light: "day", dark: "night"),
      fonts: context.layoutDirection == .rightToLeft
        ? ThemeFontModeSelection(primary: "arabic", cascades: ["latin"])
        : ThemeFontModeSelection(primary: "latin", cascades: ["arabic"]),
      unit: context.horizontalSizeClass == .regular
        ? "regular"
        : "compact"
    )
    modes[Theme.Gradients.self] = context.colorScheme == .dark
      ? "night"
      : "day"
    modes[Theme.Motion.self] = context.horizontalSizeClass == .compact
      ? "reduced"
      : "expressive"
    return modes
  }
}
```

Install it with the theme:

```swift
AppRoot()
  .theme(
    .app,
    modeResolver: AppThemeModeResolver()
  )
```

## Context

`ThemeModeContext` intentionally contains only environment values that have a current resolution use.

| Value | Typical use |
| --- | --- |
| `colorScheme` | Choose an appearance-specific mode for a custom family. A family may ignore it. |
| `layoutDirection` | Choose font priority and cascade order for LTR and RTL content. |
| `horizontalSizeClass` | Choose compact and regular unit modes. It may be `nil`. |

Built-in colors still use a light/dark pair so one returned `Color` can follow system appearance dynamically. Custom families are different: the resolver chooses one arbitrary mode name for each family. That choice may use color scheme, size class, layout direction, or simply be fixed.

## Selections

One resolution returns all token policies together.

| Selection | Meaning |
| --- | --- |
| `colors.light` | Color mode used in light appearance. |
| `colors.dark` | Color mode used in dark appearance. |
| `fonts.primary` | Font mode that supplies metrics and the primary face. |
| `fonts.cascades` | Ordered fallback faces appended to the font descriptor. |
| `unit` | Unit mode used for spacing, sizing, and radius aliases. |
| `modes[Theme.SomeFamily.self]` | One arbitrary mode selected for that custom family. |

Every selected mode must exist on every token of that kind. Missing selections produce a consolidated diagnostic instead of silently changing the resolver policy per token.

Custom selections are keyed by the generated family type, not its JSON string. This keeps unrelated families distinct even when they use the same mode names. Every registered family needs a selection, but it does not need appearance variants:

```swift
modes[Theme.Gradients.self] = context.colorScheme == .dark ? "night" : "day"
modes[Theme.Motion.self] = "default"
```

## Standard resolver

`DefaultThemeModeResolver` preserves the library conventions:

- colors: `light` and `dark`;
- fonts: `default`, with no cascade modes;
- units: `default`.

Use `.theme(.app)` for a generated bundled resource that follows those names, or `.theme(rawTheme)` for an already decoded value such as a server response.

The standard resolver does not vary fonts or units with layout direction or size class. Use a custom resolver when those environment values should select script-specific faces, cascade order, or responsive measurements.

## SwiftUI updates

`@ThemeReader` participates in SwiftUI's dynamic-property lifecycle. It reads the resolver, color scheme, layout direction, size class, and active theme from one environment snapshot during view evaluation. Changing one of those values invalidates the consuming view through SwiftUI's normal dependency tracking.

Keep `resolve(in:)` cheap, deterministic, and free of side effects. `@ThemeReader` captures one resolver result during each DynamicProperty update and every token read in that body evaluation uses the same snapshot. SwiftUI may still evaluate a body more than once. Do not capture environment values inside the resolver; use the supplied context.

Stateless resolvers need no identity boilerplate. If a resolver stores policy state that can change its answer for the same context, expose that state through `cacheIdentity`:

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  let campaign: String

  var cacheIdentity: AnyHashable { campaign }

  func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
    ResolvedThemeModes(
      colors: ThemeColorModeSelection(
        light: "\(campaign)-light",
        dark: "\(campaign)-dark"
      ),
      fonts: ThemeFontModeSelection(primary: "default"),
      unit: "default"
    )
  }
}
```

Passing a resolver with a new identity invalidates its resolved token scope.

Resolution is main-actor-bound because it runs inside SwiftUI's environment update. Client resolvers need no `nonisolated`, `Sendable`, or actor annotations.

Color scheme, layout direction, and horizontal size class are resolver inputs, so a change creates a fresh resolution snapshot. Built-in dynamic `UIColor` values still follow appearance directly; exposing color scheme lets consumer-defined families opt into appearance-specific selection when appropriate. Dynamic Type remains outside the resolver because the font modifier rebuilds its scaled concrete font when `dynamicTypeSize` changes.

Resolved token caches use the decoded theme identity, composed override identity, resolver identity, and relevant environment context. Returned mode-name strings are not separate cache-key components. Concrete font caches include Dynamic Type size. All caches are bounded.

Next: [Using tokens](tokens.md)
