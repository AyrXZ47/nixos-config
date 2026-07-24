{ lib, ... }:

{
  imports = [ ];
  home.packages = [ ];

  # --- [ CONTROL DE HYDENIX Y ANIMACIONES ] ---
  hydenix.hm = {
    enable = true;
    
    # Blindar la animación LimeFrenzy para siempre
    hyprland.animations = {
      enable = true;
      preset = "LimeFrenzy";
    };

    # APAGAMOS LOS EDITORES DE HYDENIX PARA ACABAR CON LA COLISIÓN DE /bin/nvim
    editors = {
      enable = true;
      neovim = false;      # <- Booleano directo: apaga el nvim de Hydenix
      vim = false;         # <- CORREGIDO: Booleano directo para apagar vim clásico
      vscode.enable = false;
      default = "nvim";    # <- Declaramos tu Neovim cyberpunk como supremo
    };

    social.discord.enable = false;
    social.vesktop.enable = true;
    spotify.enable = false;
  };


  # --- [ HYPRIDLE: GESTIÓN DE ENERGÍA ] ---
  home.file.".config/hypr/hypridle.conf" = lib.mkForce {
    text = ''
      general {
          lock_cmd = pidof hyprlock || hyprlock
          before_sleep_cmd = loginctl lock-session
          after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
          timeout = 600
          on-timeout = hyprctl dispatch dpms off
          on-resume = hyprctl dispatch dpms on
      }
    '';
  };

 # --- [ HYPRLAND PREFS: RESOLUCIÓN, TRANSPARENCIA, ANIMACIONES, GAPS Y DWINDLE ] ---
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      monitor = Virtual-1, 1920x1080@60, auto, 1
      monitor = , 1920x1080@60, auto, 1

      # Gaps compactos para no perder pantalla (6px alinea exactamente con Waybar)
      general {
          gaps_in = 4
          gaps_out = 6
      }

      dwindle {
          force_split = 2
          preserve_split = true
      }

      animations {
          enabled = true
      }

      layerrule = ignorealpha 1, waybar
      layerrule = noanim, waybar
    '';
  };

  # --- [ WAYBAR: CSS ALINEADO, AZUL NATIVO Y CERO ÓVALOS ] ---
  home.file.".config/waybar/user-style.css" = lib.mkForce {
    text = ''
      window#waybar {
        background: transparent;
      }

      * {
        font-size: 18px;
      }

      /* Cajitas negras: Acolchado compacto de 8px para que quepan bien todos los iconos */
      .pill, group {
        padding-top: 8px;
        padding-bottom: 8px;
        padding-left: 0px;
        padding-right: 0px;
        margin: 4px 0px;
        border-radius: 10px;
      }

      /* RESET: Matar márgenes horizontales residuales para centrar todo */
      .pill *, group *, #tray, #tray * {
        margin-left: 0px;
        margin-right: 0px;
        padding-left: 0px;
        padding-right: 0px;
      }

      group > *, .pill > * {
        margin-top: 5px;
        margin-bottom: 5px;
      }

      /* BOTONES: Adiós al óvalo. Usamos border-radius: 4px para un rectángulo moderno */
      #workspaces button, #taskbar button {
        padding: 4px 0px;
        margin: 4px 0px;
        min-width: 28px;
        min-height: 28px;
        border-radius: 4px;
        background: transparent;
      }

      /* INDICADOR ACTIVO: Al no poner 'background', hereda tu AZUL BONITO pero en rectángulo (4px) */
      #workspaces button.active, #workspaces button.focused,
      #taskbar button.active {
        box-shadow: none;
        border: none;
        padding: 4px 0px;
        min-width: 28px;
        min-height: 28px;
        border-radius: 4px;
      }

      #taskbar, #workspaces {
        padding: 0px;
        margin: 0px;
      }
    '';
  };
  # --- [ BLINDAR MODO OSCURO EN SISTEMA Y FIREFOX ] ---
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.sessionVariables = {
    GTK_THEME_VARIANT = "dark";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
