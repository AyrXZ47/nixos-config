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
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/sdr.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/rust-dev.nix
    ../../modules/apps/packettracer.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/docker.nix
  ];

  # Packet Tracer (universidad): el .deb se baja solo (Archive.org) en el rebuild.
  modules.apps.packetTracer.enable = true;

  modules.desktop.hyprland.enable = true;
  modules.desktop.caelestia.enable = true;

  modules.hardware.fingerprint.enable = true;
  modules.hardware.sdr.enable = true;

  # Loader, timeout, openssh, zona, locale e identidad de git:
  # modules/core/common-host.nix + modules/core/nix-optimization.nix.
  # Mismo kernel que los hosts fisicos: modules/core/kernel-cachyos.nix.
  boot.initrd.kernelModules = [ "virtio_gpu" "vmwgfx" ];

  system.stateVersion = "26.05";

  networking.hostName = "nixos-vm";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  virtualisation.vmware.guest.enable = true;

  services.xserver.videoDrivers = [ "modesetting" ];

  # pipewire/rtkit: modules/core/audio.nix (igual que los hosts fisicos).

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 1777 root root"
  ];

}
