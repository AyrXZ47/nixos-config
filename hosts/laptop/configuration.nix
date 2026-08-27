{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/hardware/nvme-dramless.nix
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

  # openrgb: por si esta laptop llega a tener luces que controlar (perfiles a mano).
  environment.systemPackages = [ pkgs.openrgb ];

  # fwupd: servicio para actualizar firmware (BIOS/SSD). Uso: `fwupdmgr refresh && fwupdmgr update`.
  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-laptop";

  # kdeconnect: abre puertos 1714-1764 TCP/UDP que el firewall bloqueaba
  # (sin esto el daemon corre pero no descubre/conecta dispositivos).
  programs.kdeconnect.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  # Identidad de git por host (NO en modules/apps/git.nix) para no filtrar
  # identidad a quien clone el repo. Default null -> home-manager omite la clave.
  home-manager.users.yovick.modules.apps.git = {
    name = "Yovick RZ";
    email = "66042604+AyrXZ47@users.noreply.github.com";
  };

}
