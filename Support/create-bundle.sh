#!/bin/sh

if [ ! $7 ]; then
  echo "Usage: <appcast-url> <bundle-id> <bundle-language> <version> <build> <org-name> <zhfst-file>"
  echo ""
  echo "A bundle called '<bundle-language>.bundle' will be created in the current directory."
  echo "Example: create-bundle.sh 'https://domain.com/appcast.xml' 'com.example.bundle' 'en' '1.0.0' '1' 'Divvun' 'en.zhfst'"
  echo ""
  exit 0
fi

bundle_name="$3.bundle"
plist="$bundle_name/Contents/Info.plist"

plist_add() {
  /usr/libexec/PlistBuddy -c "add $1 $2 $3" $plist
}

mkdir -p "$bundle_name/Contents/Resources/3"
cp "$7" "$bundle_name/Contents/Resources/3"

/usr/libexec/PlistBuddy -c "Save" $plist >/dev/null

plist_add ':CFBundleDevelopmentRegion' 'string' 'en'
plist_add ':SUEnableAutomaticChecks' 'bool' 'YES'
plist_add ':SUFeedURL' 'string' "$1"
plist_add ':CFBundleIdentifier' 'string' "$2"
plist_add ':CFBundleName' 'string' "$3"
plist_add ':CFBundlePackageType' 'string' 'BNDL'
plist_add ':CFBundleSupportedPlatforms' 'array'
plist_add ':CFBundleSupportedPlatforms:' 'string' 'MacOSX'
plist_add ':CFBundleShortVersionString' 'string' "$4"
plist_add ':CFBundleVersion' 'string' "$5"
plist_add ':NSHumanReadableCopyright' 'string' "Copyright © $6"

plist_add ':NSServices' 'array'
plist_add ':NSServices:' 'dict'
plist_add ':NSServices:0:NSExecutable' 'string' 'MacVoikko'
plist_add ':NSServices:0:NSLanguages' 'array'
plist_add ':NSServices:0:NSLanguages:' 'string' "$3"
plist_add ':NSServices:0:NSMenuItem' 'dict'
plist_add ':NSServices:0:NSPortName' 'string' 'MacVoikko'
plist_add ':NSServices:0:NSSpellChecker' 'string' 'MacVoikko'

