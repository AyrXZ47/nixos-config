{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.hyprland;

  # Lanzador de GUIs "no intrusivas": abre la app en un workspace NUEVO
  # consecutivo (max en uso + 1) sin robar el foco ni tocar el workspace
  # actual. Motivacion: las GUIs que lanza el agente opencode (gtkwave,
  # matplotlib, logisim) nacian EN el workspace activo y su terminal se
  # redimensionaba -> opencode se rompe (bug documentado). El workspace es
  # dinamico (si hay 3 en uso abre el 4; si hay 10, el 11). Mecanica:
  # snapshot de clientes hyprctl, lanza la app desasociada (setsid), espera
  # la primera ventana nueva (hasta 10s: una JVM tarda) y la mueve con
  # movetoworkspacesilent (no cambia la vista).
  # ponytail: si la app abre MULTIPLES ventanas solo se mueve la primera; si
  # eso pasa con gtkwave/matplotlib, cambiar a windowrule por class.
  guirun = pkgs.writeShellScriptBin "guirun" ''
    set -euo pipefail
    # fuera de Hyprland (tty/ssh): lanzar normal
    command -v hyprctl >/dev/null 2>&1 || exec "$@"

    snap() {
      hyprctl -j clients 2>/dev/null | ${pkgs.python3}/bin/python3 -c '
import json, sys
try:
    print("\n".join(w["address"] for w in json.load(sys.stdin)))
except Exception:
    pass' | sort
    }
    nextws() {
      hyprctl -j workspaces 2>/dev/null | ${pkgs.python3}/bin/python3 -c '
import json, sys
try:
    ids = [w["id"] for w in json.load(sys.stdin) if w["id"] > 0]
    print((max(ids) + 1) if ids else 1)
except Exception:
    print(1)'
    }

    before=$(snap)
    setsid "$@" >/dev/null 2>&1 &
    for _ in $(seq 1 100); do
      sleep 0.1
      new=$(comm -13 <(printf '%s\n' "$before") <(snap) | head -1)
      if [ -n "''${new:-}" ]; then
        hyprctl dispatch movetoworkspacesilent "$(nextws),address:$new" >/dev/null
        exit 0
      fi
    done
    echo "guirun: sin ventana nueva tras 10s (no es una app GUI?)" >&2
  '';
in
{
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.yovick = {
      imports = [ ./hyprland-home.nix ];
      gtk = {
        enable = true;
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        # Cursor por gsettings: GTK y el platform theme gtk3 de Qt (QT_QPA_...
        # = gtk3, ver abajo) leen gtk-cursor-theme-name, NO el XCURSOR_THEME de
        # entorno. Sin esto apps Qt como KeepassXC se quedan con el cursor de
        # fábrica aunque XCURSOR_THEME diga Bibata-Material-Deep-Blue. Es el
        # mismo paquete que theme-base.nix usa en home.pointerCursor.
        cursorTheme = {
          name = "Bibata-Material-Deep-Blue";
          package = pkgs.bibata-material-deep-blue;
          size = 30;
        };
        gtk3.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
      };
      qt = {
        enable = true;
        platformTheme.name = "gtk3";
        style = {
          name = "adwaita-dark";
          package = pkgs.adwaita-qt;
        };
      };
      xdg.configFile."kdeglobals" = {
        text = ''
          [KDE]
          ColorScheme=BreezeDark
          widgetStyle=Breeze
          [General]
          colorScheme=BreezeDark
        '';
      };
      home.sessionVariables = {
        GTK_THEME = "Adwaita:dark";
        QT_QPA_PLATFORMTHEME = "gtk3";
        # Hyprland, no KDE: XDG_CURRENT_DESKTOP=KDE hace que xdg-open use kfmclient
        # (no instalado) y nunca abra el navegador (rompía gh auth login).
        XDG_CURRENT_DESKTOP = "Hyprland";
      };
      xdg.configFile."wayle/config.toml".text = ''
        [bar]
        # Valores tuneados en vivo en pc (wayle los persiste en runtime.toml,
        # que es per-host y no se comparte): horneados aquí para que TODOS los
        # hosts rendericen la barra igual. Editar aquí, no en runtime.toml.
        location = "right"
        exclusive = true
        layer = "top"
        rounding = "none"
        scale = 0.85
        inset-edge = 0.0
        inset-ends = 0.7
        module-gap = 0.5
        padding = 0.3
        padding-ends = 0.0
        bg = "transparent"
        border-location = "none"
        border-width = 0
        shadow = "none"

        button-variant = "block-prefix"
        button-rounding = "full"
        button-icon-size = 1.0
        button-icon-padding = 1.0
        button-label-size = 1.35
        button-label-weight = "bold"
        button-label-padding = 0.25
        button-gap = 0.5
        button-bg-opacity = 66
        button-opacity = 100
        button-border-location = "none"
        button-border-width = 0
        button-group-module-gap = 0.0
        button-group-padding = 0.75
        button-group-rounding = "full"
        button-group-background = "bg-elevated"
        button-group-opacity = 100
        button-group-border-location = "all"
        button-group-border-width = 2
        button-group-border-color = "status-info"

        dropdown-shadow = true
        dropdown-opacity = 88
        dropdown-autohide = true
        dropdown-freeze-label = true

        [[bar.layout]]
        monitor = "*"
        show = true
        left = [
          { name = "top", modules = ["notifications", "clock"] },
          { name = "cava", modules = ["cava"] },
        ]
        center = ["hyprland-workspaces"]
        right = [
          { name = "system", modules = [
            "custom-picker",
            "custom-wallpaper",
            "custom-clipboard",
          ] },
          { name = "bottom", modules = [
            "volume",
            "brightness",
            "battery",
            "bluetooth",
            "network",
            "dashboard",
          ] },
        ]

        [styling]
        scale = 1.1
        rounding = "lg"
        theme-provider = "wayle"
        theming-monitor = ""

        [styling.palette]
        bg = "#0a0a12"
        surface = "#141428"
        elevated = "#1e1e3a"
        fg = "#d4d4f0"
        fg-muted = "#8888aa"
        primary = "#ff0066"
        red = "#ff0040"
        yellow = "#ffcc00"
        green = "#00ff88"
        blue = "#00aaff"

        # --- Modules ---

        [modules.clock]
        format = "%I\n%M"
        icon-show = false
        label-show = true
        label-color = "#ff0066"
        label-max-length = 0
        left-click = "dropdown:calendar"
        button-bg-color = "transparent"

        [modules.idle-inhibit]
        icon-inactive = "ld-bell-symbolic"
        icon-active = "ld-bell-off-symbolic"
        format = "{{ state }}"
        icon-show = true
        label-show = false
        left-click = "wayle idle toggle --indefinite"
        button-bg-color = "bg-elevated"

        [modules.hyprland-workspaces]
        display-mode = "label"
        label-use-name = false
        numbering = "absolute"
        app-icons-show = true
        app-icons-dedupe = true
        app-icons-empty = "tb-minus-symbolic"
        active-indicator = "background"
        min-workspace-count = 5
        container-bg-color = "#000000"
        active-color = "#ff0066"
        occupied-color = "#8888aa"
        empty-color = "#2a2a44"
        workspace-padding = 0.3
        icon-size = 1.0
        label-size = 0.85
        icon-gap = 0.2
        # Ventanas de hyprdev (clase hyprdev-<app>-<runid>): sin mapeo, wayle
        # intuye la app por substrings del class (nvim→Neovim, opencode→VSCode,
        # resto→fallbacks aleatorios). Todas son wezterm: un solo glob basta.
        app-icon-map = { "*hyprdev*" = "si-wezterm-symbolic" }

        [modules.notifications]
        icon-show = true
        label-show = false
        icon-inactive = "preferences-system-notifications-symbolic"
        icon-active = "notifications-disabled-symbolic"
        left-click = "dropdown:notification"
        right-click = "wayle notify dnd"
        popup-position = "bottom-right"
        popup-max-visible = 5
        popup-duration = 5000
        popup-hover-pause = true
        popup-margin-x = 12
        popup-margin-y = 12
        popup-gap = 8
        popup-shadow = true
        popup-urgency-bar = "low"
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "bg-elevated"
        button-bg-color = "bg-elevated"

        [modules.brightness]
        level-icons = ["ld-sun-dim-symbolic", "ld-sun-medium-symbolic", "ld-sun-symbolic"]
        icon-show = true
        label-show = false
        left-click = "dropdown:brightness"
        scroll-up = "~/.config/hypr/scripts/brightness.sh up"
        scroll-down = "~/.config/hypr/scripts/brightness.sh down"
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"

        [modules.battery]
        level-icons = ["battery-caution-symbolic", "battery-low-symbolic", "battery-medium-symbolic", "battery-good-symbolic", "battery-full-symbolic", "battery-full-charging-symbolic"]
        charging-icon = "battery-full-charging-symbolic"
        alert-icon = "battery-caution-symbolic"
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"

        [modules.network]
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"
        left-click = "dropdown:network"

        [modules.bluetooth]
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"
        left-click = "dropdown:bluetooth"

        [modules.dashboard]
        icon-override = ""
        icon-show = true
        # La "bola" que envuelve el logo es icon-bg-color (default amarillo "yellow")
        # y el logo en sí icon-color. #00aaff = el azul final del gradiente de borde
        # activo (ff0066 → 9900ff → 00aaff); antes era #00e5ff (cian más frío).
        icon-bg-color = "#00aaff"
        icon-color = "#ffffff"
        left-click = "dropdown:dashboard"
        dropdown-lock-command = "loginctl lock-session"
        # logout con hyprctl dispatch exit (exit limpio -> SDDM relanza el greeter).
        # loginctl terminate-session mandaba SIGTERM al scope y el wrapper
        # start-hyprland de nixpkgs aborta (SIGABRT) -> sddm-helper ve "Process
        # crashed" y NO devuelve el greeter: pantalla negra. Antes de salir se
        # aplica RGBRules2 (el servidor de la sesion sigue vivo -> --client).
        # El openrgb-shutdown de systemd queda de respaldo para reboots externos.
        dropdown-logout-command = "${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules2; hyprctl dispatch exit"
        dropdown-reboot-command = "${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules2; systemctl reboot"
        dropdown-poweroff-command = "${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules2; systemctl poweroff"
        button-bg-color = "bg-elevated"

        [modules.volume]
        icon-show = true
        label-show = false
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"

        # Pill compacto de visualizador flotando entre la hora y workspaces
        # (grupo top, tras clock): barras delgadas en el acento cyberpunk,
        # mismo redondeo/fondo que los demas pills.
        [modules.cava]
        bars = 44
        stereo = true
        input = "pipe-wire"
        style = "peaks"
        direction = "mirror"
        color = "accent"
        bar-width = 2
        bar-gap = 1
        internal-padding = 0.4
        border-show = false
        button-bg-color = "bg-elevated"

        # Brillo via el modulo nativo de wayle: lee /sys/class/backlight.
        # En pc lo provee ddcci (monitor DDC/CI); en laptop el panel interno.
        # Da dropdown con slider + OSD y iconos por nivel (no se oculta en 0).

        [[modules.custom]]
        id = "wallpaper"
        icon-name = "ld-image-symbolic"
        icon-show = true
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        label-show = false
        tooltip-format = "Wallpaper"
        left-click = "~/.config/hypr/scripts/wallpaper-menu.sh"
        right-click = "~/.config/hypr/scripts/wallpaper-cycle.sh"
        button-bg-color = "bg-elevated"

        # Color picker de pantalla: lanza hyprpicker (el picker nativo de
        # Hyprland). Copia el color al portapapeles en hex y muestra un OSD con
        # el valor. Notify es de wayle: `wayle notify`. Depende de hyprpicker
        # en systemPackages (mismo archivo, más abajo).
        [[modules.custom]]
        id = "picker"
        icon-name = "color-select-symbolic"
        icon-show = true
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        label-show = false
        tooltip-format = "Color picker"
        left-click = "hyprpicker -a -f hex && wayle notify \"Color copiado: $(wl-paste)\""
        button-bg-color = "bg-elevated"

        [[modules.custom]]
        id = "clipboard"
        icon-name = "ld-file-text-symbolic"
        icon-show = true
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        label-show = false
        tooltip-format = "Clipboard"
        # Lista (no cuadrícula): sin `listview { columns: 1 }` rofi hereda del
        # tema cyberpunk (type-3) el grid y trunca cada entrada -> no se lee ni
        # la primera palabra. Se fuerza 1 columna + más padding/ancho.
        left-click = "cliphist list | rofi -dmenu -p clipboard -theme-str 'window {width: 700px;} listview {columns: 1; spacing: 6px;} element {padding: 8px;}' | cliphist decode | wl-copy"
        button-bg-color = "bg-elevated"

        # --- Wallpaper (mpvpaper, no awww engine) ---

        [wallpaper]
        engine-enabled = false
        cycling-enabled = false

        # --- OSD ---

        [osd]
        enabled = true
        position = "bottom"
        duration = 2500
      '';
      xdg.configFile."wayle/styles/index.scss".text = ''
        // Gap entre la barra (derecha) y los dropdowns
        popover.dropdown > contents > .dropdown {
            margin-right: calc(0.75rem * var(--global-scale));
        }

        // Bounce de los iconos de apps en el workspace activo
        @keyframes workspace-bounce {
            0%   { -gtk-icon-transform: scale(1) translateY(0); }
            50%  { -gtk-icon-transform: scale(1.5) translateY(-10px); }
            100% { -gtk-icon-transform: scale(1) translateY(0); }
        }

        .workspace.active .workspace-icon {
            animation-name: workspace-bounce;
            animation-duration: 0.6s;
            animation-timing-function: cubic-bezier(0.28, 0.84, 0.42, 1);
        }
      '';
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      ];
    };

    # udisks2: Dolphin lista/monta los discos extra (sda/sdb) sin fstab
    services.udisks2.enable = true;
    # Solo el contenedor del root (nvme0n1p2) va con UDISKS_IGNORE
    # (HintIgnore -> StorageVolume.ignored): lo monta el initrd, nunca se
    # desbloquea desde el escritorio, y el volumen desencriptado ya aparece
    # via fstab. El contenedor de Mikoshi se DEJA visible a proposito: es la
    # unica forma de que Dolphin ofrezca el desbloqueo (click -> dialogo de
    # passphrase de soliduiserver, kded de plasma-workspace). Al desbloquear
    # KFilePlacesModel (kio) muestra contenedor + volumen duplicados (no hay
    # dedup); se esconde el del volumen (/dev/mapper/...) una vez con click
    # derecho -> Hide, y persiste en kfileplaces.xml (bookmark por uuid), asi
    # el contenedor queda solo: desbloquea y navega al mountpoint.
    services.udev.extraRules = ''
      # root (nvme0n1p2): contenedor LUKS, siempre montado por el initrd
      SUBSYSTEM=="block", ENV{ID_FS_TYPE}=="crypto_LUKS", ENV{ID_FS_UUID}=="b6a58d8d-5ccb-436d-8837-bbeebc89a57b", ENV{UDISKS_IGNORE}="1"
    '';
    # Daemons runtime del dashboard de Wayle (red, bluetooth, batería)
    hardware.bluetooth.enable = true;
    services.upower.enable = true;
    # Brillo de monitores externos via DDC/CI (i2c) con ddcutil
    hardware.i2c.enable = true;
    services.udev.packages = [ pkgs.ddcutil ];
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    environment.systemPackages = with pkgs; [
      guirun
      mpvpaper
      cliphist
      (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      wayle
      wl-clipboard
      hyprlock
      hypridle
      # Color picker del portal: xdg-desktop-portal-hyprland necesita hyprpicker
      # (o slurp) para implementar PickColor (el "eyedropper" del Chroma Key de
      # Shotcut y cualquier app que use el portal Screenshot). Sin él:
      # "[ERR] Neither slurp nor hyprpicker found. We can't pick colors."
      hyprpicker
      polkit_gnome
      brightnessctl
      ddcutil
    ];

    # hyprlock hace la autenticación por contraseña vía PAM (servicio "hyprlock");
    # sin este archivo cae a /etc/pam.d/su. fprintAuth=false: la huella la
    # gestiona hyprlock por fprintd de forma nativa (auth fingerprint:enabled),
    # y el pam_fprintd duplicado peleaba el sensor con el fprintd nativo
    # (Device was already claimed) y rompía la contraseña.
    security.pam.services.hyprlock = {
      fprintAuth = false;
    };

    security.polkit.enable = true;
    # Montar/desbloquear discos (udisks2) sin pedir contraseña al usuario wheel
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel") &&
            (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others-seat" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock-system" ||
             action.id == "org.freedesktop.udisks2.encrypted-lock")) {
          return polkit.Result.YES;
        }
      });
    '';

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];

    # El agente polkit corre via exec-once en hyprland-home.nix; este servicio
    # nunca arrancaba (graphical-session.target inactivo con systemd.enable=false).
    # Nota: dos agentes polkit a la vez rompen los diálogos de autenticación.

  };
}
