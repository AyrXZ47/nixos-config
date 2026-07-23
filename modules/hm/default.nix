{ lib, ... }:

{
  imports = [ ];

  home.packages = [ ];

  hydenix.hm.enable = true;

  # --- [ INYECCIÓN DE DOTFILES ] ---

  # 1. Hyprland User Prefs (Resolución + Transparencia de Waybar)
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      # Forzar resolución desde el segundo cero
      monitor = Virtual-1, 1920x1080@60, auto, 1
      # Fallback genérico por si la VM le asigna otro nombre al monitor
      monitor = , 1920x1080@60, auto, 1

      # Quitar el blur de Waybar
      layerrule = ignorealpha 1, waybar
      layerrule = noanim, waybar
    '';
  };

  # 2. Hypridle
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
}
