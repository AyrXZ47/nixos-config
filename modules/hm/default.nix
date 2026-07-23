{ lib, ... }:

{
  imports = [ ];
  home.packages = [ ];

  # --- [ CONTROL DE BLOATWARE EN HOME MANAGER ] ---
  hydenix.hm = {
    enable = true;

    # 1. Quitar VSCode
    editors.vscode.enable = false;

    # 2. Quitar Discord oficial y dejar Vesktop
    social.discord.enable = false;
    social.vesktop.enable = false;

    # 3. Quitar Spotify
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
}
