{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/stylix.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
  ];

  modules.desktop.hyprland = {
    enable = true;
    screenshotKey = "SUPER, P";
    screenshotWindowKey = "SUPER SHIFT, P";
    screenshotScreenKey = "SUPER, F4";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
