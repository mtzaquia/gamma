# Overrides

Use `WithThemeOverrides` to replace selected token modes inside one view subtree. The installed base theme and resolver stay the same outside that scope. For a theme whose resolver selects `day` and `night` colors:

```swift
let campaignOverrides = RawThemeOverrides(
  tokens: [
    try ThemeTokenOverride(
      Theme.Colors.BrandAlias.brandAccent,
      modes: [
        "day": RawColor.Mode(hex: "#B42318", alpha: 1),
        "night": RawColor.Mode(hex: "#FDA29B", alpha: 1),
      ]
    )
  ]
)

WithThemeOverrides(overrides: campaignOverrides) {
  CampaignView()
}
```

Every view below `WithThemeOverrides` resolves `brand/accent` from the replacement modes. Siblings and ancestors continue to use the base theme.

## Override fonts and units

`ThemeTokenOverride` infers the mode payload from the alias family. A color alias only accepts `RawColor.Mode`, a font alias accepts `RawFont.Mode`, and a unit alias accepts numeric unit modes. This keeps handwritten keys type-safe while preserving the backend's string-keyed JSON format.

The same scope can replace colors, fonts, units, and registered extension families together. `RawFont.Mode` is designed to be decoded with the rest of an override payload.

```json
{
  "colors": {},
  "fonts": {
    "typography/display": {
      "latin": {
        "fontSize": 34,
        "fontName": "CampaignDisplay-Regular",
        "lineHeight": 42,
        "letterSpacing": -1,
        "textCase": "ORIGINAL"
      },
      "arabic": {
        "fontSize": 34,
        "fontName": "CampaignArabicDisplay-Regular",
        "lineHeight": 44,
        "letterSpacing": 0,
        "textCase": "ORIGINAL"
      }
    }
  },
  "units": {
    "radius/card": {
      "compact": 8,
      "regular": 12
    }
  }
}
```

```swift
let overrides = try JSONDecoder().decode(
  RawThemeOverrides.self,
  from: overrideData
)

WithThemeOverrides(overrides: overrides) {
  CampaignView()
}
```

Decoded override documents may include any built-in or registered extension family. Omitted families have no replacements.

## Override an extension token

Custom mode payloads remain app-owned. When the mode is `Encodable`, the same typed entry API checks both its alias and replacement value:

```swift
let gradientOverrides = RawThemeOverrides(
  tokens: [
    try ThemeTokenOverride(
      Theme.Gradients.BrandAlias.brandHero,
      modes: [
        "day": GradientToken.Mode(
          stops: ["surface/background", "brand/accent"]
        ),
        "night": GradientToken.Mode(
          stops: ["brand/accent", "surface/background"]
        )
      ]
    )
  ]
)

WithThemeOverrides(overrides: gradientOverrides) {
  HeroBanner()
}
```

The equivalent backend payload keeps the generated token keys as strings:

```json
{
  "gradients": {
    "brand/hero": {
      "day": { "stops": ["surface/background", "brand/accent"] },
      "night": { "stops": ["brand/accent", "surface/background"] }
    }
  }
}
```

Gamma replaces the `modes` object on the existing extension token, then validates it through the registered extension's concrete `Token` type and selected mode.

Overrides carry token values only. If an overridden font mode names a custom face, make that file available through the root `.theme(..., fontURLs:)` call or register it in the app before presenting the override. `WithThemeOverrides` does not download or register fonts.

## Replacement semantics

An override replaces the complete mode dictionary for one token; it does not merge individual modes into the base token. Include every mode that the active resolver may select.

This makes an override self-contained and prevents an old base value from unexpectedly filling part of a remotely supplied treatment.

Overrides must reference families and tokens that already exist in the base theme. They cannot introduce new aliases because generated source and component code would not know those aliases.

Replacing a `RawThemeOverrides` value with newly decoded server data updates the transformed environment immediately. The app remains responsible for fetching that data and publishing the replacement value.

## Validation and caching

Gamma validates the transformed theme against the active resolver. Missing tokens or selected modes produce one consolidated diagnostic for that override state.

Override identity composes through nested scopes and participates in built-in and extension token caches, so values from the base theme, a parent override, or another server response are not reused accidentally.

Next: [Diagnostics](diagnostics.md)
