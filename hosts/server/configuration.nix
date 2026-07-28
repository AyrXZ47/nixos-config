{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/core/user.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-server";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    vim git curl wget htop
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
