# Contributing

Bug reports, fixes, and ideas are welcome. For anything large, open an issue first.

## Development setup

```bash
git clone https://github.com/Muddyblack/nixdatifier.git
cd nixdatifier
nix develop        # toolchain and git hooks
make help          # all targets
```

Without Nix you need:

| Dependency | Purpose |
|---|---|
| `nix` with flakes | Development shell (`nix develop`) and package builds |
| `qt6.qtdeclarative` | `qmllint`, `qmlformat`, `qmltestrunner` |
| `kdePackages.plasma-sdk` / `kpackage` | `plasmoidviewer`, `kpackagetool6` |
| `pre-commit` | QML lint and format hooks |
| `zip` | `.plasmoid` archive |

## Try your changes

```bash
make view          # preview the Plasma widget
qs -p .            # Quickshell panel
nix run .#         # standalone app
make test          # QML and helper tests
```

`make test` runs in isolated temporary directories. It never switches generations,
updates a flake, or collects garbage.

## Guidelines

- Keep the QML shared: all three hosts use `package/contents/ui/Engine.qml` and its
  views. Host-specific code belongs in the host files only.
- Helpers live in `package/contents/tools/sh/`. Expensive reads go through
  `run cached`, system changes through `run mutate`. See
  [docs/architecture.md](docs/architecture.md).
- Do not add background work that runs while the popup is closed.
- Run `pre-commit run --all-files` before committing. Use
  [conventional commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `chore:`).
- New settings need an entry in [docs/configuration.md](docs/configuration.md).

## Packaging

```bash
make pack          # <checkout-directory>-<version>.plasmoid
```

## Pull requests

Branch from `master`, keep the change focused, describe what you tested, and include
screenshots for UI changes.

By contributing you agree your work is released under the [MIT license](LICENSE).
