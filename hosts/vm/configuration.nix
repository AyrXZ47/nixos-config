{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
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
  networking.firewall.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.vmware.guest.enable = true;

  services.xserver.videoDrivers = [ "modesetting" ];

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  security.rtkit.enable = true;

  services.openssh.enable = true;

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 1777 root root"
  ];

}
