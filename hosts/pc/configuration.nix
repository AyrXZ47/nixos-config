{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
  ];

  modules.desktop.hyprland = {
    enable = true;
    screenshotKey = "SUPER SHIFT, P";
    screenshotWindowKey = "SUPER ALT, P";
    screenshotScreenKey = "SUPER, P";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

}
