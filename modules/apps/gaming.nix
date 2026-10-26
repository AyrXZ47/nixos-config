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

  # Proton/Wine mapean DLLs de 32 y 64 bits y piden muchisimos mapas: con el
  # default (65530) algunos juegos mueren con "out of memory". Este es el valor
  # que recomienda Valve/Proton.
  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  environment.systemPackages = with pkgs; [
    mangohud
    gamescope
    protonup-qt
    wineWow64Packages.wayland
    winetricks
  ];
}
