# MacDivvun.service

A macOS speller service for zhfst spellers built using the
[Giella infrastructure](http://divvun.no/doc/infra/GettingStarted.html).

[![Build Status](https://dev.azure.com/divvun/divvun-service/_apis/build/status/divvun.macdivvun-service?branchName=master)](https://dev.azure.com/divvun/divvun-service/_build/latest?definitionId=4&branchName=master)

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
