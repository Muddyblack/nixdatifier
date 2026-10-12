# Features

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
- **Any desktop** — A standalone app (window plus tray icon) needs only Qt, so it runs on GNOME, COSMIC, Sway, niri, XFCE, KDE, and X11. The same interface also runs as a Plasma widget and as a Quickshell popup with a panel pill. See [Hosts](hosts.md).
- **Appearance** — Accent and timeline colors, background color and opacity, corner radius, font scale, icon style, glow, and motion (all animations can be turned off).
