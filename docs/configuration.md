# Configuration

Everything is in the widget's right-click → *Configure* menu (on Hyprland, the ⚙ button in the popup).

Settings use grouped cards with a search across all settings and stacked controls in narrow windows.
The **Info** tab shows the installed and latest release, GitHub stars and downloads,
KDE Store downloads, license, contributors, and support links. Its requests and timer
stop when settings close; the Info pane is released when hidden or another tab opens.

## General

| Setting | Default | Description |
|---|---|---|
| **System flake path** | `""` | Your NixOS flake directory. Empty detects `/etc/nixos`, `~/nixos-config`, or `~/.config/nixos`. |
| **Configuration Git repository** | `""` | Repository whose commit is recorded for each generation. Empty uses the flake path. |
| **Check updates every (seconds)** | `3600` | Flake input check interval (60–86400). |
| **Maximum generations shown** | `10` | Generations listed in the timeline (3–200). |
| **Detect hostname and flake configuration** | `true` | When off, previews need a flake with exactly one NixOS configuration. |
| **Check tarball inputs** | `true` | Check inputs fetched as tarballs (channels, `.tar.zst`). A light HEAD request compares the immutable URL Nix locked; Nix only downloads the archive if the server gives no hint. |
| **Check nested inputs** | `false` | Walk every transitive input instead of the root inputs (plus a wrapper flake's own inputs). One request per input. |
| **Open on** | `timeline` | Starting view: `timeline`, `updates`, `diff`, `tools`, `devenv`, `secrets`, `hash`, `history`, `storeusage`, or `impermanence`. |

Update checks read the root inputs of the configured flake's `flake.lock`, independently
of how many NixOS or Home Manager outputs it defines. When the flake is a wrapper (it has
a single input, or an input of type `path`), that input's own direct inputs are checked
too and shown as `wrapper/input`. Turn on **Check nested inputs** to follow deeper levels. **Configuration Git
repository** only controls generation history.

Git-backed inputs are checked against their upstream revision. Tarball inputs are
resolved with `nix flake metadata --refresh` and compared by their unpacked content
hash, so compression formats supported by your Nix installation work too. These
checks can download archives. Immutable archive URLs remain unchanged until you
edit the input URL.

For troubleshooting, run `nixdatifier --refresh --json updates --all` to include
unchanged, pinned/unsupported, and unreachable inputs. Fetch failures include a
reason; the widget also shows a notification when an upstream cannot be reached.

## Commands

| Setting | Default | Description |
|---|---|---|
| **Commands** | *see below* | Up to four terminal commands, run from your flake directory. |
| **Show Commands button in the footer** | `true` | Shows the footer launcher for the Commands panel. |
| **Terminal emulator** | `""` | Empty detects the desktop default. Supports konsole, kitty, foot, alacritty, wezterm, ghostty, gnome-terminal, ptyxis, and xterm. |
| **Custom cleanup command** | `""` | Adds your own command to the cleanup menu. |

## Behavior

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
| **Use the GitHub CLI login** | off | Borrows the token of a signed-in `gh` when no token file is set. Off by default because that token often has wide scopes. Nix modules: `githubUseGh`. |
| **GitHub token file** | `""` | File holding a GitHub token (a sops-nix or agenix secret path) that lifts the rate limit for release notes. Only the path is stored. Empty stays anonymous unless **Use the GitHub CLI login** is on. Nix modules: `programs.nixdatifier.githubTokenFile`. |
| **Extra persistent folders** | `""` | Colon-separated roots (for example `/persist:/mnt/data`) added to the ones detected from the mounts for the Persistent folders tool. |
| **Offer cleanup for folders untouched for (days)** | `180` | How long nothing inside a home folder may change before the Persistent folders cleanup suggests it. |
| **Show package search/filter** | `true` | Filter box above package lists. |
| **Package detail mode** | `compact` | `compact` rows expand on click; `detailed` shows every row expanded. |
| **Show application icons** | `true` | App icons next to package names. |

## Design

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

## Shared with the terminal view

The window and `nixdatifier` (the terminal view and CLI) keep these settings in step: system flake path, configuration Git repository, secrets path and source, GitHub token file and CLI login, extra persistent folders, check interval, notifications, and the Commands. Change one in either place and it changes in both; the shared copy is `~/.config/nixdatifier/config`. The first time the window starts with this version, it adopts the values it already had, so nothing needs redoing. Environment variables (and the Nix modules' `tui.commands`) still win on the command line.

## Custom commands format

The `customCommands` setting stores a JSON array:

```json
[
  { "label": "update", "cmd": "nix flake update" },
  { "label": "upnix",  "cmd": "upnix" }
]
```

`label` is optional (the command itself is shown instead). At most four entries are used.
