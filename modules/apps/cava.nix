{ config, pkgs, lib, ... }:

{
  # cava standalone NO hereda nada de wayle (programas separados, cada uno lee
  # su config). Se declaran aquí los mismos colores del tema cyberpunk de wayle
  # (styling.palette en hyprland.nix) para que el visualizador del dev() en
  # wezterm matchee la barra.
  xdg.configFile."cava/config".text = ''
    [color]
    foreground = '#ff0066'
    background = '#0a0a12'
    gradient = 1
    gradient_color_1 = '#00ff88'
    gradient_color_2 = '#ffcc00'
    gradient_color_3 = '#ff0066'
  '';
}
