#!/bin/sh
set -ex

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -f Vendor/libdivvun_runtime.a ]; then
    echo "Vendor/libdivvun_runtime.a missing — build divvun-runtime first." >&2
    exit 1
fi

Vendor/pkgconfig/generate.sh
export PKG_CONFIG_PATH="$ROOT/Vendor/pkgconfig:${PKG_CONFIG_PATH:-}"

rm -rf build "MacDivvun.service" "MacDivvunPreferences.app"
xcodegen generate

for scheme in MacDivvun MacDivvunPreferences; do
    xcodebuild \
        -project MacDivvun.xcodeproj \
        -scheme "$scheme" \
        -configuration Release \
        -derivedDataPath build/derived \
        -clonedSourcePackagesDirPath build/spm \
        CODE_SIGNING_ALLOWED=NO \
        build
done

cp -R "build/derived/Build/Products/Release/MacDivvun.service" "MacDivvun.service"
cp -R "build/derived/Build/Products/Release/MacDivvunPreferences.app" "MacDivvunPreferences.app"

echo "Built: MacDivvun.service, MacDivvunPreferences.app"
