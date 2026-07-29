{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/stylix.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
  ];

  modules.desktop.hyprland.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  # Replace with generated hardware-configuration.nix
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  networking.hostName = "nixos-laptop";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
