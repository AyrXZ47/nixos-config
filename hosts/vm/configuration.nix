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
    ../../modules/apps/syncthing.nix
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

  systemd.tmpfiles.rules = [
    "d /nix/var/nix/profiles/per-user/yovick 1777 root root"
  ];

  # Identidad de git por host (NO en modules/apps/git.nix) para no filtrar
  # identidad a quien clone el repo. Default null -> home-manager omite la clave.
  home-manager.users.yovick.modules.apps.git = {
    name = "Yovick RZ";
    email = "66042604+AyrXZ47@users.noreply.github.com";
  };

}
