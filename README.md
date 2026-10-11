<p align="center">
  <img src="./package/icon.png" width="128" alt="Nixdatifier Logo">
</p>

<h1 align="center">Nixdatifier</h1>

<p align="center">
  <a href="https://store.kde.org/p/2360222/">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store Download" />
  </a>
  <img src="https://img.shields.io/badge/Made%20for-NixOS-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="Made for NixOS" />
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  </a>
  <a href="https://store.kde.org/p/2360222/">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%3Fsearch%3Dnixdatifier%26format%3Djson&query=%24.data%5B0%5D.downloads&label=Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <a href="https://github.com/Muddyblack/nixdatifier/releases">
    <img src="https://img.shields.io/github/downloads/Muddyblack/nixdatifier/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
  </a>
  <img src="https://img.shields.io/badge/Started-May_2026-9c27b0?style=for-the-badge" alt="Project started May 2026" />
</p>

<p align="center">
  <img src="./readme/panel.svg" width="280" alt="Nixdatifier desktop panel pill">
</p>

<p align="center">
  System generations, package diffs, flake updates, secrets, dev environments, and Nix store usage, from a tray icon on any Linux desktop. Also available as a KDE Plasma 6 widget and a Quickshell panel.
</p>

## A closer look

| Generations timeline | Flake updates |
| --- | --- |
| <img src="./readme/demo_timeline.svg" alt="Generations Timeline Tab" width="440"> | <img src="./readme/demo_updates.svg" alt="Flake Updates Tab" width="440"> |
| Booted and next-boot generations on one rail, with per-generation package counts and inline actions. | Pending upstream inputs, revision changes, and package previews before you update. |

| Compare generations | Tools & Nix store |
| --- | --- |
| <img src="./readme/demo_diff.svg" alt="Compare Generations Tab" width="440"> | <img src="./readme/demo_tools.svg" alt="Tools Tab" width="440"> |
| Package additions, removals, and upgrades between any two generations. | Store size, reclaimable space, cleanup, and the built-in tools. |

| Secrets inspector | Custom commands |
| --- | --- |
| <img src="./readme/demo_secrets.svg" alt="Secrets Tab" width="440"> | <img src="./readme/demo_commands.svg" alt="Commands Panel" width="440"> |
| Deployed and encrypted source secrets for sops-nix and agenix. | Your own terminal commands, run from the flake directory. |

---

## Features

- **Generations** — A timeline of your system generations with the booted and next-boot ones highlighted, added / removed / changed package counts, kernel and NixOS release badges, and search across numbers, dates, and package names.
- **Generation actions** — Activate a generation now, set it for next boot, or delete it (through Polkit/`pkexec`). The booted and next-boot generations are protected, and confirmations are configurable.
- **Package changes** — Expand any generation to see what changed against the previous one (or the booted one), with versions, size deltas, store paths, app icons, and homepage links.
- **Compare** — Diff any two generations with `nix store diff-closures`.
- **Configuration changes** — When your config lives in a Git repository, each generation records its commit, so you can see the `.nix` changes between generations.
- **Flake updates** — Checks your flake inputs against their upstream repositories, notifies you of updates, and can preview the resulting package changes (`nix build --dry-run`, lock file untouched) or update a single input. Expanding an input shows what changed upstream: GitHub releases with their notes, the newest commits, and a link to the full diff (set `GITHUB_TOKEN` to lift GitHub's anonymous limit of 60 requests per hour).
- **Tools**
  - **Secrets** — Deployed secrets (`/run/secrets`, `/run/agenix.d`) and your encrypted source file: format, recipients, freshness.
  - **Hash calculator** — Hashes for URLs, archives, GitHub revisions, local files, and store paths, in both Nix and SRI form, with a ready-to-paste fetcher snippet.
  - **Rebuild history** — The output of past switches, cleanups, flake updates, and custom commands, kept after the notification is gone.
  - **Store usage** — Why a store path cannot be garbage-collected: its GC roots, referrers, and closure size.
- **Nix store** — Store size, free space, reclaimable space, and one-click cleanup (plus your own cleanup command).
- **Custom commands** — Up to four terminal commands (for example `nixos-rebuild switch`) in the footer Commands panel. The widget follows the command until it actually exits.
- **Dev environments** — Point it at any project folder (or pick one direnv already knows) to see whether its `.envrc` is allowed, what it loads (`use flake`, `use nix`, `dotenv`, …), how old the cached environment is, the flake's inputs and how stale they are, and its `devShells` (click one to list its packages). Buttons run `direnv allow`, open a terminal inside the environment, or run `nix flake update`. It can also measure how much store space each project's `.direnv` cache keeps alive and clear it. Nothing in it is specific to NixOS.
- **System health** — A quick check of what quietly goes wrong: a pending reboot (running kernel older than the activated one), a nearly full `/boot`, a NixOS release close to end of life, unreachable or slow binary caches, and failed systemd units, plus your Nix version, Home Manager and `nix profile` generations.
- **Any desktop** — A standalone app (window plus tray icon) needs only Qt, so it runs on GNOME, COSMIC, Sway, niri, XFCE, KDE, and X11. The same interface also runs as a Plasma widget and as a Quickshell popup with a panel pill. See [Where it runs](#where-it-runs).
- **Appearance** — Accent and timeline colors, background color and opacity, corner radius, font scale, icon style, glow, and motion (all animations can be turned off).

---

## Where it runs

All three hosts share one QML application (`package/contents/ui/Engine.qml` and its views). Only the host differs, so pick whichever fits your desktop:

| Host | Best for | Needs |
|---|---|---|
| **Standalone app** (`nixdatifier`) | Any desktop: GNOME, COSMIC, XFCE, Cinnamon, Sway, niri, i3, KDE, X11 | Qt 6 |
| **Plasma widget** | A native panel widget on KDE Plasma 6 | Plasma ≥ 6.0 |
| **Quickshell panel** | A pill and popup on Hyprland, and other layer-shell compositors | Quickshell |

### Standalone app

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

### Plasma and Quickshell details

- **Plasma:** the plasmoid. Settings live in Plasma's widget configuration. Preview with `make view`.
- **Hyprland:** a Quickshell popup with a configurable panel pill (always visible, revealed at the screen edge, or tray only), a tray icon, six popup positions, and edge/side insets to avoid overlapping other widgets. Drag the pill to move it anywhere on its current screen; release to save, or click to open. The popup follows and stays within the screen. Adjust the insets under Design → Hyprland panel (pixels from the selected edges). Settings are stored in `~/.config/nixdatifier/hyprland.json`.

#### Starting and stopping the Quickshell panel

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

See [the implementation notes](docs/REDESIGN.md) for details on caching, IPC, and testing.

---

## How it works

The QML engine runs small helper scripts from `package/contents/tools/sh/` and parses their output. Each host supplies its own process runner. Expensive reads go through `run cached`, a result cache shared by every widget instance. System changes go through `run mutate`, a lock that prevents two operations from running at once.

```mermaid
flowchart TD
    subgraph Hosts
        P["main.qml (Plasma)<br/>PlasmaProcess.qml"]
        Q["NixdatifierShell.qml (Hyprland)<br/>ProcessAdapter.qml"]
        W["Main.qml (standalone)<br/>ProcessRunner (C++ QProcess)"]
    end

    subgraph Core ["Shared QML"]
        E[Engine.qml]
        A[ApplicationView.qml]
        F["FullView.qml + tabs"]
    end

    subgraph Scripts ["tools/sh"]
        R["run (cache + lock)"]
        G["generations, details, change-counts"]
        FL["flake-context, flake-probe, dry-run-preview"]
        T["hash, secrets, store-usage, devenv, diskusage, history"]
        TE["terminal, terminal-job"]
    end

    subgraph System
        N["nix / nix-store / nix-env"]
        K["pkexec (polkit)"]
        S["/run/secrets, flake repo"]
    end

    P --> E
    Q --> E
    W --> E
    E --> A --> F
    E --> R
    R --> G & FL & T
    E --> TE
    G & FL & T --> N
    E -->|generation actions, cleanup| K
    T --> S
```

### Idle cost

The widget does as little as possible while you are not looking at it:

- **Settings do not poll while idle.** Info wakes only for a pending request timeout, retry, or refresh cooldown. Once loaded, its timer stops. Closing settings destroys the Info pane, aborts its requests, and releases their callbacks.
- **Tray animation reuses artwork.** The Quickshell tray helper rasterizes the SVG once and caches at most 60 smoothly rotated frames. It releases the animation frames when idle and ignores duplicate status updates.
- **Package previews have a deadline.** A stalled download, evaluation, or cache-lock wait ends after three minutes with a retryable error instead of leaving the loading indicator running indefinitely.
- **No expensive background timers.** Measuring the store (`du -sb /nix/store`, plus `nix-store --gc --print-dead` for the reclaimable size) walks the whole store, so it runs only while the popup is open, at most every 30 minutes, never twice at once, and at `nice -n 19` / idle I/O priority.
- **Animations stop when the popup closes.** Every looping animation is tied to whether the popup is on screen, so a closed popup does not keep the render loop awake.
- **The flake cache watch cannot spin.** Cross-instance sync waits on `inotifywait`. If that is missing or unusable, the widget falls back to a slow poll instead of respawning the watch in a tight loop.
- **Package lookups are bounded.** Homepage lookups are batched into one evaluation. The `/nix/store` fallback scan is a single pass and is skipped for large diffs.

While closed, a configured widget runs one `flake-probe` per check interval (hourly by default, shared between instances) and one cheap `sysinfo` read every 30 minutes.

---

## Requirements

### Runtime

| Dependency | Purpose |
|---|---|
| Qt 6 (standalone app), KDE Plasma ≥ 6.0, or Quickshell | Host: pick one |
| `direnv` | *Optional:* the Dev environments tab shows its state when present |
| `nix` | `store diff-closures`, `path-info`, dry-run previews, hashes (SRI conversion needs Nix ≥ 2.19) |
| `nix-env`, `nix-collect-garbage` | Generation switching, deletion, and cleanup |
| `pkexec` (polkit) | Privilege escalation for generation actions and cleanup |
| `jq`, `git` | Flake input checks, homepage lookup, history, configuration diffs |
| `flock`, `ionice` (util-linux) | Operation lock and low-priority store measurement |
| `inotifywait` (inotify-tools) | *Optional:* instant sync between widget instances |
| `notify-send` (libnotify) | *Optional:* desktop notifications |

The flake package puts all of these on the helpers' `PATH`. With a manual or KDE Store install they come from your system.

### Development

| Dependency | Purpose |
|---|---|
| `nix` with flakes | Development shell (`nix develop`) and package builds |
| `qt6.qtdeclarative` | `qmllint`, `qmlformat`, `qmltestrunner` |
| `kdePackages.plasma-sdk` / `kpackage` | `plasmoidviewer`, `kpackagetool6` |
| `pre-commit` | QML lint and format hooks |
| `zip` | `.plasmoid` archive |

Run `make help` for all targets. `make test` runs the QML and helper tests in isolated temporary directories; it never switches generations, updates a flake, or collects garbage.

---

## Install

### Standalone app (any Linux distribution with Nix)

Try it immediately without installing:

```bash
nix run github:Muddyblack/nixdatifier
```

Install into your Nix profile:

```bash
nix profile install github:Muddyblack/nixdatifier
nixdatifier --autostart # registers autostart entry to run in tray at login
```

### NixOS module

```nix
# flake.nix
{
  inputs.nixdatifier.url = "github:Muddyblack/nixdatifier";

  outputs = { self, nixpkgs, nixdatifier, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        nixdatifier.nixosModules.default
        {
          programs.nixdatifier = {
            enable = true;
            autostart = true; # default: true, starts in tray at login
          };
        }
      ];
    };
  };
}
```

Or install specific packages directly via `environment.systemPackages`:
- `nixdatifier.packages.${pkgs.system}.nixdatifier` (standalone desktop app)
- `nixdatifier.packages.${pkgs.system}.default` (KDE Plasma 6 widget)
- `nixdatifier.packages.${pkgs.system}.hyprland` (Quickshell / Hyprland panel & pill)

### Home Manager module

```nix
{
  inputs.nixdatifier.url = "github:Muddyblack/nixdatifier";

  # In your home-manager configuration:
  imports = [ nixdatifier.homeManagerModules.default ];

  programs.nixdatifier = {
    enable = true;
    autostart = true; # default: true, starts in tray at login
  };
}
```

### KDE Store (Plasma widget)

Right-click your panel → *Add Widgets…* → *Get New Widgets…* and search for **Nixdatifier**, or download it from the [KDE Store](https://store.kde.org/p/2360222/).

On Linux distributions with Nix installed but without NixOS, the app opens on Tools
and labels the system “Nix”. Development environments, system health, hashes and
store inspection remain available. NixOS generations, updates, comparison, secrets,
rebuild commands and generation cleanup are hidden. Home Manager/profile generation
counts appear in System health; a Home Manager timeline is not implemented.
This mode has automated fixture coverage, but has not yet been tested on a real
non-NixOS installation.

### Manual install for Plasma 6 (any distro)

```bash
git clone https://github.com/Muddyblack/nixdatifier.git
cd nixdatifier
kpackagetool6 -t Plasma/Applet -i package
# or, to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then add the widget from Plasma's *Add Widgets* panel.

To remove: `kpackagetool6 -t Plasma/Applet -r org.muddyblack.nixosGenerationExplorer`

### Packaging for distribution

```bash
make pack
# produces <checkout-directory>-<version>.plasmoid
```

---

## Configuration

Everything is in the widget's right-click → *Configure* menu (on Hyprland, the ⚙ button in the popup).

Settings use grouped cards with a search across all settings and stacked controls in narrow windows.
The **Info** tab shows the installed and latest release, GitHub stars and downloads,
KDE Store downloads, license, contributors, and support links. Its requests and timer
stop when settings close; the Info pane is released when hidden or another tab opens.

### General

| Setting | Default | Description |
|---|---|---|
| **System flake path** | `""` | Your NixOS flake directory. Empty detects `/etc/nixos`, `~/nixos-config`, or `~/.config/nixos`. |
| **Configuration Git repository** | `""` | Repository whose commit is recorded for each generation. Empty uses the flake path. |
| **Check updates every (seconds)** | `3600` | Flake input check interval (60–86400). |
| **Maximum generations shown** | `10` | Generations listed in the timeline (3–200). |
| **Detect hostname and flake configuration** | `true` | When off, previews need a flake with exactly one NixOS configuration. |
| **Open on** | `timeline` | Starting view: `timeline`, `updates`, `diff`, `tools`, `devenv`, `secrets`, `hash`, `history`, or `storeusage`. |

### Commands

| Setting | Default | Description |
|---|---|---|
| **Commands** | *see below* | Up to four terminal commands, run from your flake directory. |
| **Show Commands button in the footer** | `true` | Shows the footer launcher for the Commands panel. |
| **Terminal emulator** | `""` | Empty detects the desktop default. Supports konsole, kitty, foot, alacritty, wezterm, ghostty, gnome-terminal, ptyxis, and xterm. |
| **Custom cleanup command** | `""` | Adds your own command to the cleanup menu. |

### Behavior

| Setting | Default | Description |
|---|---|---|
| **Use pkexec for privileged operations** | `true` | Uses the system Polkit authentication dialog. |
| **Enable Activate now** | `true` | Allows switching the running system without a reboot. |
| **Confirm before switching generation** | `true` | Asks before Activate and Set boot. |
| **Confirm before deleting generation** | `true` | Asks before deleting a generation. Store cleanups always ask. |
| **Show delete generation action** | `true` | Shows Delete on generation cards. |
| **Show update notifications** | `true` | Desktop notifications for new flake updates and finished actions. |
| **Refresh generations when the popup opens** | `true` | Reloads generations and system info each time you open the popup. |
| **Check flake inputs in the background** | `true` | Turns the update checks on or off. |
| **Deployed secrets directory** | `""` | Empty detects `/run/secrets` or `/run/agenix.d`. |
| **Encrypted source secrets path** | `""` | Empty detects a SOPS file in the flake directory. |
| **Show package search/filter** | `true` | Filter box above package lists. |
| **Package detail mode** | `compact` | `compact` rows expand on click; `detailed` shows every row expanded. |
| **Show application icons** | `true` | App icons next to package names. |

### Design

| Setting | Default | Description |
|---|---|---|
| **Timeline color** | `#71849b` | Rail and older-generation markers. |
| **Accent color** | `#91bcff` | Highlights, selection, and links. |
| **Use system text color** / **Custom text color** | `true` / `#ffffff` | The system color is checked for contrast against the widget background. |
| **Font scale** | `1.0` | 0.7–2.0. |
| **Show glass background** | `true` | Draws the widget's own card; off uses the Plasma theme background. |
| **Background color** | `#f5131923` | `#AARRGGBB`; the first pair sets opacity (e.g. `#80131923` for half). |
| **Corner radius** | `14` | 0–32. |
| **Glow on timeline markers** | `true` | Soft glow on markers and change indicators. |
| **Animate the flake and traveling marker** | `true` | Turn off for reduced motion. |
| **Icon colors** | `colored` | `colored`, `white`, `black`, or `accent`. |
| **Compact representation** | `icon` | Panel look: `icon`, `number`, `both`, or `pill`. |
| **Show pending update badge** | `true` | Update count on the panel icon. |
| **Width** / **Height** | `600` / `740` | Popup size; resizing the popup remembers it. |

On Hyprland the Design tab also has **pill mode** (`always`, `hover`, `tray`) and **popup position** (`top-left` … `bottom-right`).

### Custom commands format

The `customCommands` setting stores a JSON array:

```json
[
  { "label": "update", "cmd": "nix flake update" },
  { "label": "upnix",  "cmd": "upnix" }
]
```

`label` is optional (the command itself is shown instead). At most four entries are used.
