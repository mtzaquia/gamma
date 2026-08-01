# Using tokens

Read the active theme and resolve aliases with `@ThemeReader`.

```swift
struct Card: View {
  @ThemeReader private var theme

  var body: some View {
    VStack(alignment: .leading) {
      DSText("Card title")
        .font(theme.font(.typographyBody))
    }
      .padding(theme.unit(.spacingMedium))
      .background(theme.color(.surfaceSurface))
      .clipShape(
        RoundedRectangle(cornerRadius: theme.unit(.radiusCard))
      )
  }
}
```

Generated aliases are typed by both their value family and semantic group. They keep raw theme keys out of view code while letting a component distinguish, for example, spacing from radius even though both resolve to `CGFloat`.

Consumer-defined families can use the same alias-to-value pattern through a small app-owned proxy extension. See [Theme extensions](theme-extensions.md).

## Restrict component token parameters

Every non-empty group generates an alias nested under its family. A component can require those generated types while Gamma's resolver remains generic across all groups in the family:

```swift
struct TokenCard<Content: View>: View {
  @ThemeReader private var theme

  let background: Theme.Colors.SurfaceAlias
  let foreground: Theme.Colors.TextAlias
  let font: Theme.Fonts.TypographyAlias
  let padding: Theme.Units.SpacingAlias
  let cornerRadius: Theme.Units.RadiusAlias
  @ViewBuilder let content: Content

  init(
    background: Theme.Colors.SurfaceAlias,
    foreground: Theme.Colors.TextAlias,
    font: Theme.Fonts.TypographyAlias,
    padding: Theme.Units.SpacingAlias,
    cornerRadius: Theme.Units.RadiusAlias,
    @ViewBuilder content: () -> Content
  ) {
    self.background = background
    self.foreground = foreground
    self.font = font
    self.padding = padding
    self.cornerRadius = cornerRadius
    self.content = content()
  }

  var body: some View {
    content
      .font(theme.font(font))
      .foregroundStyle(theme.color(foreground))
      .padding(theme.unit(padding))
      .background(theme.color(background))
      .clipShape(
        RoundedRectangle(cornerRadius: theme.unit(cornerRadius))
      )
  }
}
```

Consumer code passes ordinary generated members:

```swift
TokenCard(
  background: .surfaceSurface,
  foreground: .textPrimary,
  font: .typographyBody,
  padding: .spacingMedium,
  cornerRadius: .radiusCard
) {
  Text("Account")
}
```

Both `.spacingMedium` and `.radiusCard` resolve through `theme.unit(...)`, but exchanging them in this initializer is a compile-time error. The group restricts the component contract; the owning family selects the resolver and output type. Keeping the group in the accessor also disambiguates direct calls when, for example, both `spacing/medium` and `size/medium` exist.

An empty `group` produces no artificial group type. Its accessors use the family scope. For example, a font token keyed by `body` with `group: ""` generates `.body` on `Theme.Alias<Theme.Fonts>`:

```swift
let body: Theme.Alias<Theme.Fonts> = .body
```

Aliases are also `Codable` and decode from a plain token-key string:

```swift
let alias = try JSONDecoder().decode(
  Theme.Alias<Theme.Colors>.self,
  from: Data(#""legacy""#.utf8)
)
```

The complete string is the token key. Grouped aliases decode from ordinary strings such as `"text/primary"`; `tokenGroup` and `tokenName` expose the two components. The schema requires that the first component exactly match the token's `group` field. An empty group uses a slash-free key such as `"legacy"` and remains on the family scope rather than receiving an artificial `UngroupedAlias`.

## Colors

`theme.color(...)` returns a SwiftUI `Color` backed by a dynamic `UIColor`. The same value follows light and dark appearance using the resolver's selected pair.

```swift
Text("Account")
  .foregroundStyle(theme.color(.textPrimary))
```

## Typography

`theme.font(...)` returns a `ThemeFont`. Apply it with Gamma's `View.font(_:)` overload:

```swift
DSText("Readable at every size")
  .font(theme.font(.typographyBody))
```

The modifier applies:

- a Dynamic Type-scaled font;
- the resolver's primary and cascade faces;
- line spacing and a scaled line-height value for `DSText`;
- percentage-based letter spacing;
- the token's text case.

Use `DSText` when single-line text should occupy at least the token's scaled line height. It accepts the common SwiftUI `Text` inputs and reads that value from the environment. The font modifier applies line spacing to multiline content; `DSText` does not replace SwiftUI's text-layout engine with an exact line-height renderer.

`ThemeFont` also exposes values for UIKit and attributed text. Read the current Dynamic Type size from the environment and pass it explicitly:

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

private var bodyUIFont: UIFont {
  theme.font(.typographyBody).uiFont(for: dynamicTypeSize)
}

private var bodyAttributes: AttributeContainer {
  theme.font(.typographyBody).attributes(for: dynamicTypeSize)
}
```

## Register custom fonts

Pass local font-file URLs when installing the theme. Gamma reads their PostScript names and registers each face before rendering the themed subtree.

```swift
AppRoot()
  .theme(
    .app,
    modeResolver: AppThemeModeResolver(),
    fontURLs: AppFonts.urls
  )
```

`AppFonts.urls` is simply an application-owned collection of bundled or downloaded local file URLs. It is not a Gamma manifest and does not need to duplicate names from the JSON.

The JSON `fontName` is already the contract: it must be the face's PostScript name, not necessarily its filename. No separate font manifest is required.

Registration is idempotent for the lifetime of the process. Repeated SwiftUI body evaluations do not reread the same successful URL, the same PostScript name supplied from different cache URLs is registered only once, and a font already registered by the app or another framework is treated as available.

Supplied files are first validated independently, so system fonts and faces registered elsewhere do not need entries in `fontURLs`. After registration, Gamma checks every resolver-selected primary and cascade `fontName` through UIKit. An unavailable PostScript name joins the consolidated theme diagnostic and triggers a debug assertion. Enable trace diagnostics while integrating custom faces to compare discovered PostScript names with the JSON.

### Server-provided themes and fonts

The host app owns transport and storage. Download or retrieve the JSON and font files using the networking and cache policy appropriate for the app, decode the theme, and publish the theme and completed local URLs together:

```swift
struct ActiveTheme {
  let value: RawTheme
  let fontURLs: [URL]
}

@MainActor
final class AppThemeStore: ObservableObject {
  @Published private(set) var active: ActiveTheme

  // Inject these using the app's normal dependency system.
  let themeService: ThemeService
  let fontStore: FontStore

  init(
    active: ActiveTheme,
    themeService: ThemeService,
    fontStore: FontStore
  ) {
    self.active = active
    self.themeService = themeService
    self.fontStore = fontStore
  }

  func refresh() async throws {
    let response = try await themeService.fetchTheme()
    let theme = try JSONDecoder().decode(
      RawTheme.self,
      from: response.themeData
    )
    let fontURLs = try await fontStore.localURLs(for: response.fontFiles)

    // One publication prevents the new theme rendering before its files exist.
    active = ActiveTheme(value: theme, fontURLs: fontURLs)
  }
}

struct AppRoot: View {
  @ObservedObject var themes: AppThemeStore

  var body: some View {
    RootContent()
      .theme(
        themes.active.value,
        modeResolver: AppThemeModeResolver(),
        fontURLs: themes.active.fontURLs
      )
  }
}
```

Gamma owns schema validation, local font registration, and SwiftUI activation. It deliberately does not download fonts, prescribe a cache, or manage loading and failure UI.

Treat downloaded font files as immutable after passing their URLs to `.theme(...)`. Core Text cannot reliably replace a registered face with another binary using the same PostScript name during one process. A genuinely new face should use a new PostScript name; otherwise activate the update after the next app launch.

The generated aliases still come from build inputs. A server theme must preserve that compiled alias contract. Schema problems fail decoding, selected-mode problems assert during installation in debug builds, and a missing compiled alias is diagnosed when a view reads it.

## Units

`theme.unit(...)` resolves an alias from any group owned by `Theme.Units` to a `CGFloat` using the selected unit mode.

```swift
VStack(spacing: theme.unit(.spacingSmall)) {
  content
}
.padding(theme.unit(.spacingLarge))
```

Unit groups are separate alias scopes. `spacing` and `radius`, for example, generate `Theme.Units.SpacingAlias` and `Theme.Units.RadiusAlias`. Their full-key members, such as `.spacingSmall` and `.radiusCard`, remain unambiguous even when passed directly to the family-wide `theme.unit(...)` resolver.

## Assets

Asset generation creates typed aliases for `.imageset` entries. Regular image sets become `Theme.AssetAlias<IconAsset>`; image sets below a folder named `Illustration` or `Illustrations` become `Theme.AssetAlias<IllustrationAsset>`.

An alias carries the catalogue name and an optional bundle:

```swift
let icon: Theme.IconAlias = .close
let image = Image(icon.rawValue, bundle: icon.bundle)
```

Asset aliases name resources; Gamma does not impose an image-loading abstraction.

Aliases generated into an Xcode app target default to the main bundle. In a Swift package target, pass that target's resource bundle explicitly because generated aliases cannot expose its internal `Bundle.module` outside the module:

```swift
let icon: Theme.IconAlias = .close
let image = Image(icon.rawValue, bundle: .module)
```

## Theme defaults

`.theme(...)` applies the theme's default font and primary foreground color to its entire subtree. When `secondaryTextColor` is present, it also installs the secondary level of a hierarchical foreground style.

Resolve explicit aliases where a component needs to depart from those defaults.

Next: [Code generation](code-generation.md) · [Overrides](overrides.md)
