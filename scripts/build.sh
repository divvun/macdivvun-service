#!/bin/sh
set -ex

rm -rf tmp || echo "no tmp dir; continuing"
rm -rf build || echo "no build dir; continuing"

export MACOS_DEVELOPMENT_TEAM="2K5J2584NX"
export MACOS_CODE_SIGN_IDENTITY="Developer ID Application: The University of Tromso (2K5J2584NX)"
export MACOS_CODE_SIGN_IDENTITY_INSTALLER="Developer ID Installer: The University of Tromso (2K5J2584NX)"

APP_NAME="MacDivvun.service"
PKG_NAME="MacDivvun.pkg"

pod update && pod install
xcodebuild -scheme MacDivvun -workspace MacDivvun.xcworkspace -configuration Release archive -clonedSourcePackagesDirPath tmp/src -derivedDataPath tmp/derived -archivePath build/app.xcarchive \
    CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$MACOS_DEVELOPMENT_TEAM" CODE_SIGN_IDENTITY="$MACOS_CODE_SIGN_IDENTITY" -allowProvisioningUpdates  \
    OTHER_CODE_SIGN_FLAGS=--options=runtime || exit 1

rm -rf "$APP_NAME"
mv "build/app.xcarchive/Products/Applications/$APP_NAME" .

echo "Notarizing bundle"
xcnotary notarize "$APP_NAME" --override-path-type app -d "$INPUT_MACOS_DEVELOPER_ACCOUNT" -p "$INPUT_MACOS_NOTARIZATION_APP_PWD"
stapler validate "$APP_NAME"

VERSION=`/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_NAME/Contents/Info.plist"`

pkgbuild --component MacDivvun.service \
    --ownership recommended \
    --install-location /Library/Services \
    --version $VERSION \
    no.divvun.MacDivvun.pkg

productbuild --distribution scripts/dist.xml \
    --version $VERSION \
    --package-path . \
    MacDivvun-unsigned.pkg

productsign --sign "$MACOS_CODE_SIGN_IDENTITY_INSTALLER" MacDivvun-unsigned.pkg "$PKG_NAME"
pkgutil --check-signature "$PKG_NAME"

echo "Notarizing installer"
xcrun notarytool submit -v --apple-id "$INPUT_MACOS_DEVELOPER_ACCOUNT" --password "$INPUT_MACOS_NOTARIZATION_APP_PWD" --team-id "$MACOS_DEVELOPMENT_TEAM" --wait "$PKG_NAME"
xcrun stapler staple "$PKG_NAME"
spctl --assess -vv --type install "$PKG_NAME"
stapler validate "$PKG_NAME"
