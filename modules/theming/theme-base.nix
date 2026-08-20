{ config, pkgs, lib, ... }:

{
  # Cursor del sistema: Breeze Dark (repo polirritmico/Breeze-Dark-Cursor),
  # forzado a nivel de sistema vía home-manager pointerCursor (XCURSOR_THEME)
  # para que TODAS las apps (GTK/Qt/X11/Wayland) lo usen. El paquete
  # `breeze-dark-cursor` viene del overlay breezeDarkCursorOverlay en flake.nix.
  home-manager.users.yovick = {
    home.pointerCursor = {
      enable = true;
      name = "Breeze_Dark";
      package = pkgs.breeze-dark-cursor;
      size = 24;
      # Xcursor respeta esto y GTK/Qt lo recogen via xsettings/gsettings.
      gtk.enable = true;
    };
  };

  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    inter
    noto-fonts
  ];
}
