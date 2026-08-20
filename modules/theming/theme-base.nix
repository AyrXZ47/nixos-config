{ config, pkgs, lib, ... }:

{
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.symbols-only
    inter
    noto-fonts
  ];
}
