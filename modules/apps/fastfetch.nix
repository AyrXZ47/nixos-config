{ config, pkgs, lib, ... }:

{
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
      "logo": {
        "type": "small"
      },
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
}
