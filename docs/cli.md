# Command line

Every window runs its system actions through one script, `package/contents/tools/sh/nixdatifier`. Installed, it is `nixdatifier <command>` (see [install](install.md) for the CLI-only package). Because the window calls the same code, a terminal, a script or an AI agent gets the same locking, cache and history as the UI.

```console
$ nixdatifier status
gen 312 · reboot needed · 2 updates

$ nixdatifier generations --limit 3
NUMBER  DATE                 NEXT_BOOT  BOOTED  NIXOS_VERSION           KERNEL
312     2026-10-12 21:04:11  yes        -       25.11.20261012.a1b2c3d  6.12.5
311     2026-10-09 08:30:02  -          yes     25.11.20261008.9f8e7d6  6.12.5

$ nixdatifier delete --keep 5 --older-than 30d      # lists, asks, deletes
$ nixdatifier updates --check || echo "inputs are behind"   # exit 2
$ nixdatifier diff --json | jq '.counts'
```

Commands can be abbreviated (`nixdatifier gen`, `nixdatifier upd`) and `nixdatifier help <command>` explains each one.
Misspelled commands, options and `dev`/`persist` subcommands suggest nearby names
(for example, `generatoins` suggests `generations`) and exit with status 2.
Suggestions never run automatically. Missing option values also report a usage error.

| Area | Your packages | `profile [list\|install REF…\|remove NAME…\|upgrade [NAME…]\|clean]` manages what `nix profile` installed for your user (`nixpkgs#hello`, `github:user/repo`); also in the window's Tools tab and under Profiles in the interactive view. `profiles` lists the profile generations |
| Commands |
| --- | --- |
| Generations | `generations`, `diff [A [B]]`, `diff --config`, `switch N`, `boot N`, `rollback`, `delete N…` / `--keep N` / `--older-than DAYS`, `profiles` (Home Manager, `nix profile`) |
| Flake | `updates [--all] [--check]`, `update [INPUT]`, `preview INPUT` (packages that would change), `notes INPUT` (upstream releases and commits) |
| Store | `disk`, `disk STORE-PATH` (GC roots, referrers, closure), `gc [--older-than 14d \| --all]`, `path NAME [VERSION]` |
| System | `status`, `health`, `info`, `history`, `hash` |
| Secrets | `secrets` (names and freshness, never values) |
| Impermanence | `persist` (`status`, `sizes`, `ls DIR`, `scan`, `cleanup`, `rm PATH…`) |
| Dev environments | `dev` (`list`, `show DIR`, `shells DIR`, `pkgs DIR SHELL`, `clear DIR`) |
| Interactive | `nixdatifier` alone (or `menu`) opens the [interactive view](#interactive-view). `switch`, `boot` and `delete` without a number let you pick a generation from a list (fzf if installed) |
| Shell | `completion install` sets up your shell in one step; `completion bash\|zsh\|fish` prints the script |
| Commands | `commands [list\|add LABEL CMD\|rm LABEL]` manages your quick-run commands, the same four the window's Commands panel shows; `run LABEL` runs one from the flake directory, as typed; `rebuild` runs the one labelled `rebuild`, or `nixos-rebuild switch --flake DIR` as root when there is none. All ask first and land in History |
| Update checks | `watch on\|off\|status\|run`: a systemd user timer checks the flake inputs every `check_interval` (default `6h`) and sends a desktop notification for new updates. Off by default; also under *Update checks* in the interactive view, or `programs.nixdatifier.tui.updateCheck` in the Nix modules |
| Cleanup | `clean` deletes old generations (keeps 5, drops older than 14 days) and collects garbage in one go |

The CLI and desktop packages install Bash, zsh and fish completion scripts in
the standard shell directories. With your shell's completion support enabled,
press Tab to suggest commands, options, generation numbers (both arguments of
`diff`), or flake input names for `update`, `preview` and `notes`. Generation and
input suggestions read local data without changing anything or checking upstream.
You can use these completions from any working directory.

For an uninstalled checkout, load the script once in your current terminal:

```bash
source <(./package/contents/tools/sh/nixdatifier completion bash)
# zsh: source <(./package/contents/tools/sh/nixdatifier completion zsh)
# fish: ./package/contents/tools/sh/nixdatifier completion fish | source
```

For Bash and fish development use, put the checkout's
`package/contents/tools/sh` directory on PATH and invoke `nixdatifier` by name.
The zsh script also registers completion for paths ending in `/nixdatifier`.

## Interactive view

On a terminal, a bare `nixdatifier` opens a full-screen view in the spirit of
lazygit. Sections are on the left, and the highlighted one's details show live
on the right. The header shows the next-boot and booted generations, the
release and its end of life, and failed units. Type to jump, press Enter to
open. Esc or Backspace (on an empty search) goes back one screen, and F1 lists
every key.

| Screen | What you can do |
| --- | --- |
| Generations | Enter opens a generation's package changes. Ctrl-O switches the comparison between *previous*, *booted* and *next boot*. Tab marks generations; with two marked, Enter compares them. Ctrl-S switches, Ctrl-B sets next boot, Ctrl-D deletes the marked (or highlighted) ones. |
| What changed | The package list with `[All] [+Added] [-Removed] [~Changed]` buttons. Click them, press Tab to cycle, or use Alt-A/R/C/0. Type to filter. Enter shows the package's store paths in both generations. |
| Updates | Every flake input with its status. The preview has the release notes. Enter lists the packages an update would change. Ctrl-U updates one input, Alt-U updates all. |
| History | Every switch, cleanup and update, with its full output. |
| Dev environments | direnv projects by cache size. Enter evaluates their shells, Ctrl-O opens a shell there, Ctrl-X clears `.direnv`. |
| Impermanence, Health, Disk, Secrets, Profiles, System info | Live preview; Enter opens it full screen with search. |
| Clean up, Hash calculator | The preview shows a dry run of what Enter would do. |

Everywhere: Ctrl-R refreshes, Ctrl-/ hides the preview, Shift-↑↓ scrolls it.
Anything that changes the system runs the normal command, so it asks first and
lands in History.

The view lives in its own script, `package/contents/tools/sh/tui`. It holds no
system logic: every list and action calls `nixdatifier`, so the CLI stays the
single source of behaviour. It needs fzf 0.70 or newer and ignores your
`FZF_DEFAULT_OPTS`, so the layout is always the same. Without a usable fzf, or
with `NIXDATIFIER_NO_FZF=1`, it falls back to a numbered menu. With
[chafa](https://hpjansson.org/chafa/) installed, the Overview draws the logo.
The packages bring both fzf and chafa. Set `NIXDATIFIER_LOGO=image` to draw the
logo as a real picture on terminals with graphics support (kitty, WezTerm,
Ghostty, Konsole), or `off` to hide it. Package diffs are kept in
`~/.cache/nixdatifier/tui`, since generations never change. That makes

### Colour themes

F1 lists the keys; Alt-C (or a click on the footer) cycles the colour theme and
Alt-L the layout, and the choice is remembered in
`~/.config/nixdatifier/tui.conf`. Built in: `deep` (default, Midnight Marina
Deep), `midnight`, `marina` (the widget's palette), `full` and `plain`.

Your own theme is a file `~/.config/nixdatifier/themes/NAME.theme` (or in
`/etc/nixdatifier/themes`) with one `key=#rrggbb` per line and `#` comment
lines. Keys you leave out come from `deep`; a file named like a built-in
replaces it.

```
accent=#ff8800   # prompt, headings, icons
label=#ffb066    # box titles
text=#e8e8e8
muted=#909090    # descriptions
border=#444444
select=#303030  # highlighted row
match=#ffcc00    # search matches
pointer=#ff8800
ok=#44ffb1
bad=#e52e2e
warn=#ffe073
bg=              # empty: keep the terminal's background
```

With Nix, set
`programs.nixdatifier.tui.themes.NAME = { accent = "#ff8800"; ... };` and
`programs.nixdatifier.tui.theme = "NAME";` in the NixOS or Home Manager module.
reopening a comparison instant.

## Built for the terminal

- **Three views of the same data.** Text is aligned for people (colour only on a terminal; `NO_COLOR` and `--color never` are honoured), `--plain` is header-less TSV for `cut`/`awk`, `--json` is stable JSON with sizes in bytes. Text sizes are human (`3.2G`); the other two stay exact.
- **stdout is data, stderr is talk.** Progress (“Checking upstream…”), notices and prompts go to stderr and only when it is a terminal, so pipes stay clean. `-q` silences them.
- **Safe by default, scriptable on purpose.** Anything that changes the system asks first. Without a terminal it refuses unless you pass `--yes`, instead of hanging. `--dry-run` prints the exact commands. `delete` never touches the running or booted generation. With `--json`, a change prints one result object (`{"ok":true,"action":"delete","exitCode":0,...}`) and its output goes to stderr.
- **Fast and cached.** Slow reads (upstream probe, store measurement, health) share the cache the window uses; `--refresh` bypasses it.
- **Root the way you do it.** `sudo` by default, `--priv doas|pkexec|none` (or `NIXDATIFIER_PRIV`); nothing when you already are root. Reads never need root.
- **One change at a time**, across the terminal and every open window (exit 75 if busy), and each run lands in the history the window shows.
- **Exit codes:** `0` ok, `1` failed, `2` usage error (also `updates --check` when updates exist), `75` busy.

## Configuration

There is no config file; it is flags and environment, so it works the same in a shell alias, a systemd unit or CI:

| Variable | Meaning |
| --- | --- |
| `NIXDATIFIER_FLAKE` | flake directory (else `/etc/nixos`, `~/nixos-config`, `~/.config/nixos`) |
| `NIXDATIFIER_PRIV` | `sudo`, `doas`, `pkexec` or `none` |
| `NIXDATIFIER_CONFIG_REPO` | git repo whose commits `diff --config` compares (default: the flake) |
| `NIXDATIFIER_PERSIST` | extra impermanence roots, `/a:/b` |
| `NIXDATIFIER_SECRETS`, `NIXDATIFIER_SECRETS_SOURCE` | secrets directory and source file |
| `GITHUB_TOKEN` | lifts GitHub's rate limit for `notes` |
| `NIXDATIFIER_GITHUB_TOKEN_FILE` | file holding a GitHub token, used when `GITHUB_TOKEN` is unset (config key `github_token_file`). |
| `NIXDATIFIER_CHECK_TARBALLS` | `off` skips tarball flake inputs when checking for updates (config key `check_tarballs`; on by default) |
| `NIXDATIFIER_DEEP_INPUTS` | `on` checks every transitive flake input, not just the root (and wrapper) inputs (config key `deep_inputs`; off by default) |
| `NIXDATIFIER_IGNORE_INPUTS` | comma-separated input names (globs allowed) to leave out of update checks (config key `ignored_inputs`; empty by default) |
| `NIXDATIFIER_GITHUB_USE_GH` | `on` borrows the login of a signed-in `gh` when there is no token (config key `github_use_gh`; off by default, its token often has wide scopes) |

`diff --config` needs to know which config commit built each generation. `generations` and the window record it; run `nixdatifier snapshot` from a post-rebuild hook if you only rebuild from a terminal.
