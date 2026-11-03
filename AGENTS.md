# Agent notes for nixdatifier

Instructions for coding agents (Claude Code, Codex, …) working in this repo.
`CONTRIBUTING.md` and `docs/architecture.md` have the full picture.

## Every feature ships in the GUI *and* the CLI/TUI

Nixdatifier has two front ends over the same helper scripts, and users expect
both to behave the same. A change that touches only one of them is unfinished.

| Front end | Where |
|---|---|
| GUI: Plasma widget, plus the Hyprland shell and standalone window that reuse it | `package/contents/ui/` (`Engine.qml` runs the helpers; tabs like `UpdatesTab.qml` show results), `hyprland/`, `standalone/` |
| CLI | `package/contents/tools/sh/nixdatifier` (`cmd_*` functions; text, `--plain` TSV, `--json`) |
| TUI (interactive `nixdatifier` / `nixdatifier menu`) | `package/contents/tools/sh/tui`. It calls the CLI (`cli …`, `"$NXD_CLI" --json …`), so the CLI output is what the TUI shows |
| Shared logic | `package/contents/tools/sh/*` helpers (e.g. `dry-run-preview`), called by both `Engine.qml` and the CLI |

When adding or changing a feature:

1. Put the logic in a shared helper script when both front ends need it. Don't duplicate it in QML and bash.
2. GUI: parse the helper's output in `Engine.qml` and show it in the relevant tab.
3. CLI: expose it in the `cmd_*` function in all three formats: human text, `--plain` TSV and `--json`. `--json` is a stable contract; use camelCase keys and sizes in bytes.
4. TUI: check what the TUI shows for that command (`grep -n 'cli <command>' package/contents/tools/sh/tui`) and confirm it still reads well there.
5. Tests: `tests/test_helpers.py` for helpers and CLI, `tests/tst_*.qml` for Engine/UI.

## Settings must exist everywhere

A new GUI setting is declared in **all** of these places (`test_settings_agree_across_hosts` checks this):
`package/contents/config/main.xml`, `package/contents/ui/Settings.qml`,
`hyprland/NixdatifierShell.qml` (the `cfg` adapter), `package/contents/ui/SettingsSchema.js`,
and `package/contents/ui/configGeneral.qml` (`cfg_X` and `cfg_XDefault`).

If the CLI/TUI needs it too, also add a config key: `CONFIG_KEYS`, `config_var`,
`GUI_MAP`, the `gui_sync` conversions and the `config set` validation in
`tools/sh/nixdatifier`; `_syncKeys` plus an `on…Changed` handler in `Engine.qml`;
and `settings_desc` in `tools/sh/tui`. Document it in `docs/configuration.md`
and/or `docs/cli.md`.

## Before you finish

```sh
nix develop -c make test   # shell-helper tests + QML tests
nix develop -c make lint   # ruff, shellcheck, qmllint, qmlformat, unused code
```

For a visual check of the GUI, `tests/Smoke.qml` renders the app offscreen and
saves screenshots to `/tmp/nixdatifier-*.png`:
`QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic qml tests/Smoke.qml`
