{ lib, ... }:

{
  imports = [
    # ./example.nix
  ];

  home.packages = [
    # tus paquetes
  ];

  hydenix.hm.enable = true;

  # --- [ INYECCIÓN DE DOTFILES CON FORZADO DE PRIORIDAD ] ---

  # 1. Waybar
  home.file.".config/waybar/config" = lib.mkForce {
    text = ''
      {
        "layer": "top",
        "position": "right",
        "width": 45,
        "modules-left": ["hyprland/workspaces"],
        "modules-center": ["clock"],
        "modules-right": ["tray"]
      }
    '';
  };

  # 2. Hyprland User Prefs
  home.file.".config/hypr/userprefs.conf" = lib.mkForce {
    text = ''
      layerrule = ignorealpha 1, waybar
      layerrule = noanim, waybar
    '';
  };

  # 3. Hypridle
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
