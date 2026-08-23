{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/flatpak.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/rust-dev.nix
    ../../modules/apps/packettracer.nix
  ];

  # Packet Tracer (universidad): el .deb se baja solo (Archive.org) en el rebuild.
  modules.apps.packetTracer.enable = true;

  modules.desktop.hyprland.enable = true;

  modules.hardware.fingerprint.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.timeout = 0;
  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.initrd.kernelModules = [ "virtio_gpu" "vmwgfx" ];

  system.stateVersion = "26.05";

  networking.hostName = "nixos-vm";

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

  # syncthing: arranca el daemon + Web UI en 127.0.0.1:8384.
  # Corre como yovick (el user por defecto "syncthing" no tiene permisos
  # sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 1777 root root"
  ];

  # Email de git por host (NO en modules/apps/git.nix) para no filtrar identidad
  # a quien clone el repo. Default null -> home-manager omite la clave.
  home-manager.users.yovick.modules.apps.git.email = "66042604+AyrXZ47@users.noreply.github.com";

}
