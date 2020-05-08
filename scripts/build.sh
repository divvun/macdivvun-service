set -e
version=`/usr/libexec/PlistBuddy Sources/Info.plist -c "Print :CFBundleShortVersionString"`

security default-keychain -s build.keychain
security unlock-keychain -p travis build.keychain
security set-keychain-settings -t 3600 -u build.keychain

xcodebuild -scheme MacDivvun -configuration Release -workspace MacDivvun.xcworkspace archive -archivePath build/macdivvun.xcarchive \
    DEVELOPMENT_TEAM=$MACOS_DEVELOPMENT_TEAM CODE_SIGN_IDENTITY="$MACOS_CODE_SIGN_IDENTITY" -quiet \
    OTHER_CODE_SIGN_FLAGS=--options=runtime || exit 1

rm -rf MacDivvun.service || true

mv build/MacDivvun.xcarchive/Products/Applications/MacDivvun.service .

echo "Notarizing bundle"
xcnotary notarize MacDivvun.service --override-path-type app -d "$MACOS_DEVELOPER_ACCOUNT" -k "$MACOS_DEVELOPER_PASSWORD_CHAIN_ITEM"  2>&1
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

productsign --sign "$MACOS_CODE_SIGN_IDENTITY_INSTALLER" MacDivvun-unsigned.pkg MacDivvun-$version.pkg
pkgutil --check-signature MacDivvun-$version.pkg
mv MacDivvun-$version.pkg MacDivvun.pkg

echo "Notarizing installer"
xcnotary notarize MacDivvun.pkg --override-path-type pkg -d "$MACOS_DEVELOPER_ACCOUNT" -k "$MACOS_DEVELOPER_PASSWORD_CHAIN_ITEM" 2>&1
stapler validate MacDivvun.pkg
