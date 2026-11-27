{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/hardware/amd-common.nix
    ../../modules/apps/common-cli.nix
    ../../modules/apps/server.nix
  ];

  # Loader, openssh, zona, locale e identidad de git: modules/core/common-host.nix.
  system.stateVersion = "26.05";

  networking.hostName = "nixos-server";

  # amd-common habilita Mesa 32-bit para los hosts con escritorio; el server no
  # corre apps de 32 bits (ni GUI), así que la apaga. mkForce porque amd-common
  # ya define la opción en true.
  hardware.graphics.enable32Bit = lib.mkForce false;

  # Boot: sin GUI ni escritorio, no hay nada que espere "conectividad" para
  # arrancar. NetworkManager-wait-online solo sumaba segundos a la cadena.
  systemd.services.NetworkManager-wait-online.enable = false;

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
