{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/apps/shell.nix
    ../modules/apps/kitty.nix
    ../modules/apps/pantalla.nix
    ../modules/apps/neovim.nix
    ../modules/apps/fastfetch.nix
    ../modules/apps/git.nix
    ../modules/apps/mpd.nix
    ../modules/apps/firefox.nix
    ../modules/apps/serena.nix
    ../modules/apps/opencode.nix
    ../modules/apps/dolphin.nix
    ../modules/apps/gtkwave.nix
    ../modules/apps/miracast.nix
    ../modules/apps/mixxx-mpris.nix
  ];

  home.username = "yovick";
  home.homeDirectory = "/home/yovick";
  home.stateVersion = "26.05";

  xdg.userDirs = {
    enable = true;
    pictures = "${config.home.homeDirectory}/Pictures";
  };

  home.file."Pictures/Screenshots/.keep".text = "";

  # Estilo neón de mplcyberpunk aplicado a TODAS las gráficas de matplotlib
  # (matplotlib carga este rc automáticamente en cada import). El contenido es
  # el stylesheet cyberpunk.mplstyle; .source = se versiona como asset.
  xdg.configFile."matplotlib/matplotlibrc".source = ../assets/matplotlib/matplotlibrc;

  # Tema cyberpunk para el IDE de Vivado 2026.1: recoloreado desde el "Dark
  # Theme" nativo con la paleta de NeoCyberVim (vendoreado, no se redistribuye
  # el tema de AMD). Vivado lo lista por el nombre del archivo; se elige en
  # Tools > Settings > Themes > Cyberpunk (una sola vez).
  home.file.".Xilinx/Vivado/2026.1/newThemes/Cyberpunk.xmltheme".source =
    ../assets/vivado/Cyberpunk.xmltheme;

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    _1password-cli
    btop
    cava
    ffmpeg
    fd
    fzf
    gh
    libnotify
    obsidian
    opencode
    pipes-rs
    ripgrep
    scrcpy
    unzip
    wget
    yt-dlp
  ];
}
