{ lib, ... }:

{
  imports = [ ];
  home.packages = [ ];

  # --- [ CONTROL DE BLOATWARE EN HYDENIX ] ---
  hydenix.hm = {
    enable = true;
    
    # 1. Quitar VSCode (Nos quedamos con Neovim)
    editors = {
      enable = true;
      neovim = true;
      vscode.enable = false;
    };

    # 2. Quitar Discord oficial rancio (Y dejamos Vesktop activo)
    social = {
      enable = true;
      discord.enable = false;
      vesktop.enable = true;
    };

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
