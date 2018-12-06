version=`/usr/libexec/PlistBuddy Sources/Info.plist -c "Print :CFBundleVersion"`

xcodebuild -scheme MacDivvun -configuration Release -workspace MacDivvun.xcworkspace archive -archivePath build/macdivvun.xcarchive DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY"

mv build/MacDivvun.xcarchive/Products/Applications/MacDivvun.service .

pkgbuild --component MacDivvun.service \
    --ownership recommended \
    --install-location /Library/Services \
    --version $version \
    no.divvun.MacDivvun.pkg

productbuild --distribution scripts/dist.xml \
    --version $version \
    --package-path . \
    MacDivvun-unsigned.pkg

productsign --sign "Developer ID Installer: The University of Tromso (2K5J2584NX)" MacDivvun-unsigned.pkg MacDivvun-$version.pkg
pkgutil --check-signature MacDivvun-$version.pkg
