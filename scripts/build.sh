set -e
version=`/usr/libexec/PlistBuddy Sources/Info.plist -c "Print :CFBundleShortVersionString"`

security default-keychain -s build.keychain
security unlock-keychain -p travis build.keychain
security set-keychain-settings -t 3600 -u build.keychain

export DEVELOPMENT_TEAM="2K5J2584NX"
export CODE_SIGN_IDENTITY="Developer ID Application: The University of Tromso (2K5J2584NX)"
export CODE_SIGN_IDENTITY_INSTALLER="Developer ID Installer: The University of Tromso (2K5J2584NX)"

xcodebuild -scheme MacDivvun -configuration Release -workspace MacDivvun.xcworkspace archive -archivePath build/macdivvun.xcarchive \
    DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" -quiet \
    OTHER_CODE_SIGN_FLAGS=--options=runtime || exit 1

rm -rf MacDivvun.service || true

mv build/MacDivvun.xcarchive/Products/Applications/MacDivvun.service .

echo "Notarizing bundle"
xcnotary notarize MacDivvun.service --override-path-type app -d "$DEVELOPER_ACCOUNT" -k "$DEVELOPER_PASSWORD_CHAIN_ITEM"  2> /dev/null
stapler validate MacDivvun.service

pkgbuild --component MacDivvun.service \
    --ownership recommended \
    --install-location /Library/Services \
    --version $version \
    no.divvun.MacDivvun.pkg

productbuild --distribution scripts/dist.xml \
    --version $version \
    --package-path . \
    MacDivvun-unsigned.pkg

productsign --sign "$CODE_SIGN_IDENTITY_INSTALLER" MacDivvun-unsigned.pkg MacDivvun-$version.pkg
pkgutil --check-signature MacDivvun-$version.pkg
mv MacDivvun-$version.pkg MacDivvun.pkg

echo "Notarizing installer"
xcnotary notarize MacDivvun.pkg --override-path-type pkg -d "$DEVELOPER_ACCOUNT" -k "$DEVELOPER_PASSWORD_CHAIN_ITEM" 2> /dev/null
stapler validate MacDivvun.pkg
