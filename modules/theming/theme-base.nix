{ config, pkgs, lib, ... }:

{
  # Cursor del sistema: Qogir (vinceliuice/Qogir-icon-theme, variante dist-Dark),
  # forzado a nivel de sistema vía home-manager pointerCursor (XCURSOR_THEME)
  # para que TODAS las apps (GTK/Qt/X11/Wayland) lo usen. El paquete
  # `qogir-dark-cursor` viene del overlay qogirDarkCursorOverlay en flake.nix.
  home-manager.users.yovick = {
    home.pointerCursor = {
      enable = true;
      name = "Qogir-white";
      package = pkgs.qogir-dark-cursor;
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
