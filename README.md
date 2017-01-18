# MacVoikko

## Requirements

- Xcode
- autotools
- autopoint
- cmake

## Building

Run the following commands:

```bash
git submodule update --init
brew install automake libtool autoconf gettext pkg-config cmake python3
brew link --force gettext
```

Then, open Xcode and build. Easy.
