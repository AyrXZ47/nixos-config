{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/core/user.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_zen;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-laptop";
  networking.networkmanager.enable = true;
  networking.wireless.iwd.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.opengl.enable = true;

  services.libinput.enable = true;
  services.power-profiles-daemon.enable = true;

  environment.systemPackages = with pkgs; [
    vim git curl wget
  ];

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
