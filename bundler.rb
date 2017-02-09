#!/usr/bin/env ruby

ARGV.each { |zhfst_file|
  zhfst_file = ARGV.shift
  zhfst_basename = File.basename(zhfst_file, ".zhfst")
  if !(zhfst_file.end_with? ".zhfst") then
    puts "Unsupported file extension"
    exit 1
  end
  bundle_name = "#{zhfst_basename}.bundle"
  bundle_file = "./Bundles/#{bundle_name}"
  @plist = "#{bundle_file}/Contents/Info.plist"

  if File.exist? bundle_file then
    puts "#{bundle_name} exists, skipping"
    exit 0
  end

  def plist_add(path, type, value = "")
    `/usr/libexec/PlistBuddy -c "add #{path} #{type} #{value}" #{@plist}`
  end

  puts "Creating #{bundle_name}"
  `mkdir -p #{bundle_file}/Contents/Resources`
  `cp #{zhfst_file} #{bundle_file}/Contents/Resources`
  plist_add ':CFBundleDevelopmentRegion', 'string', 'en'
  plist_add ':SUEnableAutomaticChecks', 'bool', 'YES'
  plist_add ':SUFeedURL', 'string', "https://divvun.no/bundles/#{zhfst_basename}/appcast.xml"
  plist_add ':CFBundleIdentifier', 'string', "no.divvun.MacVoikko.#{zhfst_basename}"
  plist_add ':CFBundleName', 'string', zhfst_basename
  plist_add ':CFBundlePackageType', 'string', 'BNDL'
  plist_add ':CFBundleSupportedPlatforms', 'array'
  plist_add ':CFBundleSupportedPlatforms:', 'string', 'MacOSX'
  plist_add ':CFBundleShortVersionString', 'string', '1.0'
  plist_add ':CFBundleVersion', 'string', '1'
  plist_add ':NSHumanReadableCopyright', 'string', "'Copyright © 2017 Divvun. All rights reserved.'"

  plist_add ':NSServices', 'array'
  plist_add ':NSServices:', 'dict'
  plist_add ':NSServices:0:NSExecutable', 'string', 'MacVoikko'
  plist_add ':NSServices:0:NSLanguages', 'array'
  plist_add ':NSServices:0:NSLanguages:', 'string', zhfst_basename
  plist_add ':NSServices:0:NSMenuItem', 'dict'
  plist_add ':NSServices:0:NSPortName', 'string', 'MacVoikko'
  plist_add ':NSServices:0:NSSpellChecker', 'string', 'MacVoikko'
}
