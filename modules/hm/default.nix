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

# --- [ HYPRLAND PREFS: RESOLUCIÓN, TRANSPARENCIA, ANIMACIONES Y GAPS ] ---
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      monitor = Virtual-1, 1920x1080@60, auto, 1
      monitor = , 1920x1080@60, auto, 1

      # Gaps simétricos y quirúrgicos para alinear ventanas con Waybar (3px)
      general {
          gaps_in = 9
          gaps_out = 9
      }

      # Blindar animaciones para siempre
      animations {
          enabled = true
      }

      layerrule = ignorealpha 1, waybar
      layerrule = noanim, waybar
    '';
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

  # --- [ WAYBAR: CSS OPTIMIZADO Y SUTIL PARA BARRA VERTICAL ] ---
  home.file.".config/waybar/user-style.css" = lib.mkForce {
    text = ''
      window#waybar {
        background: transparent;
      }

      /* Tamaño base de tipografía */
      * {
        font-size: 18px;
      }

      /* Contenedores generales (píldoras): ultra delgadas */
      .pill, group {
        padding: 4px 0px;
        margin: 4px 0px;
        border-radius: 12px;
      }

      /* Botones normales de áreas de trabajo y apps */
      #workspaces button, #taskbar button {
        padding: 4px 0px;
        margin: 2px 0px;
        min-width: 28px;
        min-height: 28px;
        border-radius: 8px;
        background: transparent;
      }

      /* INDICADOR ACTIVO SUTIL: Reemplaza la madre azul por un brillo translúcido */
      #workspaces button.active, #workspaces button.focused,
      #taskbar button.active {
        box-shadow: none;
        border: none;
        padding: 4px 0px;
        min-width: 28px;
        border-radius: 8px;
      }

      /* Eliminar márgenes extras del contenedor de apps */
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
