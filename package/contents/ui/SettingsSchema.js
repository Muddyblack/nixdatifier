.pragma library

var fields = [
  {
    "key": "flakePath",
    "tab": "General",
    "group": "NixOS & Flake",
    "label": "System flake path",
    "help": "Leave empty to detect /etc/nixos, ~/nixos-config, or ~/.config/nixos.",
    "type": "String"
  },
  {
    "key": "configRepoPath",
    "tab": "General",
    "group": "NixOS & Flake",
    "label": "Configuration Git repository",
    "help": "Leave empty to use the flake path. Records the configuration revision for each generation.",
    "type": "String"
  },
  {
    "key": "checkInterval",
    "tab": "General",
    "group": "NixOS & Flake",
    "label": "Check updates every (seconds)",
    "help": "",
    "type": "Int",
    "min": 60,
    "max": 86400
  },
  {
    "key": "maxGenerations",
    "tab": "General",
    "group": "NixOS & Flake",
    "label": "Maximum generations shown",
    "help": "",
    "type": "Int",
    "min": 3,
    "max": 200
  },
  {
    "key": "defaultView",
    "tab": "General",
    "group": "Default view",
    "label": "Open on",
    "help": "",
    "type": "String",
    "choices": [
      {
        "value": "timeline",
        "label": "Generations"
      },
      {
        "value": "updates",
        "label": "Updates"
      },
      {
        "value": "diff",
        "label": "Compare"
      },
      {
        "value": "tools",
        "label": "Tools"
      },
      {
        "value": "devenv",
        "label": "Dev environments"
      },
      {
        "value": "health",
        "label": "System health"
      },
      {
        "value": "secrets",
        "label": "Secrets"
      },
      {
        "value": "hash",
        "label": "Hash calculator"
      },
      {
        "value": "history",
        "label": "Rebuild history"
      },
      {
        "value": "storeusage",
        "label": "Store usage"
      }
    ]
  },
  {
    "key": "enableHostDetect",
    "tab": "General",
    "group": "NixOS & Flake",
    "label": "Detect hostname and flake configuration",
    "help": "When disabled, previews require a flake with exactly one NixOS configuration.",
    "type": "Bool"
  },
  {
    "key": "customCommands",
    "tab": "Commands",
    "group": "Quick-run commands",
    "label": "Commands",
    "help": "Up to four commands, run from your flake directory in a terminal.",
    "type": "String"
  },
  {
    "key": "showCommandButtons",
    "tab": "Commands",
    "group": "Quick-run commands",
    "label": "Show Commands button in the footer",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "commandTerminal",
    "tab": "Commands",
    "group": "Terminal & cleanup",
    "label": "Terminal emulator",
    "help": "Leave empty to detect the desktop default. Supports konsole, kitty, foot, alacritty, wezterm, ghostty, and xterm.",
    "type": "String"
  },
  {
    "key": "usePkexec",
    "tab": "Behavior",
    "group": "Permissions",
    "label": "Use pkexec for privileged operations",
    "help": "Use the system polkit authentication dialog.",
    "type": "Bool"
  },
  {
    "key": "enableLiveSwitch",
    "tab": "Behavior",
    "group": "Generation actions",
    "label": "Enable Activate now",
    "help": "Switch the running system without rebooting.",
    "type": "Bool"
  },
  {
    "key": "confirmBeforeRollback",
    "tab": "Behavior",
    "group": "Generation actions",
    "label": "Confirm before switching generation",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "confirmBeforeDelete",
    "tab": "Behavior",
    "group": "Generation actions",
    "label": "Confirm before deleting generation",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "showDeleteButton",
    "tab": "Behavior",
    "group": "Generation actions",
    "label": "Show delete generation action",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "showNotifications",
    "tab": "Behavior",
    "group": "Updates & detection",
    "label": "Show update notifications",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "autoRefreshOnOpen",
    "tab": "Behavior",
    "group": "Updates & detection",
    "label": "Refresh generations when the popup opens",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "showFlakeSection",
    "tab": "Behavior",
    "group": "Updates & detection",
    "label": "Check flake inputs in the background",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "secretsPath",
    "tab": "Behavior",
    "group": "Secrets",
    "label": "Deployed secrets directory",
    "help": "Leave empty to detect the deployed agenix or sops-nix secrets.",
    "type": "String"
  },
  {
    "key": "secretsSourcePath",
    "tab": "Behavior",
    "group": "Secrets",
    "label": "Encrypted source secrets path",
    "help": "Leave empty to detect the source in the flake directory.",
    "type": "String"
  },
  {
    "key": "impermanencePaths",
    "tab": "Behavior",
    "group": "Impermanence",
    "label": "Extra persistent folders",
    "help": "Colon-separated, e.g. /persist:/mnt/data. Leave empty to detect them from the mounts.",
    "type": "String"
  },
  {
    "key": "impermanenceStaleDays",
    "tab": "Behavior",
    "group": "Impermanence",
    "label": "Offer cleanup for folders untouched for (days)",
    "help": "",
    "type": "Int",
    "min": 14,
    "max": 3650
  },
  {
    "key": "diffFilterEnabled",
    "tab": "Behavior",
    "group": "Package changes",
    "label": "Show package search/filter",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "timelineColor",
    "tab": "Design",
    "group": "Colors",
    "label": "Timeline color",
    "help": "",
    "type": "Color"
  },
  {
    "key": "accentColor",
    "tab": "Design",
    "group": "Colors",
    "label": "Accent color",
    "help": "",
    "type": "Color"
  },
  {
    "key": "fontScale",
    "tab": "Design",
    "group": "Typography",
    "label": "Font scale",
    "help": "",
    "type": "Double",
    "min": 0.7,
    "max": 2
  },
  {
    "key": "showBg",
    "tab": "Design",
    "group": "Background",
    "label": "Show glass background",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "bgColor",
    "tab": "Design",
    "group": "Background",
    "label": "Background color",
    "help": "Accepts #RRGGBB or #AARRGGBB; the first pair controls opacity.",
    "type": "String"
  },
  {
    "key": "bgRadius",
    "tab": "Design",
    "group": "Background",
    "label": "Corner radius",
    "help": "",
    "type": "Double",
    "min": 0,
    "max": 32
  },
  {
    "key": "useSystemTextColor",
    "tab": "Design",
    "group": "Colors",
    "label": "Use system text color",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "customTextColor",
    "tab": "Design",
    "group": "Colors",
    "label": "Custom text color",
    "help": "",
    "type": "Color"
  },
  {
    "key": "enableGlow",
    "tab": "Design",
    "group": "Effects",
    "label": "Glow on timeline markers",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "iconStyle",
    "tab": "Design",
    "group": "Panel",
    "label": "Icon colors",
    "help": "",
    "type": "String",
    "choices": [
      {
        "value": "colored",
        "label": "Original colored flake"
      },
      {
        "value": "white",
        "label": "White"
      },
      {
        "value": "black",
        "label": "Black"
      },
      {
        "value": "accent",
        "label": "Accent color"
      }
    ]
  },
  {
    "key": "diffViewMode",
    "tab": "Behavior",
    "group": "Package changes",
    "label": "Package detail mode",
    "help": "",
    "type": "String",
    "choices": [
      {
        "value": "compact",
        "label": "Compact"
      },
      {
        "value": "detailed",
        "label": "Expanded details"
      }
    ]
  },
  {
    "key": "showPackageIcons",
    "tab": "Behavior",
    "group": "Package changes",
    "label": "Show application icons",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "compactStyle",
    "tab": "Design",
    "group": "Panel",
    "label": "Compact representation",
    "help": "",
    "type": "String",
    "choices": [
      {
        "value": "icon",
        "label": "Icon"
      },
      {
        "value": "number",
        "label": "Generation number"
      },
      {
        "value": "both",
        "label": "Icon and generation"
      },
      {
        "value": "pill",
        "label": "Pill"
      }
    ]
  },
  {
    "key": "compactShowBadge",
    "tab": "Design",
    "group": "Panel",
    "label": "Show pending update badge",
    "help": "",
    "type": "Bool"
  },
  {
    "key": "compactAnimateIcon",
    "tab": "Design",
    "group": "Panel",
    "label": "Animate panel icon while working",
    "help": "Turn off if the spinning icon interferes with your panel or tray.",
    "type": "Bool"
  },
  {
    "key": "popupWidth",
    "tab": "Design",
    "group": "Popup size",
    "label": "Width",
    "help": "",
    "type": "Int",
    "min": 380,
    "max": 1400
  },
  {
    "key": "popupHeight",
    "tab": "Design",
    "group": "Popup size",
    "label": "Height",
    "help": "",
    "type": "Int",
    "min": 420,
    "max": 1400
  },
  {
    "key": "gcCustomCommand",
    "tab": "Commands",
    "group": "Terminal & cleanup",
    "label": "Custom cleanup command",
    "help": "Adds an option to the cleanup menu.",
    "type": "String"
  },
  {
    "key": "enableMotion",
    "tab": "Design",
    "group": "Effects",
    "label": "Animate the flake and traveling marker",
    "help": "Turn off for reduced motion. Hidden views never animate.",
    "type": "Bool"
  }
];
