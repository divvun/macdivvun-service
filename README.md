# MacDivvun.service

A macOS speller service for zhfst spellers built using the
[Giella infrastructure](http://divvun.no/doc/infra/GettingStarted.html).

[![Build Status](https://travis-ci.org/divvun/macdivvun-service.svg?branch=master)](https://travis-ci.org/divvun/macdivvun-service)

## Requirements

- Xcode
- autoconf
- automake
- CocoaPods
- cmake
- gettext
- libtool
- pkg-config
- python3

## Building

Run the following commands:

```bash
pod install
git submodule update --init
```

Then, open `MacDivvun.xcworkspace` and build. Easy.

## Installing

Pop into `~/Library/Services`.
