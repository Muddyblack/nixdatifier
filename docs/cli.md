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
$ nixdatifier why zstd --all                         # what pulls zstd into the system
$ nixdatifier doctor                                 # why a view is empty; paste it into bug reports
$ nixdatifier preview nixpkgs --json | jq '{downloadBytes, unpackedBytes, toBuild}'   # cost before updating
```

Commands can be abbreviated (`nixdatifier gen`, `nixdatifier upd`) and `nixdatifier help <command>` explains each one.
Misspelled commands, options and `dev`/`persist` subcommands suggest nearby names
(for example, `generatoins` suggests `generations`) and exit with status 2.
Suggestions never run automatically. Missing option values also report a usage error.

| Area | Your packages | `profile [list\|install REF…\|remove NAME…\|upgrade [NAME…]\|clean]` manages what `nix profile` installed for your user (`nixpkgs#hello`, `github:user/repo`); also in the window's Tools tab and under Profiles in the interactive view. `profiles` lists the profile generations |
| Commands |
| --- | --- |
| Generations | `generations`, `diff [A [B]]`, `diff --config`, `switch N`, `boot N`, `rollback`, `delete N…` / `--keep N` / `--older-than DAYS`, `profiles` (Home Manager, `nix profile`) |
| Flake | `updates [--all] [--check]`, `update [INPUT...]`, `preview INPUT` (what the update would cost, which packages would change and, once you ran `cve`, which known vulnerabilities it would fix or introduce), `notes INPUT` (upstream releases and commits) |
| Store | `disk`, `disk STORE-PATH` (GC roots, referrers, closure), `gc [--older-than 14d \| --all]`, `optimise` (hard-link identical files with `nix-store --optimise`; asks first, records what it freed in History), `optimise status` (whether `auto-optimise-store` or the `nix-optimise` timer is on, the last run, and a rough estimate of what a run would free), `clean --optimise`, `path NAME [VERSION]`, `why NAME\|STORE-PATH [VERSION] [--all]` (the dependency chain that pulls a package into the system, and what pulls it in) |
| System | `status`, `health`, `info`, `history`, `hash`, `doctor` (what was checked when nothing shows up: NixOS, the required tools, the Nix store, the profiles and generation list, the flake path, flake or channels setup, flakes enabled, the flake's git state; each failure with its fix and the failed command's output. Exits 1 when a check fails) |
| Vulnerabilities | `cve [--generation N] [--all]`: known vulnerabilities (CVEs) in the running system (or generation N), found by [vulnix](https://github.com/nix-community/vulnix): each affected package with its CVE ids, CVSS v3 score and severity. Exits 2 when a critical or high one is found, for cron and CI. `cve status` shows whether a scanner is there and the last scan, without scanning. Only when vulnix is installed, or with `cve_nix_run on` (runs `nix run nixpkgs#vulnix`); see [Vulnerability scan](#vulnerability-scan) |
| Secrets | `secrets` (names and freshness, never values) |
| Impermanence | `persist` (`status`, `sizes`, `ls DIR`, `scan`, `cleanup`, `rm PATH…`) |
| Dev environments | `dev` (`list`, `show DIR`, `shells DIR`, `pkgs DIR SHELL`, `clear DIR`) |
| Interactive | `nixdatifier` alone (or `menu`) opens the [interactive view](#interactive-view). `switch`, `boot` and `delete` without a number let you pick a generation from a list (fzf if installed) |
| Shell | `completion install` sets up your shell in one step; `completion bash\|zsh\|fish` prints the script |
| Commands | `commands [list\|add LABEL CMD\|rm LABEL]` manages your quick-run commands, the same four the window's Commands panel shows; `run LABEL` runs one from the flake directory, as typed; `rebuild [switch\|boot\|test\|dry-build]` runs the one labelled `rebuild` exactly as saved (it gets the mode in `NIXDATIFIER_REBUILD_MODE`), or `nh os MODE DIR` when `nh` is installed, else `nixos-rebuild MODE --flake DIR` as root; a terminal shows it through `nom` when installed. `rebuild plan` prints what each mode would run, `rebuild status` the running or last rebuild (phase, derivations built, paths fetched, download size, last lines; `--json` has `built`, `toBuild`, `fetched`, `toFetch`, `downloadBytes`, `exitCode`, `tail`), `rebuild log` its output. Status follows a rebuild started anywhere: terminal, TUI or window. All ask first and land in History |
| Update checks | `watch on\|off\|status\|run`: a systemd user timer checks the flake inputs every `check_interval` (default `6h`) and sends a desktop notification for new updates. Off by default; also under *Update checks* in the interactive view, or `programs.nixdatifier.tui.updateCheck` in the Nix modules |
| Hosts | `hosts [status\|list\|add NAME TARGET\|rm NAME]`: the machines of your flake and how each is (see [Hosts](#several-machines-one-flake)); `--host NAME` before `generations`, `diff`, `disk`, `health`, `status`, `info`, `switch`, `boot`, `rollback`, `delete`, `clean`, `gc` or `rebuild` runs that command on the host over ssh |
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
| What changed | The package list with `[All] [+Added] [-Removed] [~Changed]` buttons. Click them, press Tab to cycle, or use Alt-A/R/C/0. Type to filter. Enter shows the package's store paths in both generations and why it is in the system; Ctrl-W lists everything that pulls it in. |
| Updates | Every flake input with its status. The preview has the release notes. Enter lists the packages an update would change. Ctrl-U updates one input, Alt-U updates all. |
| History | Every switch, cleanup and update, with its full output. |
| Dev environments | direnv projects by cache size. Enter evaluates their shells, Ctrl-O opens a shell there, Ctrl-X clears `.direnv`. |
| Vulnerabilities | Only with a scanner. The preview shows the last scan without starting one; Enter scans and lists every affected package with its CVEs. Health shows the last scan's counts, and an update's preview the CVEs it would fix or introduce. |
| Impermanence, Health, Disk, Secrets, Profiles, System info, Doctor | Live preview; Enter opens it full screen with search. When Generations, Compare or Updates have nothing to show, they show the Doctor checklist instead. |
| Why is this here? | Type a package name or store path: the chain from the system down to it, then everything that pulls it in. |
| Clean up, Hash calculator | The preview shows a dry run of what Enter would do. Under Disk & clean up, *Optimise store* shows the deduplication status and estimate first. |

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
| `NIXDATIFIER_REBUILD_TOOL` | `nh` or `nixos-rebuild`: which one `rebuild` uses when you saved no `rebuild` command (default: `nh` when installed) |
| `NIXDATIFIER_REBUILD_MODE` | set for your own `rebuild` command: `switch`, `boot`, `test` or `dry-build` |
| `NIXDATIFIER_CONFIG_REPO` | git repo whose commits `diff --config` compares (default: the flake) |
| `NIXDATIFIER_PERSIST` | extra impermanence roots, `/a:/b` |
| `NIXDATIFIER_SECRETS`, `NIXDATIFIER_SECRETS_SOURCE` | secrets directory and source file |
| `GITHUB_TOKEN` | lifts GitHub's rate limit for `notes` |
| `NIXDATIFIER_GITHUB_TOKEN_FILE` | file holding a GitHub token, used when `GITHUB_TOKEN` is unset (config key `github_token_file`). |
| `NIXDATIFIER_CHECK_TARBALLS` | `off` skips tarball flake inputs when checking for updates (config key `check_tarballs`; on by default) |
| `NIXDATIFIER_DEEP_INPUTS` | `on` checks every transitive flake input, not just the root (and wrapper) inputs (config key `deep_inputs`; off by default) |
| `NIXDATIFIER_PREVIEW_WARN` | `preview` warns when an update downloads more than this many MiB (config key `preview_warn`, shared with the window; `0` never warns; 2048 by default) |
| `NIXDATIFIER_MEASURE_STORE` | `off` skips the slow store measurement; `disk` and the window then show only free space until you ask (`disk --refresh`, or Measure in the window; config key `measure_store`; on by default) |
| `NIXDATIFIER_IGNORE_INPUTS` | comma-separated input names (globs allowed) to leave out of update checks (config key `ignored_inputs`; empty by default) |
| `NIXDATIFIER_CVE_NIX_RUN` | `on` runs vulnix with `nix run nixpkgs#vulnix` when it is not installed, which downloads it (config key `cve_nix_run`, shared with the window; off by default) |
| `NIXDATIFIER_CVE_WHITELIST` | a vulnix whitelist file (TOML or YAML) or URL (config key `cve_whitelist`, shared with the window; empty uses `~/.config/vulnix/whitelist.toml` when it exists) |
| `NIXDATIFIER_HOSTS` | ssh targets of the other machines, `name=user@address,other=address` (config key `hosts`, shared with the window's *ssh targets of other hosts*; empty by default) |
| `NIXDATIFIER_HOST` | the host commands act on without `--host` (the interactive view keeps its choice in `NIXDATIFIER_HOST_FILE`); commands that only work on this machine ignore it |
| `NIXDATIFIER_SSH`, `NIXDATIFIER_SSH_TIMEOUT` | the ssh program (default `ssh`) and its connect timeout in seconds (default 8) |
| `NIXDATIFIER_GITHUB_USE_GH` | `on` borrows the login of a signed-in `gh` when there is no token (config key `github_use_gh`; off by default, its token often has wide scopes) |

## Several machines, one flake

A flake often defines more than one `nixosConfigurations` machine. Nixdatifier
lists them (`nixdatifier hosts`) and can look at, and change, the others over
ssh. With one machine none of this shows anywhere.

```console
$ nixdatifier hosts add server me@server.lan      # or: config set hosts server=me@server.lan
$ nixdatifier hosts
NAME    STATE    TARGET          NEXT_BOOT  BOOTED  REBOOT  BEHIND  LAST_SEEN
laptop  online                   312        312     -       0       2026-11-09 07:40
server  online   me@server.lan   88         87      yes     2       2026-11-09 07:40
nas     unmapped                                                    

$ nixdatifier --host server generations           # also diff, disk, health, status, info
$ nixdatifier --host server switch 87             # asks: Activate generation 87 on server now?
$ nixdatifier --host server rebuild               # nixos-rebuild/nh with --target-host
```

- **Discovery.** Hosts are the flake's `nixosConfigurations` (read with
  `nix eval`, cached for an hour) and what you mapped to an ssh target with
  `hosts add`. A flake host whose name already resolves needs no mapping; the
  machine named like this one is it. `hosts add` and `hosts rm` edit the `hosts`
  config key, which the window's setting shares.
- **Status.** `hosts` asks every host in parallel: `online`, `offline` (no
  answer), `unreachable` (cannot be resolved or reached), `auth` (ssh did not
  accept a key; fix it with `ssh-add` or by authorizing this machine) or
  `unmapped` (no ssh target). It also reports the next-boot and booted
  generation, whether a reboot is needed, the flake revision the host runs
  (`system.configurationRevision`) and how many commits it is behind your flake's
  HEAD, and when it was last seen: an offline host shows its last answer. JSON
  keys: `name`, `target`, `local`, `state`, `lastSeen`, `stale`, `nixosVersion`,
  `kernel`, `uptimeSeconds`, `activeGeneration`, `bootedGeneration`,
  `newestGeneration`, `generations`, `rebootRequired`, `failedUnits`, `rev`,
  `revDirty`, `localHead`, `behind` and `error`.
- **Reading.** The read helpers travel over ssh's standard input, so nothing has
  to be installed on the host (only `bash`). ssh runs in `BatchMode` with your
  keys or agent, never a password, and with a connect timeout (8 seconds), so an
  unreachable host cannot block anything. `diff --config`, `why`, store paths
  and change counts read this machine's store and stay on it.
- **Changing.** `switch`, `boot`, `rollback`, `delete`, `gc`, `clean` and
  `rebuild` ask first, name the host in the question, run the command there with
  `sudo` (or `doas`, per `--priv`; none for a `root@` target) and are recorded in
  History with the host in the label. A change needs a terminal for the sudo
  password; without one, give the host passwordless sudo.
- **Rebuild.** Without a saved `rebuild` command, `nh os MODE FLAKE --hostname
  NAME --target-host TARGET` or `nixos-rebuild MODE --flake FLAKE#NAME
  --target-host TARGET --use-remote-sudo` builds here and activates there. Your
  own `rebuild` command keeps priority, but it must say which machine: `{host}`
  (the name) and `{target}` (the ssh destination) are replaced, and the host is
  also in `NIXDATIFIER_HOST` and `NIXDATIFIER_HOST_TARGET`. A command without a
  placeholder would rebuild this machine, so it is refused for a host.
- **The window and the interactive view.** Once there is a second reachable
  host, the header shows `● this-pc ▾` (and the interactive view a *Hosts*
  entry, Alt-H). It lists every host with its state, boot state, pending reboot,
  commits behind HEAD and last seen; choosing one re-scopes Generations, Compare,
  Health and the Store card, and the confirmations name it. A host that stops
  answering keeps its last generations on screen, greyed, with when they were
  read. There are no extra tabs.

## Vulnerability scan

`nixdatifier cve` lists known vulnerabilities in the running system. It only
works when a scanner is there: [vulnix](https://github.com/nix-community/vulnix)
installed (`environment.systemPackages = [ pkgs.vulnix ];`), or `cve_nix_run on`
to run `nix run nixpkgs#vulnix`, which downloads vulnix first. Without either,
nothing changes: the window and the interactive view show nothing about CVEs.

```console
$ nixdatifier cve
nixos-system-host-26.05.20261101.9bb5222 (running system) · scanned 2026-11-08 19:26 · vulnix 1.12.4
1 critical, 1 high, 1 medium: 3 CVEs in 3 packages (1 whitelisted, --all lists them)

PACKAGE  VERSION  CVE             SCORE  SEVERITY
openssl  3.6.5    CVE-2026-00001  9.8    critical
curl     8.22.0   CVE-2026-00002  7.5    high
zstd     1.5.7    CVE-2025-00003  5.3    medium
```

- vulnix reads the runtime closure (`vulnix -C`) and matches package names and
  versions against the NVD database, so some findings may not apply. Patches
  named after a CVE count as fixed. Packages whose `.drv` files were garbage
  collected are skipped.
- The first scan downloads the NVD database into `~/.cache/vulnix`, which takes
  a few minutes. vulnix refreshes it at most every two hours.
- Results are cached for a day per closure and whitelist, and shared between
  the CLI, the interactive view and the window. `--refresh` scans again.
- Severity follows the CVSS v3 base score: critical from 9, high from 7,
  medium from 4, low below that. CVEs without a v3 score are listed as unknown
  (*no score* in the window).
- A vulnix whitelist leaves CVEs you have checked out of the counts:
  `cve_whitelist`, else `~/.config/vulnix/whitelist.toml` (or `.yaml`) when it
  exists. `--all` lists the whitelisted ones too.
- `--json` has `counts` (`critical`, `high`, `medium`, `low`, `unknown`: distinct
  CVE ids that are not whitelisted), `cves`, `whitelisted`, `affectedPackages`,
  `scannedAt`, `stale`, and `packages[]` with `name`, `pname`, `version`,
  `derivation` and `cves[]` (`id`, `score`, `severity`, `url`, `description`,
  `whitelisted`). `--plain` prints package, version, CVE, score and severity.
- Exit status 2 means a critical or high CVE was found (not whitelisted).

Once the running system was scanned, `preview INPUT` also compares the update's
packages with that scan: which CVEs the update fixes and which it introduces
(text, and `cve` in `--json`: `fixed[]` and `introduced[]` with `id`, `score`,
`severity`, `url`, `package`, `fromVersion` and `toVersion`, plus `fixedCounts`
and `introducedCounts`). The new system is not built for a preview, so its
packages are read from their `.drv` files, including the same-version rebuilds
of packages that are affected now (a backported CVE patch). Before the first
scan, `cve` is `null`, so a preview never starts the database download.

`diff --config` needs to know which config commit built each generation. `generations` and the window record it; run `nixdatifier snapshot` from a post-rebuild hook if you only rebuild from a terminal.
