# Hosts: standalone, Plasma, Quickshell

All three hosts share one QML application (`package/contents/ui/Engine.qml` and its views). Only the host differs, so pick whichever fits your desktop:

| Host | Best for | Needs |
|---|---|---|
| **Standalone app** (`nixdatifier`) | Any desktop: GNOME, COSMIC, XFCE, Cinnamon, Sway, niri, i3, KDE, X11 | Qt 6 |
| **Plasma widget** | A native panel widget on KDE Plasma 6 | Plasma ≥ 6.0 |
| **Quickshell panel** | A pill and popup on Hyprland, and other layer-shell compositors | Quickshell |

## Standalone app

A normal window plus a tray icon. Closing the window hides it to the tray, and left-clicking the tray icon shows or hides it. The icon shows the pending-update count and spins while Nixdatifier is working.

```bash
nix run github:Muddyblack/nixdatifier   # try it without installing
nixdatifier --autostart                      # start at login (writes ~/.config/autostart)
```

| Command | Effect |
|---|---|
| `nixdatifier` | Open the window, or raise the running one |
| `nixdatifier --background` | Start in the tray (what autostart uses) |
| `nixdatifier --toggle` / `--show` / `--hide` | Control the running window |
| `nixdatifier --refresh` / `--settings` / `--quit` | Refresh, open settings, stop |
| `nixdatifier --status` | One line of JSON for a bar: `text`, `alt`, `class`, `tooltip`, `generation`, `updates` |

Settings are stored in `~/.config/nixdatifier/standalone.json`.

**Graphics.** Without working OpenGL/EGL (e.g. niri without
`hardware.graphics.enable = true`), the app falls back to Qt's CPU renderer
automatically. Shader effects are disabled in that mode. Set `QT_QUICK_BACKEND`
to choose a renderer yourself. The Quickshell panel (`#hyprland`) has no
click-outside dismiss outside Hyprland; use Escape or the tray toggle.

**Tray support differs by desktop.** The tray icon uses the StatusNotifier standard:

| Desktop | Tray icon |
|---|---|
| KDE Plasma, COSMIC, Waybar, XFCE, Cinnamon, i3bar/polybar with a tray | Works out of the box |
| GNOME | Needs the [AppIndicator](https://extensions.gnome.org/extension/615/appindicator-support/) extension. Without it there is no tray, so the app keeps a normal window: closing it quits, and you start it from the app launcher |

**Panel modules.** `--status` makes a panel button easy. For Waybar:

```jsonc
"custom/nixdatifier": {
  "exec": "nixdatifier --status",
  "return-type": "json",
  "interval": 60,
  "format": "{alt} {text}",
  "on-click": "nixdatifier --toggle"
}
```

There is no GNOME Shell extension or COSMIC applet yet; the tray icon and `--status` cover those panels.

## Plasma and Quickshell details

- **Plasma:** the plasmoid. Settings live in Plasma's widget configuration. Preview with `make view`.
- **Hyprland:** a Quickshell popup with a configurable panel pill (always visible, revealed at the screen edge, or tray only), a tray icon, six popup positions, and edge/side insets to avoid overlapping other widgets. Drag the pill to move it anywhere on its current screen; release to save, or click to open. The popup follows and stays within the screen. Adjust the insets under Design → Hyprland panel (pixels from the selected edges). Settings are stored in `~/.config/nixdatifier/hyprland.json`.

### Starting and stopping the Quickshell panel

From a checkout:

```bash
qs -p .                      # popup and pill only
nix run path:.#hyprland      # popup, pill, and tray icon
```

With the `hyprland` flake package installed, add `exec-once = nixdatifier-hyprland` to your Hyprland config instead.

Control a running instance over IPC (use the same config root you started it with; for the installed package that is its `share/nixdatifier` directory):

```bash
qs ipc -p . call panel toggle      # open / close the popup
qs ipc -p . call panel quit        # stop it
```

`open`, `hide`, `refresh`, `configure`, and `summary` work the same way.

The Quickshell panel also runs under Plasma, except that clicking outside the popup doesn't close it (that relies on Hyprland's focus grab).

See [the implementation notes](REDESIGN.md) for details on caching, IPC, and testing.
