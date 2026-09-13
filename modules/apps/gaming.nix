{ config, pkgs, lib, ... }:

{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    protontricks.enable = true;
  };

  programs.steam.extraCompatPackages = with pkgs; [ proton-ge-bin ];

  # reglas udev para mandos (DualShock/DualSense y genéricos)
  hardware.steam-hardware.enable = true;
  services.udev.packages = [ pkgs.game-devices-udev-rules ];

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    protonup-qt
    wineWow64Packages.wayland
    winetricks
  ];
}
