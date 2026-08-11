{ config, pkgs, lib, ... }:

let
  terminalLogo = ../../assets/Terminal/nixTeminal.png;
  cfg = config.modules.apps.fastfetch;
  # El celular (nix-on-droid) no soporta el protocolo kitty de la app de
  # Termux, asi que ahi se usa el logo ascii integrado de nixos. La pc sigue
  # con el PNG.
  logoJson = if cfg.asciiLogo then ''
    {
      "type": "builtin",
      "source": "nixos",
      "width": 40,
      "padding": { "top": 2, "left": 4 }
    }
  '' else ''
    {
      "type": "kitty",
      "source": "${terminalLogo}",
      "width": 40,
      "padding": { "top": 2, "left": 4 }
    }
  '';
in

{
  options.modules.apps.fastfetch = {
    asciiLogo = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Logo ascii de nixos en vez del PNG (protocolo kitty), para nix-on-droid";
    };
  };

  config = {
    home.packages = with pkgs; [ fastfetch ];

    xdg.configFile."fastfetch/config.jsonc".text = ''
      {
        "$schema": "https://github.com/fastfetch/fastfetch/raw/dev/doc/config.schema.json",
        "display": {
          "separator": "=>>     ",
          "key": {
            "type": "both"
          },
          "constants": [
            "───────────────────────────────────( 🚀 )────────────────────────────────────"
          ]
        },
        "logo": ${logoJson},
        "modules": [
          {
            "type": "title",
            "format": "╭─────────────────────────────[ 🔥 {user-name-colored}@{host-name-colored} 🔥 ]─────────────────────────────╮"
          },
          "break",
          "break",
          { "type": "os",       "key": "  OS                    ",  "keyColor": "magenta" },
          { "type": "host",     "key": "  Host                  ",  "keyColor": "magenta" },
          { "type": "kernel",   "key": "  Kernel                ",  "keyColor": "magenta" },
          { "type": "uptime",   "key": "  Uptime                ",  "keyColor": "magenta" },
          { "type": "packages", "key": "  Packages              ",  "keyColor": "magenta" },
          { "type": "shell",    "key": "  Shell                 ",  "keyColor": "magenta" },
          { "type": "display",  "key": "  Display               ",  "keyColor": "magenta" },
          { "type": "de",       "key": "  DE                    ",  "keyColor": "magenta" },
          { "type": "wm",       "key": "  WM                    ",  "keyColor": "magenta" },
          { "type": "terminal", "key": "  Terminal              ",  "keyColor": "magenta" },
          { "type": "cpu",      "key": "  CPU                   ",  "keyColor": "magenta" },
          { "type": "gpu",      "key": "  GPU                   ",  "keyColor": "magenta" },
          { "type": "memory",   "key": "  Memory                ",  "keyColor": "magenta" },
          { "type": "swap",     "key": "  Swap                  ",  "keyColor": "magenta" },
          "break",
          "break",
          { "type": "custom", "format": "╰{$1}╯" },
          { "type": "colors", "paddingLeft": 31, "symbol": "circle" }
        ]
      }
    '';
  };
}
