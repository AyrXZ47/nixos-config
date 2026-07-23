{ lib, ... }:

{
  imports = [ ];

  home.packages = [ ];

  hydenix.hm.enable = true;

# --- [ WAYBAR A LA DERECHA CON ESTÉTICA INTACTA ] ---
  home.file.".config/waybar/config" = lib.mkForce {
    text = ''
      {
        "include": [
          "~/.config/waybar/modules.json",
          "~/.config/waybar/modules/*.json",
          "~/.config/waybar/modules/*.jsonc"
        ],
        "layer": "top",
        "position": "right",
        "width": 44,
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["clock"],
        "modules-right": ["tray", "custom/power"]
      }
    '';
  };

  # --- [ HYPRLAND PREFS: RESOLUCIÓN Y TRANSPARENCIA ] ---
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      # Forzar resolución desde el segundo cero (soporte específico y genérico)
      monitor = Virtual-1, 1920x1080@60, auto, 1
      monitor = , 1920x1080@60, auto, 1

      # Forzamos la transparencia y quitamos el blur feo de Waybar
      layerrule = ignorealpha 1, waybar
      layerrule = noanim, waybar
    '';
  };

  # --- [ HYPRIDLE: GESTIÓN DE ENERGÍA Y SUSPENSIÓN ] ---
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
