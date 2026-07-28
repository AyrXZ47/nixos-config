{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/stylix.nix
    ../../modules/theming/plymouth.nix
  ];

  modules.desktop.hyprland.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.timeout = 0;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.initrd.kernelModules = [ "virtio_gpu" "vmwgfx" ];

  system.stateVersion = "26.05";

  networking.hostName = "nixos-vm";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.vmware.guest.enable = true;

  services.xserver.videoDrivers = [ "modesetting" ];

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  services.openssh.enable = true;

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 1777 root root"
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
