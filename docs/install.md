# Install

## Standalone app (any Linux distribution with Nix)

Try it immediately without installing:

```bash
nix run github:Muddyblack/nixdatifier
```

Install into your Nix profile:

```bash
nix profile install github:Muddyblack/nixdatifier
nixdatifier --autostart # registers autostart entry to run in tray at login
```

## Command line only (no GUI, no Qt)

```bash
nix run github:Muddyblack/nixdatifier#cli -- generations
nix profile install github:Muddyblack/nixdatifier#cli   # installs `nixdatifier`
```

The `cli` package is just the shell helpers (about 340 KB on top of tools you already have), so it suits servers and terminal-only setups. The default package (`nixdatifier`) is the tray app and includes the same command line: `nixdatifier generations` works there too. Install one or the other, not both, since both provide `bin/nixdatifier`.

Both packages ship Tab completion for Bash, zsh and fish. NixOS and Home Manager pick it up on their own. With a plain `nix profile install` your shell may not look in the profile, so run this once and it works everywhere:

```bash
nixdatifier completion install   # detects your shell, asks, adds one line to its startup file
```

Open a new terminal afterwards. Running it again changes nothing.

Want both the tray app and the command line? Install just the app: it already includes `nixdatifier` on the command line. If you do put both packages in one profile there is no conflict; the app wins.

## NixOS module

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

Terminal only? Set `ui = false` and the module installs the `cli` package instead of the tray app and adds no autostart entry:

```nix
programs.nixdatifier = { enable = true; ui = false; };
```

Or install specific packages directly via `environment.systemPackages`:
- `nixdatifier.packages.${pkgs.system}.cli` (command line only)
- `nixdatifier.packages.${pkgs.system}.nixdatifier` (standalone desktop app, includes the command line)
- `nixdatifier.packages.${pkgs.system}.default` (KDE Plasma 6 widget)
- `nixdatifier.packages.${pkgs.system}.hyprland` (Quickshell / Hyprland panel & pill)

## Home Manager module

```nix
{
  inputs.nixdatifier.url = "github:Muddyblack/nixdatifier";

  # In your home-manager configuration:
  imports = [ nixdatifier.homeManagerModules.default ];

  programs.nixdatifier = {
    enable = true;
    autostart = true; # default: true, starts in tray at login
    # ui = false;     # command line only
  };
}
```

## KDE Store (Plasma widget)

Right-click your panel → *Add Widgets…* → *Get New Widgets…* and search for **Nixdatifier**, or download it from the [KDE Store](https://store.kde.org/p/2360222/).

On Linux distributions with Nix installed but without NixOS, the app opens on Tools
and labels the system “Nix”. Development environments, system health, hashes and
store inspection remain available. NixOS generations, updates, comparison, secrets,
rebuild commands and generation cleanup are hidden. Home Manager/profile generation
counts appear in System health; a Home Manager timeline is not implemented.
This mode has automated fixture coverage, but has not yet been tested on a real
non-NixOS installation.

## Manual install for Plasma 6 (any distro)

```bash
git clone https://github.com/Muddyblack/nixdatifier.git
cd nixdatifier
kpackagetool6 -t Plasma/Applet -i package
# or, to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then add the widget from Plasma's *Add Widgets* panel.

To remove: `kpackagetool6 -t Plasma/Applet -r org.muddyblack.nixosGenerationExplorer`

## Requirements

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

