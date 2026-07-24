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

# --- [ HYPRLAND PREFS: TUS MÁRGENES SAGRADOS INTELIGENTES ] ---
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      monitor = Virtual-1, 1920x1080@60, auto, 1
      monitor = , 1920x1080@60, auto, 1

      # TU MARGEN SAGRADO DE 14PX INTACTO
      general {
          gaps_in = 6
          gaps_out = 6 0 6 6
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

  # --- [ WAYBAR: PÍLDORAS LARGAS Y ALINEACIÓN SIN ESCALÓN ] ---
  home.file.".config/waybar/user-style.css" = lib.mkForce {
    text = ''
      window#waybar {
        background: transparent;
      }

      * {
        font-size: 18px;
      }

      /* ALINEACIÓN ANTIESCALÓN: Empujamos los extremos para igualar tus 14px de gaps_out */
      .modules-left {
        margin-top: 0px;
      }
      .modules-right {
        margin-bottom: 0px;
      }

      /* PÍLDORAS MÁS LARGAS */
      .pill, group {
        padding-top: 0px;
        padding-bottom: 0px;
        padding-left: 0px;
        padding-right: 0px;
        margin: 0px 0px;
        border-radius: 20px;
      }

      /* RESET: Matar márgenes horizontales residuales para centrar todo */
      .pill *, group *, #tray, #tray * {
        margin-left: 0px;
        margin-right: 0px;
        padding-left: 0px;
        padding-right: 0px;
      }

      group > *, .pill > * {
        margin-top: 0px;
        margin-bottom: 0px;
      }

      /* BOTONES DE APPS: Rectangulares con bordes boleados (4px) y buen tamaño */
      #workspaces button, #taskbar button {
        padding: 2px 0px;
        margin: 2px 0px;
        min-width: 28px;
        min-height: 28px;
        border-radius: 2px;
        background: transparent;
      }

      /* INDICADOR ACTIVO: Azul nativo en rectángulo elegante */
      #workspaces button.active, #workspaces button.focused,
      #taskbar button.active {
        box-shadow: none;
        border: none;
        padding: 2px 0px;
        min-width: 28px;
        min-height: 28px;
        border-radius: 2px;
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
