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

    editors.vscode.enable = false;
    social.discord.enable = false;
    social.vesktop.enable = true;
    spotify.enable = false;
  };



  # --- [ HYPRLAND PREFS: RESOLUCIÓN Y TRANSPARENCIA ] ---
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      monitor = Virtual-1, 1920x1080@60, auto, 1
      monitor = , 1920x1080@60, auto, 1

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

# --- [ WAYBAR: CSS OPTIMIZADO PARA BARRA VERTICAL ] ---
  home.file.".config/waybar/user-style.css" = lib.mkForce {
    text = ''
      window#waybar {
        background: transparent;
      }

      /* Aumentar tamaño base de íconos */
      * {
        font-size: 18px;
      }

      /* Matar el relleno gordo horizontal y apretar la píldora al icono */
      .pill, group {
        padding: 4px 2px;
        margin: 4px 0px;
        border-radius: 12px;
      }

      /* Ceñir los botones de las apps y del área de trabajo */
      #taskbar button, #workspaces button {
        padding: 4px 2px;
        margin: 2px 0px;
        min-width: 0px;
        border-radius: 8px;
      }

      #taskbar {
        padding: 0px;
      }
    '';
  };

}
