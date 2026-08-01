# Theme extensions

Every mode-resolved token family uses `ThemeExtension`. Gamma supplies `Theme.Colors`, `Theme.Fonts`, and `Theme.Units`; theme extensions add app-owned families to the same JSON, code-generation, resolution, and `ThemeProxy` workflow. Gamma owns the shared contract while the app defines each custom mode payload and rendering type.

## Define the JSON family

A custom top-level key holds a dictionary keyed directly by token alias. There is no intermediate `values` object. Every token requires `name`, `group`, and a non-empty `modes` dictionary; `description` is optional.

```json
"gradients": {
  "brand/hero": {
    "name": "Hero",
    "group": "brand",
    "description": "Primary brand gradient",
    "modes": {
      "day": { "stops": ["color/start", "color/end"] },
      "night": { "stops": ["color/end", "color/start"] }
    }
  }
}
```

Mode names and payloads belong to the app. A family may use appearance variants, responsive variants, one fixed `default`, or any other vocabulary its resolver understands.

## Generated API

For every non-empty custom family in a build input, Gamma generates a family marker plus one typed alias scope for each non-empty token group:

```swift
public extension Theme {
  nonisolated enum Gradients {
    nonisolated public static let key = "gradients"
  }
}

public extension Theme.Gradients {
  nonisolated enum BrandGroup: ThemeTokenGroup {
    public typealias Family = Theme.Gradients
    nonisolated public static let name = "brand"
  }

  typealias BrandAlias = Theme.Alias<BrandGroup>
}

public extension Theme.Alias where Scope == Theme.Gradients.BrandGroup {
  static var brandHero: Self {
    Self(rawValue: "brand/hero")
  }
}
```

Accessor and group names may repeat across families because each family owns its namespace. A `Brand` gradient group and a `Brand` color group therefore generate `Theme.Gradients.BrandAlias` and `Theme.Colors.BrandAlias` without colliding.

Tokens whose `group` is empty receive accessors on the family scope `Theme.Alias<Theme.Gradients>`. Gamma does not generate an `UngroupedAlias`, so components cannot treat the absence of a group as a semantic restriction.

The roots `id`, `defaults`, `colors`, `fonts`, `units`, `assets`, and `illustrations` are reserved. Empty custom dictionaries do not generate declarations. Multiple theme variants in one target must expose the same non-empty custom families and token keys.

## Define the payload

The generator cannot infer the Swift representation of a mode payload. Define it by conforming a token type to `ThemeExtensionToken`, then connect that type to the generated marker:

```swift
nonisolated public struct GradientToken: ThemeExtensionToken {
  nonisolated public struct Mode: Decodable {
    public let stops: [String]
  }

  public let name: String
  public let group: String
  public let modes: [String: Mode]
}

extension Theme.Gradients: ThemeExtension {
  public typealias Token = GradientToken
}
```

Generated markers are public, so a public conformance requires a public token type and `Token` witness. In a main-actor-by-default target, declare the token and mode types `nonisolated` so `Decodable` synthesis remains available.
Because the generated alias is constrained to `ThemeExtension`, adding a custom family also requires this conformance in the consumer target.

## Select a mode

`ResolvedThemeModes` is an empty typed collection. Populate every built-in and custom family your theme uses. Custom families select one arbitrary mode name by default; that name may come from any `ThemeModeContext` input or resolver state.

```swift
struct AppThemeModeResolver: ThemeModeResolving {
  func resolve(in context: ThemeModeContext) -> ResolvedThemeModes {
    var modes = ResolvedThemeModes()
    modes[Theme.Colors.self] = .init(light: "light", dark: "dark")
    modes[Theme.Fonts.self] = .init(primary: "default")
    modes[Theme.Units.self] = "default"
    modes[Theme.Gradients.self] = context.colorScheme == .dark
      ? "night"
      : "day"
    return modes
  }
}
```

The family type keeps unrelated selections distinct even when they use the same mode names. A family that does not care about appearance can instead use size class, layout direction, resolver state, or a fixed value such as `modes[Theme.Gradients.self] = "default"`.

## Register the family

Register each family alongside the resolver that selects its mode:

```swift
AppRoot()
  .theme(
    .app,
    modeResolver: AppThemeModeResolver(),
    extensions: [ThemeExtensionRegistration(Theme.Gradients.self)]
  )
```

The overloads that use `DefaultThemeModeResolver` do not accept registrations because the standard resolver has no custom family selections.

## Resolve the selected payload

`ThemeProxy.resolve(_:)` returns the family-specific `Token.Mode`. Keep the app-owned proxy method focused on conversion and fallback:

```swift
public extension ThemeProxy {
  func gradient(_ alias: Theme.Gradients.BrandAlias) -> LinearGradient {
    guard let mode = resolve(alias) else {
      return LinearGradient(
        colors: [.clear],
        startPoint: .top,
        endPoint: .bottom
      )
    }

    return LinearGradient(
      colors: mode.stops.map {
        color(Theme.Alias<Theme.Colors>(rawValue: $0))
      },
      startPoint: .top,
      endPoint: .bottom
    )
  }
}
```

Views now use the custom family like a built-in one:

```swift
@ThemeReader private var theme

var body: some View {
  Rectangle()
    .fill(theme.gradient(.brandHero))
}
```

## Validation and failures

Unregistered top-level keys remain opaque during runtime validation. A registration adds these installation checks:

- the root key exists and holds a keyed token dictionary;
- aliases and names are non-empty;
- grouped aliases are exactly `<group>/<name>`, with the first component matching `group`;
- every token contains string `name` and `group` fields plus a non-empty `modes` dictionary;
- the full dictionary decodes as the family's concrete token type;
- the resolver selects a non-empty mode for the family;
- every token contains that selected mode.

Failures join Gamma's consolidated warning and trigger a debug assertion. In release builds, `ThemeProxy.resolve(_:)` returns `nil` for a missing selection, token, mode, or invalid payload; the app-owned proxy method supplies the domain fallback.

## Runtime-only families

Generated aliases come only from build inputs. A server theme must preserve that compiled alias contract. If a runtime-only family is absent from every build input, declare its family marker, alias accessors, and `ThemeExtension` conformance manually—or include its alias contract in a bundled build-time theme.

Next: [Theme format](themes.md) · [Mode resolution](modes.md) · [Using tokens](tokens.md)
