# Mode resolution

Mode names belong to the design system, not the library. A resolver translates the current SwiftUI environment into the names used by one theme.

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
    ResolvedThemeModes(
      colors: ThemeColorModeSelection(light: "day", dark: "night"),
      fonts: context.layoutDirection == .rightToLeft
        ? ThemeFontModeSelection(primary: "arabic", cascades: ["latin"])
        : ThemeFontModeSelection(primary: "latin", cascades: ["arabic"]),
      unit: context.horizontalSizeClass == .regular
        ? "regular"
        : "compact"
    )
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
| `layoutDirection` | Choose font priority and cascade order for LTR and RTL content. |
| `horizontalSizeClass` | Choose compact and regular unit modes. It may be `nil`. |

Color scheme is not part of the context. The resolver selects a light/dark pair, and the returned `Color` follows the system appearance dynamically.

## Selections

One resolution returns all token policies together.

| Selection | Meaning |
| --- | --- |
| `colors.light` | Color mode used in light appearance. |
| `colors.dark` | Color mode used in dark appearance. |
| `fonts.primary` | Font mode that supplies metrics and the primary face. |
| `fonts.cascades` | Ordered fallback faces appended to the font descriptor. |
| `unit` | Unit mode used for spacing, sizing, and radius aliases. |

Every selected mode must exist on every token of that kind. Missing selections produce a consolidated diagnostic instead of silently changing the resolver policy per token.

## Standard resolver

`DefaultThemeModeResolver` preserves the library conventions:

- colors: `light` and `dark`;
- fonts: `default`, with no cascade modes;
- units: `default`.

Use `.theme(.app)` for a generated bundled resource that follows those names, or `.theme(rawTheme)` for an already decoded value such as a server response.

The standard resolver does not vary fonts or units with layout direction or size class. Use a custom resolver when those environment values should select script-specific faces, cascade order, or responsive measurements.

## SwiftUI updates

`@ThemeReader` participates in SwiftUI's dynamic-property lifecycle. It reads the resolver, layout direction, size class, and active theme from one environment snapshot during view evaluation. Changing one of those values invalidates the consuming view through SwiftUI's normal dependency tracking.

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

Color scheme and Dynamic Type do not need to be resolver inputs. Dynamic `UIColor` values follow appearance immediately, and the font modifier rebuilds its scaled concrete font when `dynamicTypeSize` changes. Layout direction and horizontal size class remain resolver inputs, so either change creates a fresh resolution snapshot; the standard resolver keeps returning `default`, while custom resolvers may choose different modes.

Resolved token caches use the decoded theme identity, composed override identity, resolver identity, and relevant environment context. Returned mode-name strings and color scheme are not separate cache-key components. Concrete font caches include Dynamic Type size. All caches are bounded.

Next: [Using tokens](tokens.md)
