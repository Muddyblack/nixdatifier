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
  <img src="./docs/readme/panel.svg" width="280" alt="Nixdatifier desktop panel pill">
</p>

<p align="center">
  System generations, package diffs, flake updates, secrets, dev environments, and Nix store usage, from a tray icon on any Linux desktop. Also available as a KDE Plasma 6 widget and a Quickshell panel.
</p>

## A closer look

<p align="center">
  <a href="https://www.youtube.com/shorts/sPLJVrwA7G4">
    <img src="https://i.ytimg.com/vi/sPLJVrwA7G4/hqdefault.jpg" width="360" alt="Watch Nixdatifier in action on YouTube Shorts">
  </a>
  <br>
  <a href="https://www.youtube.com/shorts/sPLJVrwA7G4"><strong>▶ Watch on YouTube Shorts</strong></a>
</p>

| Generations timeline | Flake updates |
| --- | --- |
| <img src="./docs/readme/demo_timeline.svg" alt="Generations Timeline Tab" width="440"> | <img src="./docs/readme/demo_updates.svg" alt="Flake Updates Tab" width="440"> |
| Booted and next-boot generations on one rail, with per-generation package counts and inline actions. | Pending upstream inputs, revision changes, and package previews before you update. |

| Compare generations | Tools & Nix store |
| --- | --- |
| <img src="./docs/readme/demo_diff.svg" alt="Compare Generations Tab" width="440"> | <img src="./docs/readme/demo_tools.svg" alt="Tools Tab" width="440"> |
| Package additions, removals, and upgrades between any two generations. | Store size, reclaimable space, cleanup, and the built-in tools. |

| Secrets inspector | Custom commands |
| --- | --- |
| <img src="./docs/readme/demo_secrets.svg" alt="Secrets Tab" width="440"> | <img src="./docs/readme/demo_commands.svg" alt="Commands Panel" width="440"> |
| Deployed and encrypted source secrets for sops-nix and agenix. | Your own terminal commands, run from the flake directory. |

---

## Highlights

- **Generations** — timeline with booted and next-boot markers, package changes, activate, set-boot, delete.
- **Compare** — diff any two generations; see the `.nix` changes behind each one.
- **Flake updates** — check inputs upstream, preview the package changes, update one input.
- **Tools** — secrets inspector, hash calculator, rebuild history, store usage, and cleanup.
- **Dev environments** — direnv state, `devShells`, and stale inputs for any project folder.
- **System health** — pending reboot, full `/boot`, end-of-life release, slow caches, failed units.
- **Persistent folders tab** — On impermanence setups, see what survives a reboot and clean up leftovers.
- **Any desktop** — standalone app with tray icon, Plasma 6 widget, or Quickshell panel.

Full list in [docs/features.md](docs/features.md).

## Quick start

```bash
nix run github:Muddyblack/nixdatifier   # try it without installing
nixdatifier --autostart                 # start in the tray at login
```

NixOS module, Home Manager, KDE Store, and manual installs are in [docs/install.md](docs/install.md).

## Documentation

| | |
|---|---|
| [Install](docs/install.md) | Nix, NixOS, Home Manager, KDE Store, requirements |
| [Command line](docs/cli.md) | `nixdatifier generations`, `updates`, `gc`, … with text, TSV and JSON output |
| [Hosts](docs/hosts.md) | Standalone app, Plasma widget, Quickshell panel, tray and CLI flags |
| [Configuration](docs/configuration.md) | Every setting and its default |
| [Features](docs/features.md) | What each tab does |
| [Architecture](docs/architecture.md) | How it works and what it costs while idle |
| [Contributing](CONTRIBUTING.md) | Development setup, tests, guidelines |
| [Security](SECURITY.md) | Reporting vulnerabilities |

## Support

If Nixdatifier saves you time, you can support its development:

[![GitHub Sponsors](https://img.shields.io/badge/Sponsor-GitHub-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/muddyblack)
[![Ko-fi](https://img.shields.io/badge/Ko--fi-muddyblack-ff5e5b?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/muddyblack)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-muddyblack-ffdd00?style=for-the-badge&logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/muddyblack)

Stars, bug reports, and translations help just as much.

## License

[MIT](LICENSE)
