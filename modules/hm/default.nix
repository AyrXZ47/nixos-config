{ ... }:

{
  imports = [
    # ./example.nix
  ];

  home.packages = [
    # tus paquetes
  ];

  hydenix.hm.enable = true;

  # --- [ INYECCIÓN DE DOTFILES ] ---

  # 1. Waybar
  xdg.configFile."waybar/config".text = ''
    {
      "layer": "top",
      "position": "right",
      "width": 45,
      "modules-left": ["hyprland/workspaces"],
      "modules-center": ["clock"],
      "modules-right": ["tray"]
    }
  '';

  # 2. Hyprland User Prefs (para quitar el blur de Waybar)
  xdg.configFile."hypr/userprefs.conf".text = ''
    # Ignorar la opacidad/blur en waybar
    layerrule = ignorealpha 1, waybar
    layerrule = noanim, waybar
  '';

  # 3. Hypridle (Configuración de energía y pantalla)
  # Aquí puedes ajustar los timeouts a tu gusto (en segundos)
  xdg.configFile."hypr/hypridle.conf".text = ''
    general {
        lock_cmd = pidof hyprlock || hyprlock
        before_sleep_cmd = loginctl lock-session
        after_sleep_cmd = hyprctl dispatch dpms on
    }

    # Apagar la pantalla a los 10 minutos (600 segundos) en lugar de 5
    listener {
        timeout = 600
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
    }
  '';
}
