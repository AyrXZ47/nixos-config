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
  # pcie_aspm=off tambien lo heredaba de amd-common; se re-declara aqui porque
  # amd-common ya no lo incluye (es solo para los hosts de escritorio/servidor
  # con ADATA SATA; la laptop lo perdio a proposito, le costaria bateria).
  boot.kernelParams = [ "processor.max_cstate=1" "pcie_aspm=off" ];

  services.openssh.enable = true;

  # syncthing: arranca el daemon + Web UI en 127.0.0.1:8384.
  # Corre como yovick (el user por defecto "syncthing" no tiene permisos
  # sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };

  # Identidad de git por host (NO en modules/apps/git.nix) para no filtrar
  # identidad a quien clone el repo. Default null -> home-manager omite la clave.
  home-manager.users.yovick.modules.apps.git = {
    name = "Yovick RZ";
    email = "66042604+AyrXZ47@users.noreply.github.com";
  };

}
