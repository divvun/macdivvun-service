# MacDivvun.service

A macOS speller service for zhfst spellers built using the
[Giella infrastructure](http://divvun.no/doc/infra/GettingStarted.html).

[![Build Status](https://github.com/divvun/macdivvun-service/workflows/CI/badge.svg)](https://github.com/divvun/macdivvun-service/actions)

## Requirements

- Xcode
- CocoaPods
- [Rust](https://rustup.rs)

## Building

Run the following commands:

```bash
pod install
git submodule update --init
sh ./scripts/build.sh
```

## Installing

Pop into `~/Library/Services`.
