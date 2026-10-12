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

Or install specific packages directly via `environment.systemPackages`:
- `nixdatifier.packages.${pkgs.system}.nixdatifier` (standalone desktop app)
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

