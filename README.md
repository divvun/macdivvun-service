# MacDivvun.service

macOS background `NSApplication` that hosts an `NSSpellServer` for spell- *and* grammar-checking bundles produced by [divvun-runtime](https://github.com/divvun/divvun-runtime). Installs to `/Library/Services` and registers per-locale checkers discovered from `<locale>.bundle/Contents/Resources/<locale>.drb` directories alongside it. Ships with a SwiftUI companion app (`MacDivvunPreferences.app`) for per-locale ignored-grammar-rule toggles and as the feedback host. When Accessibility access is granted, the service shows a small floating "Report" button next to flagged words in any app that exposes its text via AX (most native Cocoa apps + MS Office).

## Requirements

- macOS 12.0+
- Xcode 26
- `xcodegen` (`brew install xcodegen`)
- A built `libdivvun_runtime.a` at `Vendor/libdivvun_runtime.a` (symlink to `divvun-runtime/target/release/libdivvun_runtime.a` during development)
- The matching C header at `Vendor/divvun_runtime.h` (symlink to `divvun-runtime/bindings/c/divvun_runtime.h`)

## Build

```sh
sh ./scripts/build.sh
```

Produces an unsigned `./MacDivvun.service`. Signing, notarization, and packaging are handled by the downstream installer pipeline.

## Develop in Xcode

```sh
Vendor/pkgconfig/generate.sh
xcodegen generate
open MacDivvun.xcodeproj
```

`MacDivvun.xcodeproj` is generated from `project.yml` and not committed.

## Layout

```
Sources/             Swift sources + Info.plist + Assets
Vendor/              libdivvun_runtime.a, divvun_runtime.h, pkgconfig/
scripts/build.sh     Build entry point
project.yml          xcodegen manifest
```
