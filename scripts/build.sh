#!/bin/sh
set -ex

echo "::add-mask::$MACOS_NOTARIZATION_APP_PWD"
rm -rf tmp || echo "no tmp dir; continuing"
rm -rf build || echo "no build dir; continuing"

export MACOS_DEVELOPMENT_TEAM="2K5J2584NX"
export MACOS_CODE_SIGN_IDENTITY="Developer ID Application: The University of Tromso (2K5J2584NX)"
export MACOS_CODE_SIGN_IDENTITY_INSTALLER="Developer ID Installer: The University of Tromso (2K5J2584NX)"

APP_NAME="MacDivvun.service"
PKG_NAME="MacDivvun.pkg"

xcodebuild -scheme MacDivvun -configuration Release archive -clonedSourcePackagesDirPath tmp/src -derivedDataPath tmp/derived -archivePath build/app.xcarchive \
    CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$MACOS_DEVELOPMENT_TEAM" CODE_SIGN_IDENTITY="$MACOS_CODE_SIGN_IDENTITY" -allowProvisioningUpdates  \
    OTHER_CODE_SIGN_FLAGS=--options=runtime || exit 1

rm -rf "$APP_NAME"
mv "build/app.xcarchive/Products/Applications/$APP_NAME" .

echo "Notarizing bundle"
xcnotary notarize "$APP_NAME" --override-path-type app -d "$MACOS_DEVELOPER_ACCOUNT" -p "$MACOS_NOTARIZATION_APP_PWD"
stapler validate "$APP_NAME"

VERSION=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_NAME/Contents/Info.plist"`

pkgbuild --component MacDivvun.service \
    --ownership recommended \
    --install-location /Library/Services \
    --version $version \
    no.divvun.MacDivvun.pkg

productbuild --distribution scripts/dist.xml \
    --version $version \
    --package-path . \
    MacDivvun-unsigned.pkg

productsign --sign "$MACOS_CODE_SIGN_IDENTITY_INSTALLER" MacDivvun-unsigned.pkg "$PKG_NAME"
pkgutil --check-signature "$PKG_NAME"

echo "Notarizing installer"
xcnotary notarize "$PKG_NAME" --override-path-type pkg -d "$MACOS_DEVELOPER_ACCOUNT" -p "$MACOS_NOTARIZATION_APP_PWD"
stapler validate "$PKG_NAME"
