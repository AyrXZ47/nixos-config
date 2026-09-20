{ ... }:

{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 14.0;
    };
    settings = {
      # Vidrio (0.66 como el resto de Caelestia; el blur lo da Hyprland)
      background_opacity = "0.66";
      dynamic_background_opacity = "yes";
      background = "#0a0a12";
      foreground = "#d4d4f0";
      cursor = "#ff0066";
      cursor_text_color = "#0a0a12";
      selection_background = "#1e1e3a";
      selection_foreground = "#d4d4f0";
      # Paleta cyberpunk (16 colores)
      color0 = "#0a0a12";
      color8 = "#555577";
      color1 = "#ff0040";
      color9 = "#ff4d80";
      color2 = "#00ff88";
      color10 = "#66ffb0";
      color3 = "#ffcc00";
      color11 = "#ffe680";
      color4 = "#00aaff";
      color12 = "#80ccff";
      color5 = "#ff0066";
      color13 = "#ff66a0";
      color6 = "#00d4d4";
      color14 = "#66e0e0";
      color7 = "#d4d4f0";
      color15 = "#ffffff";
      # Smear cursor (nativo de kitty)
      cursor_trail = "1";
      cursor_trail_decay = "0.1 0.3";
      cursor_trail_start_threshold = "1";
      # Ventana
      window_padding_width = "10";
      confirm_os_window_close = "0";
      enable_audio_bell = "no";
      # Control remoto para que `kitty @ launch` funcione (lo usa hyprdev)
      allow_remote_control = "yes";
      shell_integration = "enabled";
    };
  };
}
