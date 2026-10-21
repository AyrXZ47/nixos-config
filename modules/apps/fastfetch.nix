{ config, pkgs, lib, hostName, ... }:

let
  terminalLogo = ../../assets/Terminal/nixTeminal.png;
  # Logos animados: viven en el repo, estandarizados con ffmpeg+gifsicle
  # (caja 400x400, <=12 fps, <=4.5 s, paleta 96). 17 MB de originales -> 5.3 MB.
  # Para sumar uno: dejarlo en assets/Fastfetch/ y rebuildear. Nada mas.
  logoDir = ../../assets/Fastfetch;

  # ── Caja simetrica en TODOS los hosts ────────────────────────────────────
  # El titulo lleva {user-name}@{host-name}: "yovick@nixos-pc" mide 15 y
  # "yovick@nixos-laptop" 19, asi que con guiones fijos el borde de arriba
  # nunca mide lo mismo que el de abajo (ni entre hosts). Se calcula en build
  # time con el hostname real, que llega por extraSpecialArgs desde flake.nix.
  # 🔥 y 🚀 ocupan 2 columnas cada uno en el terminal.
  boxW = 80;                                   # ancho total de la caja
  userName = config.home.username;
  # "[ 🔥 user@host 🔥 ]" = 2 + 2 + 1 + len + 1 + 2 + 2
  titleLen = 10 + builtins.stringLength "${userName}@${hostName}";
  sideTotal = boxW - 2 - titleLen;
  sideL = sideTotal / 2;                       # Nix / es division entera
  sideR = sideTotal - sideL;
  dashes = n: lib.concatStrings (lib.replicate n "─");
  # borde inferior: "( 🚀 )" mide 6 columnas
  botTotal = boxW - 2 - 6;
  botL = botTotal / 2;
  botR = botTotal - botL;
  dotsW = 15;                                  # "● ● ● ● ● ● ● ●"
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
      "type": "kitty-icat",
      "source": "${terminalLogo}",
      "width": 40,
      "height": 18,
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
    # invocacion, entre los GIFs versionados en assets/Fastfetch/ (repo, no
    # ~/Pictures: asi lo gestiona Nix y llega igual a todos los hosts).
    # Si el directorio quedara sin archivos, cae al PNG de config.jsonc.
    #
    # "kitty-icat", NO "kitty-direct": fastfetch 2.70 manda SIEMPRE f=100 (que
    # en el protocolo de kitty significa "datos PNG") apuntando al archivo. Con
    # un GIF eso es mentira y kitty no lo decodifica -> logo vacio. kitty-icat
    # delega en `kitten icat`, que abre el archivo con el cargador propio de
    # kitty y sí anima GIF/APNG/WebP.
    # Se instala SOLO el wrapper: referencia el store path del paquete real, sin
    # colisionar con su bin/fastfetch en el perfil.
    home.packages = [
      (pkgs.writeShellScriptBin "fastfetch" ''
        logo="$(${pkgs.findutils}/bin/find ${logoDir} -maxdepth 1 -type f \
                  \( -iname '*.gif' -o -iname '*.png' -o -iname '*.webp' \) \
                  -print0 2>/dev/null | ${pkgs.coreutils}/bin/shuf -z -n 1 | ${pkgs.coreutils}/bin/tr -d '\0')"
        if [ -n "$logo" ]; then
          exec ${pkgs.fastfetch}/bin/fastfetch --logo-type kitty-icat --logo "$logo" \
            --logo-width 40 --logo-height 18 --logo-preserve-aspect-ratio true "$@"
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
            "${dashes botL}( 🚀 )${dashes botR}"
          ]
        },
        "logo": ${logoJson},
        "modules": [
          {
            "type": "title",
            "format": "╭${dashes sideL}[ 🔥 {user-name-colored}@{host-name-colored} 🔥 ]${dashes sideR}╮"
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
{ "type": "colors", "paddingLeft": ${toString (boxW - dotsW)}, "symbol": "circle" }
        ]
      }
    '';
  };
}
