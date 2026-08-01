# Mode resolution

Mode names belong to the design system, not the library. A resolver translates the current SwiftUI environment into the names used by one theme.

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  func modes(for context: ThemeModeContext) -> ThemeModes {
    ThemeModes(
      colors: .init(light: "day", dark: "night"),
      fonts: context.layoutDirection == .rightToLeft
        ? .init(primary: "arabic", cascades: ["latin"])
        : .init(primary: "latin", cascades: ["arabic"]),
      units: context.horizontalSizeClass == .regular
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
| `colorScheme` | Choose modes that vary with light or dark appearance. |
| `layoutDirection` | Choose font priority and cascade order for LTR and RTL content. |
| `horizontalSizeClass` | Choose compact and regular unit modes. It may be `nil`. |

Built-in colors use a light/dark pair so one returned `Color` can follow system appearance dynamically.

## Selections

One `ThemeModes` value returns all token policies together. Its initializer requires the three built-in selections, so a resolver cannot accidentally omit one. Consumer-defined families are supplied as typed `ThemeModeAssignment` values.

| Family selection | Meaning |
| --- | --- |
| `colors` | Light and dark color mode names. |
| `fonts` | Primary font mode and ordered cascade modes. |
| `units` | Unit mode used for spacing, sizing, and radius aliases. |
| `extensions` | Typed assignments for consumer-defined families. |

Every selected mode must exist on every token of that kind. Invalid selections produce a consolidated diagnostic instead of changing policy per token. Consumer-defined families add typed selections to the same result; see [Theme extensions](theme-extensions.md#select-a-mode).

## Standard resolver

`DefaultThemeModeResolver` preserves the library conventions:

- colors: `light` and `dark`;
- fonts: `default`, with no cascade modes;
- units: `default`.

Use `.theme(.app)` for a generated bundled resource that follows those names, or `.theme(rawTheme)` for an already decoded value such as a server response.

The standard resolver does not vary fonts or units with layout direction or size class. Use a custom resolver for script-specific faces, cascade order, or responsive measurements.

## SwiftUI updates

`@ThemeReader` participates in SwiftUI's dynamic-property lifecycle. It reads the resolver, color scheme, layout direction, size class, and active theme from one environment snapshot during view evaluation. Changing one of those values invalidates the consuming view through SwiftUI's normal dependency tracking.

Keep `modes(for:)` cheap, deterministic, and free of side effects. `@ThemeReader` captures one resolver result during each DynamicProperty update and every token read in that body evaluation uses the same snapshot. SwiftUI may still evaluate a body more than once. Do not capture environment values inside the resolver; use the supplied context.

Stateless resolvers need no identity boilerplate. If a resolver stores policy state that can change its answer for the same context, expose that state through `cacheIdentity`:

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  let campaign: String

  var cacheIdentity: AnyHashable { campaign }

  func modes(for context: ThemeModeContext) -> ThemeModes {
    ThemeModes(
      colors: ThemeColorModeSelection(
        light: "\(campaign)-light",
        dark: "\(campaign)-dark"
      ),
      fonts: ThemeFontModeSelection(primary: "default"),
      units: "default"
    )
  }
}
```

Passing a resolver with a new identity invalidates its resolved token scope.

Resolution is main-actor-bound because it runs inside SwiftUI's environment update. Client resolvers need no `nonisolated`, `Sendable`, or actor annotations.

Dynamic Type remains outside the resolver because the font modifier rebuilds its scaled concrete font when `dynamicTypeSize` changes.

Resolved token caches use the decoded theme identity, composed override identity, resolver identity, and relevant environment context. Returned mode-name strings are not separate cache-key components. Concrete font caches include Dynamic Type size. All caches are bounded.

Next: [Using tokens](tokens.md)
