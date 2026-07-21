# Code generation

Gamma generates Swift aliases from `*.theme.json` files and `.xcassets` catalogues. The generator is a Swift library shared by the build plugin, command plugin, and executable; every entry point produces the same deterministic source.

## Build plugin

Use `GammaBuildPlugin` when generated files should remain build artifacts.

For a Swift package target:

```swift
.target(
  name: "MyFeature",
  dependencies: [
    .product(name: "Gamma", package: "Gamma"),
  ],
  resources: [
    .process("App.theme.json"),
    .process("Assets.xcassets"),
  ],
  plugins: [
    .plugin(name: "GammaBuildPlugin", package: "Gamma"),
  ]
)
```

For an Xcode target, add `GammaBuildPlugin` under **Build Phases → Run Build Tool Plug-ins**.

The plugin recursively discovers files ending exactly in `.theme.json` and directories with an `.xcassets` extension in that target, including inputs inside nested folders. Resource declarations remain necessary for SwiftPM to bundle those inputs at runtime. The plugin writes Swift into its work directory and passes those files directly to the compiler. Generated files do not appear in the project navigator and should not be committed.

If the plug-in does not discover a `*.theme.json` input, it fails the build with the likely filename and target-membership fixes, even when it finds an asset catalogue. A recognized but malformed theme reaches the generator and fails the build with schema diagnostics.

All `*.theme.json` files in one target are treated as variants of one theme family. Their existing JSON format does not change. The plugin generates one token file and checks that every variant defines the same alias contract, failing with both paths when keys or unit groups drift.

## Command plugin

Use `GammaGeneratePlugin` when generated files should live in the source tree.

In Xcode, right-click the package and choose **Generate Gamma Aliases**. From SwiftPM:

```sh
swift package \
  --allow-writing-to-package-directory \
  generate-gamma
```

With no arguments, the command discovers supported inputs target by target. For each target it writes one file per generated template under `Generated/Gamma` beside the first discovered input. A single input keeps an input-derived filename, while aggregated inputs use `Gamma+Tokens.generated.swift` or `Gamma+Assets.generated.swift`.

Pass executable options after the command for explicit generation:

```sh
swift package \
  --allow-writing-to-package-directory \
  generate-gamma \
  --input Sources/MyFeature/App.theme.json \
  --output Sources/MyFeature/Generated \
  --template tokens
```

Do not attach the build plugin and compile checked-in command-plugin output for the same input. Both files declare the same aliases.

## Executable

Use the executable from another build system or while debugging generation:

```sh
swift run gamma-codegen \
  --input path/to/App.theme.json \
  --output path/to/Generated \
  --template tokens
```

| Option | Meaning |
| --- | --- |
| `--input`, `-i` | A theme JSON file or `.xcassets` catalogue. Repeat for a theme family or mixed inputs. |
| `--output`, `-o` | Output directory with an inferred filename. |
| `--output-file` | Exact output path; requires one template. |
| `--template`, `-t` | `tokens`, `assets`, `both`, or a comma-separated list. |

`tokens` is the default. For `.xcassets`, choose `assets`. Passing `both` for catalogue-only input generates assets and warns that token generation was skipped because tokens require JSON. With mixed theme and catalogue inputs, `both` uses the JSON files for tokens and all compatible inputs for assets.

## Generated declarations

| Input | Declaration |
| --- | --- |
| File `Brand Default.theme.json` | `ThemeResource.brandDefault` |
| Color key `color/text-primary` | `Theme.ColorAlias.colorTextPrimary` |
| Font key `font/body` | `Theme.FontAlias.fontBody` |
| Unit group `Spacing` | `Theme.SpacingAlias` |
| Unit key `space/medium` | `UnitAlias.spaceMedium` constrained to `Theme.SpacingAlias` |
| Image set `close.imageset` | Icon asset alias `.close` |

Names are normalized into Swift identifiers, leading digits receive an underscore, reserved words are escaped, and raw values are emitted as escaped Swift string literals.

Normalization keeps ASCII letters and digits and treats other characters as separators. For example, `1x/foo` becomes `_1xFoo` and `icon@2x` becomes `icon2x`. A name with no ASCII identifier content fails generation.

Generation fails when distinct source names normalize to the same declaration—for example, `foo-bar` and `foo_bar`. Fix the source names rather than accepting an arbitrary winner.

Pass `--input` more than once to validate and generate a theme family explicitly:

```sh
swift run gamma-codegen \
  --input BrandDefault.theme.json \
  --input BrandHighContrast.theme.json \
  --output Generated \
  --template tokens
```

## Asset catalogue rules

- Image sets are discovered recursively.
- Any path component beginning with `!` excludes that subtree.
- A folder named `Illustration` or `Illustrations`, case-insensitively, selects illustration aliases.
- Catalogue folders are otherwise flattened: aliases use the `.imageset` basename, not an Xcode namespace.
- Duplicate basenames emit one warning listing every path. The last path in deterministic catalogue order is retained for compatibility.

## Troubleshooting Xcode

If aliases are unavailable, verify these in order:

1. The theme filename ends in `.theme.json` and belongs to the consuming target.
2. The JSON is also a target resource; generation does not by itself copy the file into the runtime bundle.
3. `GammaBuildPlugin` is attached to that target—not only added as a package product—and Xcode has permission to run it.
4. The build log contains both `Apply build tool plug-in “GammaBuildPlugin”` and `Generated Gamma+Tokens.generated.swift`.
5. If several themes are present, read the generator's contract-drift error before looking for missing Swift members.
6. After changing package-plugin sources while Xcode is open, use **Product → Clean Build Folder** and reopen the project if Xcode kept an old package build plan.

The absence of generated files from the navigator is expected. The absence of the apply or generated lines from the build log is not.

Next: [Diagnostics](diagnostics.md)
