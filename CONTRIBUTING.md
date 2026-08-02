# Contributing to Portlight

Thanks for helping make the technical parts of macOS easier to understand.

## Development

Portlight requires macOS 14 or newer and Xcode 16 or newer.

```sh
swift build
swift run Portlight
```

To create a local app bundle:

```sh
./scripts/build-app.sh
open dist/Portlight.app
```

## Pull requests

- Keep Portlight read-only unless a proposal clearly explains the safety model.
- Never display private key contents, secrets, tokens, or unredacted environment values.
- Prefer plain-English explanations over unexplained system terminology.
- Use native macOS controls, keyboard navigation, and accessibility labels.
- Run `swift build` before opening a pull request.
