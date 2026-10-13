{
  description = "Nixdatifier — NixOS generations, package diffs, flake updates and dev environments as a tray app, a KDE Plasma 6 widget and a Quickshell panel";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
      pluginId = metadata.KPlugin.Id;   # org.muddyblack.nixosGenerationExplorer
      version  = metadata.KPlugin.Version;

      # The Qt and KDE QML modules the widget imports. Tests and qmllint resolve
      # against exactly these, so they behave the same on a laptop and in CI
      # instead of depending on whatever the desktop has installed.
      qmlModules = pkgs: with pkgs; [
        qt6.qtdeclarative
        qt6.qtsvg
        kdePackages.kirigami.unwrapped
        kdePackages.plasma5support
        kdePackages.libplasma
      ];
      qmlEnv = pkgs: extra:
        let qml = pkgs.lib.makeSearchPath "lib/qt-6/qml" (qmlModules pkgs ++ extra); in
        {
          QML_IMPORT_PATH = qml;
          QML2_IMPORT_PATH = qml;
          QT_PLUGIN_PATH = pkgs.lib.makeSearchPath "lib/qt-6/plugins" [ pkgs.qt6.qtbase pkgs.qt6.qtsvg pkgs.kdePackages.plasma5support ];
        };
      # What the shell helpers call, so their tests do not borrow the host's tools.
      helperTools = pkgs: with pkgs; [ python3 bash coreutils gnugrep gnused gawk findutils util-linux jq git curl inotify-tools ];
    in
    {
      # ── installable package ────────────────────────────────────────────────
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          runtime = with pkgs; [ bash nix jq git curl coreutils util-linux findutils gnugrep gnused gawk inotify-tools libnotify polkit ];
          runtimePath = pkgs.lib.makeBinPath runtime;
          tray = pkgs.qt6.callPackage ./tray/package.nix { inherit version; };
          # The desktop-independent app: a window and a tray icon, no Plasma or
          # Quickshell needed. Works on any distribution that has Nix.
          nixdatifier = pkgs.qt6.callPackage ./standalone/package.nix {
            inherit version;
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = pkgs.lib.fileset.unions [ ./standalone ./tray ./package ];
            };
          };
        in
        {
          inherit tray nixdatifier;
          hyprland = pkgs.stdenvNoCC.mkDerivation {
            pname = "nixdatifier-hyprland";
            inherit version;
            src = ./.;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              dest="$out/share/nixdatifier"
              mkdir -p "$dest" "$out/bin"
              cp -r package hyprland shell.qml "$dest/"
              cat > "$out/bin/nixdatifier-hyprland" <<SCRIPT
              #!${pkgs.bash}/bin/bash
              set -euo pipefail
              export PATH=${runtimePath}:\$PATH
              export QT_QUICK_CONTROLS_STYLE=Fusion
              export QT_LOGGING_RULES="default.warning=false;\''${QT_LOGGING_RULES:-}"
              runtime_dir="\''${XDG_RUNTIME_DIR:-/tmp}/nixdatifier-\$USER"
              mkdir -p "\$runtime_dir"
              chmod 700 "\$runtime_dir"
              # A previous session may have died mid-operation; don't let the tray start from its state.
              rm -f "\$runtime_dir/status.json"
              ${tray}/bin/nixdatifier-tray ${pkgs.quickshell}/bin/qs "$dest" "\$runtime_dir/status.json" "$dest/package/icon-emblem.svg" &
              tray_pid=\$!
              trap 'kill "\$tray_pid" 2>/dev/null || true' EXIT
              ${pkgs.quickshell}/bin/qs --no-duplicate --path "$dest" "\$@"
              SCRIPT
              chmod +x "$out/bin/nixdatifier-hyprland"
              wrapProgram "$out/bin/nixdatifier-hyprland" \
                --prefix NIXPKGS_QT6_QML_IMPORT_PATH : "${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml"
              runHook postInstall
            '';
            meta.mainProgram = "nixdatifier-hyprland";
            meta.platforms = pkgs.lib.platforms.linux;
          };
          default = pkgs.stdenvNoCC.mkDerivation {
            pname   = "nixos-generation-explorer";
            inherit version;
            src = ./package;

            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontConfigure = true;
            dontBuild     = true;

            installPhase = ''
              runHook preInstall

              # Install plasmoid package
              plasmoid="$out/share/plasma/plasmoids/${pluginId}"
              mkdir -p "$plasmoid"
              cp -r . "$plasmoid/"
              for helper in "$plasmoid"/contents/tools/sh/*; do
                if [ -f "$helper" ] && [ -x "$helper" ]; then
                  wrapProgram "$helper" --prefix PATH : ${runtimePath}
                fi
              done

              # Register icon in hicolor theme so Plasma Widget Explorer picks it up
              mkdir -p "$out/share/icons/hicolor/256x256/apps"
              cp icon.png "$out/share/icons/hicolor/256x256/apps/${pluginId}.png"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description  = metadata.KPlugin.Description;
              longDescription = ''
                A KDE Plasma 6 widget for NixOS users. Provides a visual generation
                timeline, package diffs between generations (nix store diff-closures),
                one-click rollback/boot actions via pkexec, flake update tracking, and
                a secrets browser — all from the desktop panel.
              '';
              license   = licenses.mit;
              platforms = platforms.linux;
              homepage  = metadata.KPlugin.Website;
              maintainers = [ ];
            };
          };
        });

      # ── `nix run .#view` — preview widget with plasmoidviewer ─────────────
      apps = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          # `nix run github:Muddyblack/nixdatifier`
          default = self.apps.${system}.nixdatifier;
          nixdatifier = {
            type = "app";
            program = "${self.packages.${system}.nixdatifier}/bin/nixdatifier";
          };
          hyprland = {
            type = "app";
            program = "${self.packages.${system}.hyprland}/bin/nixdatifier-hyprland";
          };
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              export PATH=${pkgs.lib.makeBinPath [ pkgs.kdePackages.plasma-sdk ]}:"$PATH"
              # Let the wrapped viewer supply its matching Qt plugins instead
              # of inheriting a different version from the desktop session.
              unset QML2_IMPORT_PATH QML_IMPORT_PATH QT_PLUGIN_PATH QT_QPA_PLATFORM_PLUGIN_PATH NIXPKGS_QT6_QML_IMPORT_PATH
              export NIXPKGS_QT6_QML_IMPORT_PATH=${pkgs.lib.makeSearchPath "lib/qt-6/qml" (with pkgs.kdePackages; [ plasma-desktop plasma-workspace kdeclarative kitemmodels ])}
              export QT_STYLE_OVERRIDE=Fusion
              export XDG_DATA_DIRS=${pkgs.kdePackages.plasma-desktop}/share:${pkgs.kdePackages.plasma-sdk}/share:"''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
              exec plasmoidviewer \
                -a "$PWD/package" -f "''${1:-planar}"
            '');
          };
          pack = {
            type = "app";
            program = toString (pkgs.writeShellScript "pack" ''
              set -euo pipefail
              here="$PWD"
              ver="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$here/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
              name="$(basename "$here")"
              out="$here/$name-$ver.plasmoid"
              rm -f "$out"
              (cd "$here/package" && ${pkgs.zip}/bin/zip -r "$out" . -x '*.swp' '*~' 'icon-emblem.png')
              echo "wrote $out"
            '');
          };
        });

      # ── checks: `nix flake check`, and what CI runs ────────────────────────
      # `lint` is scripts/lint.sh (the same file `make lint` and CI run);
      # `tests` is tests/run.sh. Both run in the sandbox against the pinned Qt and
      # KDE modules, so a green check here means the same thing everywhere.
      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          source = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./package
              ./hyprland
              ./standalone
              ./tray
              ./shell.qml
              ./tests
              ./scripts
              ./ruff.toml
              ./.qmllint.ini
            ];
          };
          check = name: tools: extraQml: script: pkgs.runCommand "nixdatifier-${name}"
            ({ nativeBuildInputs = tools; } // qmlEnv pkgs extraQml)
            ''
              export HOME="$TMPDIR"
              cp -r ${source} source
              chmod -R u+w source
              cd source
              ${script}
              touch "$out"
            '';
        in
        {
          lint = check "lint"
            (with pkgs; [ qt6.qtdeclarative ruff shellcheck python3 findutils coreutils diffutils bash ])
            [ pkgs.quickshell ]
            "bash scripts/lint.sh";
          tests = check "tests"
            ([ pkgs.qt6.qtdeclarative ] ++ helperTools pkgs)
            [ ]
            "bash tests/run.sh";
        });

      # ── development shell ──────────────────────────────────────────────────
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in
        {
          default = pkgs.mkShell ({
            name = "nixos-generation-explorer-dev";
            packages = with pkgs; [
              qt6.qtdeclarative      # qmllint, qmlformat, qmltestrunner
              kdePackages.kpackage   # kpackagetool6
              kdePackages.plasma-sdk # plasmoidviewer
              quickshell
              qt6.qtbase
              qt6.qtsvg
              cmake
              pre-commit
              zip                    # needed by pack.sh
              ruff                   # Python lint and format
              shellcheck             # shell helper lint
            ] ++ helperTools pkgs;
            shellHook = ''
              pre-commit install -f --install-hooks
              echo "nixos-generation-explorer dev shell ready"
              echo "  make help        — list targets (view, install, pack, test, lint, tag)"
            '';
          } // qmlEnv pkgs [ pkgs.quickshell ]);
        });

      # ── integration for NixOS and Home Manager users ──────────────────────
      overlays.default = final: prev: {
        nixdatifier = self.packages.${final.stdenv.hostPlatform.system}.nixdatifier;
      };
      nixosModules.default = import ./nix/nixos-module.nix self;
      homeManagerModules.default = import ./nix/home-manager-module.nix self;

      # ── formatter (nixpkgs-fmt via nix fmt) ───────────────────────────────
      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
