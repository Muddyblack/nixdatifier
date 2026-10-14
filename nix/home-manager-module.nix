self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.nixdatifier;
in
{
  options.programs.nixdatifier = {
    enable = lib.mkEnableOption "Nixdatifier, a tray app for Nix generations, flake updates and dev environments";

    ui = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install the tray app and window. Set to false for the command line only:
        no Qt is built or downloaded, and nothing starts at login.
      '';
    };

    tui = {
      commands = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            label = lib.mkOption { type = lib.types.str; description = "Name shown in the Commands panel and used by `nixdatifier run LABEL`."; };
            cmd = lib.mkOption { type = lib.types.str; description = "The shell command, run from the flake directory as typed."; };
          };
        });
        default = [ ];
        example = lib.literalExpression ''[ { label = "rebuild"; cmd = "sudo nixos-rebuild switch --flake .#myhost"; } ]'';
        description = ''
          Quick-run commands (at most four), shared by the window and the terminal view. The one labelled
          "rebuild" is what `nixdatifier rebuild` runs. When set, they come from the environment and win over
          the ones saved from the window or the terminal view.
        '';
      };
      updateCheck = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Check the flake inputs for updates in the background and send a desktop notification when there are new ones. Works without the window; the terminal view can switch it on and off too (nixdatifier watch).";
        };
        interval = lib.mkOption {
          type = lib.types.strMatching "[1-9][0-9]*[mhd]";
          default = "6h";
          description = "How often to check: minutes, hours or days, like 30m, 6h, 1d.";
        };
      };
      theme = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Starting colour theme of the terminal view: deep (default), midnight, marina, full, plain, or the name of one of your own (see tui.themes). Alt-C in the view changes and remembers it.";
      };
      themes = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        example = lib.literalExpression ''{ mine = { accent = "#ff8800"; bg = "#101010"; }; }'';
        description = "Your own colour themes for the terminal view, by name. Keys: accent label text muted border select match pointer ok bad warn bg (empty bg keeps the terminal's), each as #rrggbb; keys left out come from deep. They show up when cycling with Alt-C.";
      };
      layout = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "compact" "roomy" ]);
        default = null;
        description = "Starting layout of the terminal view: roomy (default, boxed sections and logo) or compact (no boxes). Alt-L in the view changes and remembers it.";
      };
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.${if cfg.ui then "nixdatifier" else "cli"};
      defaultText = lib.literalExpression "inputs.nixdatifier.packages.\${system}.nixdatifier (or .cli when ui = false)";
      description = "The Nixdatifier package to install.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Nixdatifier in the tray when you log in.";
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."nixdatifier/themes" = lib.mkIf (cfg.tui.themes != { }) {
      source = pkgs.linkFarm "nixdatifier-themes" (lib.mapAttrsToList (name: colours: {
        name = "${name}.theme";
        path = pkgs.writeText "${name}.theme" (lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") colours) + "\n");
      }) cfg.tui.themes);
    };
    home.sessionVariables = lib.optionalAttrs (cfg.tui.theme != null) { NIXDATIFIER_THEME = cfg.tui.theme; }
      // lib.optionalAttrs (cfg.tui.layout != null) { NIXDATIFIER_LAYOUT = cfg.tui.layout; }
      // lib.optionalAttrs (cfg.tui.commands != [ ]) { NIXDATIFIER_COMMANDS = builtins.toJSON cfg.tui.commands; };

    systemd.user.services.nixdatifier-check = lib.mkIf cfg.tui.updateCheck.enable {
      Unit.Description = "Nixdatifier: check flake inputs for updates";
      Service = {
        Type = "oneshot";
        ExecStart = "${cfg.package}/bin/nixdatifier watch run";
        Environment = [ "PATH=${lib.makeBinPath [ pkgs.libnotify ]}:/run/current-system/sw/bin" ];
      };
    };
    systemd.user.timers.nixdatifier-check = lib.mkIf cfg.tui.updateCheck.enable {
      Unit.Description = "Nixdatifier: periodic update check";
      Timer = {
        OnBootSec = "5m";
        OnUnitActiveSec = cfg.tui.updateCheck.interval;
        RandomizedDelaySec = "2m";
      };
      Install.WantedBy = [ "timers.target" ];
    };
    home.packages = [ cfg.package ];

    xdg.configFile."autostart/nixdatifier.desktop" = lib.mkIf (cfg.ui && cfg.autostart) {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=Nixdatifier
        Exec=${cfg.package}/bin/nixdatifier --background
        Icon=nixdatifier
        X-GNOME-Autostart-enabled=true
      '';
    };
  };
}
