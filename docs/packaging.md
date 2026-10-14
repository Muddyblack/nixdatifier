# Packaging for nixpkgs

`nix/nixpkgs/` holds two packages written the way nixpkgs wants them (they fetch a tagged release instead of building the working tree), laid out like `pkgs/by-name`:

| File | Attribute | What |
| --- | --- | --- |
| `nixdatifier/package.nix` | `nixdatifier` | the window, tray icon and command line (Qt) |
| `nixdatifier-cli/package.nix` | `nixdatifier-cli` | the command line and terminal view, no Qt |

`nix-build nix/nixpkgs -A nixdatifier-cli` builds one from the release its `version` names. CI bumps `version` and `hash` on every tag but does not commit them back (the hash only exists once the tag does), so the copies here can trail the latest release.

## What `make tag` does for you

1. `make tag` bumps `package/metadata.json`, commits, tags `vX.Y.Z` and pushes.
2. The **Release** workflow builds the `.plasmoid` and creates the GitHub release.
3. The **nixpkgs** workflow bumps `version` and `hash` in `nix/nixpkgs` with `nix-update`, builds both packages against the flake's pinned nixpkgs, and uploads the result as an artifact. A failing build means the release is not packageable; fix it before the next tag.

## Once, by hand (the first submission)

1. Fork `NixOS/nixpkgs`. Add yourself to `maintainers/maintainer-list.nix` (alphabetical, in its own commit `maintainers: add muddyblack`), then set `maintainers = [ lib.maintainers.muddyblack ];` in both package files. Only in the fork: here `lib.maintainers.muddyblack` does not exist yet, so the files in this repository keep `maintainers = [ ];`.

   ```nix
   muddyblack = {
     github = "Muddyblack";
     githubId = 70057554;
     name = "Muddyblack";
   };
   ```
2. Copy both `package.nix` files (taken from the workflow's `nixpkgs-packages` artifact, which already has the new version and hash) to `pkgs/by-name/ni/nixdatifier/` and `pkgs/by-name/ni/nixdatifier-cli/`.
3. Check in the fork: `nix-build -A nixdatifier -A nixdatifier-cli`, `nixfmt` the files, and run `nixpkgs-review wip`. Test the window on a real session once.
4. Open one pull request per package, titled `nixdatifier: init at X.Y.Z` and `nixdatifier-cli: init at X.Y.Z`, using the nixpkgs PR template. Reviewers may ask for changes (usually `meta`, wrapping, or dropping the install check).

Expect review rounds the first time. Nixpkgs rules that matter here: sources come from a tag, builds must work in the sandbox without network, and the install check must be quick.

## After it is merged: nothing

The nixpkgs bot (r-ryantm) notices a new tag, runs the packages' `passthru.updateScript` (`nix-update`), builds, and opens the version-bump pull request. A maintainer (you) only approves. At that point the in-repo copies are no longer needed for releases, though they stay useful for building a release locally.

## Notes

- Both packages install `bin/nixdatifier`; the command-line one has `priority = 10`, so installing both does not conflict.
- The Plasma widget (`.plasmoid`) and the Quickshell/Hyprland popup are not in these packages. The widget comes from the KDE Store or the GitHub release; the flake in this repository still builds everything.
- The flake and Home Manager/NixOS modules keep building from the working tree; `nix/nixpkgs/` is only for nixpkgs.
