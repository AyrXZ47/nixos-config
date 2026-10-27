{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/hardware/amd-common.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/sdr.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/rust-dev.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/docker.nix
  ];

  # Loader, openssh, zona, locale e identidad de git: modules/core/common-host.nix.
  system.stateVersion = "26.05";

  networking.hostName = "nixos-server";

  modules.hardware.fingerprint.enable = true;
  modules.hardware.sdr.enable = true;

  # Preserva el comportamiento que heredaba de amd-common antes de mover el
  # tuneado de rendimiento a amd-desktop.nix (server sigue a tope).
  powerManagement.cpuFreqGovernor = "performance";
  # pcie_aspm=off tambien lo heredaba de amd-common; se re-declara aqui porque
  # amd-common ya no lo incluye (es solo para los hosts de escritorio/servidor
  # con ADATA SATA; la laptop lo perdio a proposito, le costaria bateria).
  # `processor.max_cstate=1` se fue el 2026-10-26 (igual que en la pc): es el
  # mismo freno al boost y este server pasa enchufado igual que la pc.
  boot.kernelParams = [ "pcie_aspm=off" ];

}
