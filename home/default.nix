{ config, pkgs, lib, ... }:

{
  imports = [
    ../modules/apps/shell.nix
    ../modules/apps/wezterm.nix
    ../modules/apps/neovim.nix
    ../modules/apps/fastfetch.nix
    ../modules/apps/git.nix
    ../modules/apps/headroom.nix
    ../modules/apps/mpd.nix
    ../modules/apps/firefox.nix
    ../modules/apps/cava.nix
  ];

  home.username = "yovick";
  home.homeDirectory = "/home/yovick";
  home.stateVersion = "26.05";

  xdg.userDirs = {
    enable = true;
    pictures = "${config.home.homeDirectory}/Pictures";
  };

  home.file."Pictures/Screenshots/.keep".text = "";

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
