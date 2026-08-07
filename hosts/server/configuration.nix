{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/hardware/amd-common.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/rust-dev.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-server";

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  modules.hardware.fingerprint.enable = true;

  # Preserva el comportamiento que heredaba de amd-common antes de mover el
  # tuneado de rendimiento a amd-desktop.nix (server sigue a tope).
  powerManagement.cpuFreqGovernor = "performance";
  boot.kernelParams = [ "processor.max_cstate=1" ];

  services.openssh.enable = true;

  # syncthing: arranca el daemon + Web UI en 127.0.0.1:8384.
  # Corre como yovick (el user por defecto "syncthing" no tiene permisos
  # sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };

}
