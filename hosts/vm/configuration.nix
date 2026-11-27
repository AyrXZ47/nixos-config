{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/caelestia.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/apps/common-cli.nix
    ../../modules/apps/desktop.nix
    ../../modules/apps/docker.nix
  ];

  modules.desktop.hyprland.enable = true;
  modules.desktop.caelestia.enable = true;

  # Loader, timeout, openssh, zona, locale e identidad de git:
  # modules/core/common-host.nix + modules/core/nix-optimization.nix.
  # Mismo kernel que los hosts fisicos: modules/core/kernel-zen.nix.
  boot.initrd.kernelModules = [ "virtio_gpu" "vmwgfx" ];

  system.stateVersion = "26.05";

  networking.hostName = "nixos-vm";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;

  services.xserver.videoDrivers = [ "modesetting" ];

  # Boot: la VM no tiene servicios que esperen "conectividad" para arrancar.
  systemd.services.NetworkManager-wait-online.enable = false;

  # pipewire/rtkit: modules/core/audio.nix (igual que los hosts fisicos).

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 0755 yovick users"
  ];

}
