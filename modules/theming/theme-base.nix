{ config, pkgs, lib, ... }:

{
  # Cursor del sistema: Material Bibata Deep Blue (SakibShahariar/
  # material-bibata-cursor), forzado a nivel de sistema vía home-manager
  # pointerCursor (XCURSOR_THEME) para que TODAS las apps (GTK/Qt/X11/Wayland)
  # lo usen. El paquete `bibata-material-deep-blue` viene del overlay
  # bibataCursorOverlay.
  home-manager.users.yovick = {
    home.pointerCursor = {
      enable = true;
      name = "Bibata-Material-Deep-Blue";
      package = pkgs.bibata-material-deep-blue;
      size = 30;
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
