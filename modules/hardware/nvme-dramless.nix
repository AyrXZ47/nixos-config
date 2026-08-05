{ config, pkgs, lib, ... }:

{
  # NVMe sin DRAM (XPG SPECTRIX S20G, pasa de la pc a la laptop tras el swap):
  # APST apagado + writeback en tandas cortas. Sin esto el controlador DRAM-less
  # se cuelga en silencio bajo escritura sostenida (btrfs esperando el commit de
  # transaccion y el sistema entero congelado). Vivía en amd-common.nix mientras
  # la S20G estuvo en la pc; la pc (ahora con disco con DRAM) ya no lo necesita.
  # NOTA: NO incluye pcie_aspm=off — ese era para los ADATA SATA que siguen en la pc,
  # y en una laptop ASPM off costaria bateria.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  # Writeback pronto y en tandas pequeñas: el kernel vacía la page cache de forma
  # continua en vez de acumular ~12G sucios (dirty_ratio 20) y volcarlos de golpe,
  # lo que satura el controlador del NVMe sin DRAM durante copias/extracciones
  # grandes. 5/10 mantiene las escrituras en ráfagas cortas y controlables.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };
}
