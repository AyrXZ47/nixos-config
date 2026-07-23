# Agregamos 'lib' a los argumentos de entrada
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
  xdg.configFile."waybar/config".text = lib.mkForce ''
    {
      "layer": "top",
      "position": "right",
      "width": 45,
      "modules-left": ["hyprland/workspaces"],
      "modules-center": ["clock"],
      "modules-right": ["tray"]
    }
  '';

  # 2. Hyprland User Prefs
  xdg.configFile."hypr/userprefs.conf".text = lib.mkForce ''
    # Ignorar la opacidad/blur en waybar
    layerrule = ignorealpha 1, waybar
    layerrule = noanim, waybar
  '';

  # 3. Hypridle
  xdg.configFile."hypr/hypridle.conf".text = lib.mkForce ''
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
}
