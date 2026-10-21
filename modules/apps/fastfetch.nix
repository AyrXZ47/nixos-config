{ config, pkgs, lib, ... }:

let
  terminalLogo = ../../assets/Terminal/nixTeminal.png;
  cfg = config.modules.apps.fastfetch;
  # El celular (nix-on-droid) no soporta el protocolo kitty de la app de
  # Termux, asi que ahi se usa el logo ascii original de nixos. La pc sigue
  # con el PNG. fastfetch no admite padding negativo, asi que el espacio que
  # queda entre logo y valores se reduce acortando la columna de claves.
  # "kitty-direct", NO "kitty": con fastfetch 2.70 el tipo "kitty" no emite
  # ni un escape del protocolo (el PNG no se dibuja, y salen bloques ANSI
  # identicos sea cual sea la imagen); "kitty-direct" manda a=T,f=100,t=f con
  # la ruta y kitty la abre. Verificado comparando la salida de ambos.
  logoJson = if cfg.asciiLogo then ''
    {
      "type": "builtin",
      "source": "nixos",
      "padding": { "top": 2, "left": 0 }
    }
  '' else ''
    {
      "type": "kitty-direct",
      "source": "${terminalLogo}",
      "width": 40,
      "padding": { "top": 2, "left": 4 }
    }
  '';
  # Ancho de la columna de claves: en ascii (celular) se compacta para acercar
  # los valores al logo; el resto conserva el ancho original.
  keyCol = if cfg.asciiLogo then 10 else 24;
  key = name: "  " + name + lib.concatStrings (lib.replicate (keyCol - 2 - builtins.stringLength name) " ");
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
    # Wrapper en vez del binario pelado: elige un logo AL AZAR en cada
    # invocacion de ~/Pictures/Fastfetch (mismo patron que los wallpapers: la
    # media vive en ~/Pictures, no en el store ni en git). Si el directorio no
    # existe o esta vacio, cae al PNG de siempre via config.jsonc.
    # Se instala SOLO el wrapper: referencia el store path del paquete real, sin
    # colisionar con su bin/fastfetch en el perfil.
    home.packages = [
      (pkgs.writeShellScriptBin "fastfetch" ''
        dir="$HOME/Pictures/Fastfetch"
        logo=""
        if [ -d "$dir" ]; then
          logo="$(find "$dir" -maxdepth 1 -type f \
                    \( -iname '*.gif' -o -iname '*.png' -o -iname '*.jpg' \
                       -o -iname '*.jpeg' -o -iname '*.webp' \) \
                    -print0 2>/dev/null | shuf -z -n 1 | tr -d '\0')"
        fi
        if [ -n "$logo" ]; then
          exec ${pkgs.fastfetch}/bin/fastfetch --logo-type kitty-direct --logo "$logo" "$@"
        fi
        exec ${pkgs.fastfetch}/bin/fastfetch "$@"
      '')
    ];

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
          { "type": "os",       "key": "${key "OS"}",        "keyColor": "magenta" },
          { "type": "host",     "key": "${key "Host"}",      "keyColor": "magenta" },
          { "type": "kernel",   "key": "${key "Kernel"}",    "keyColor": "magenta" },
          { "type": "uptime",   "key": "${key "Uptime"}",    "keyColor": "magenta" },
          { "type": "shell",    "key": "${key "Shell"}",     "keyColor": "magenta" },
          { "type": "display",  "key": "${key "Display"}",   "keyColor": "magenta" },
          { "type": "de",       "key": "${key "DE"}",        "keyColor": "magenta" },
          { "type": "wm",       "key": "${key "WM"}",        "keyColor": "magenta" },
          { "type": "terminal", "key": "${key "Terminal"}",  "keyColor": "magenta" },
          { "type": "cpu",      "key": "${key "CPU"}",       "keyColor": "magenta" },
          { "type": "gpu",      "key": "${key "GPU"}",       "keyColor": "magenta" },
          { "type": "memory",   "key": "${key "Memory"}",    "keyColor": "magenta" },
          { "type": "swap",     "key": "${key "Swap"}",      "keyColor": "magenta" },
          "break",
          "break",
          { "type": "custom", "format": "╰{$1}╯" },
          { "type": "colors", "paddingLeft": 31, "symbol": "circle" }
        ]
      }
    '';
  };
}
