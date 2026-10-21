{ config, pkgs, lib, ... }:

{
  # NVMe sin DRAM (XPG SPECTRIX S20G, pasa de la pc a la laptop tras el swap):
  # APST apagado + writeback en tandas cortas. Sin esto el controlador DRAM-less
  # se cuelga en silencio bajo escritura sostenida (btrfs esperando el commit de
  # transaccion y el sistema entero congelado). Vivía en amd-common.nix mientras
  # la S20G estuvo en la pc; la pc (ahora con disco con DRAM) ya no lo necesita.
  # NOTA: NO incluye pcie_aspm=off — ese era para los ADATA SATA que siguen en la pc,
  # y en una laptop ASPM off costaria bateria.
  # APST HABILITADO (2026-10-21). Antes estaba en 0 = APST apagado del todo,
  # por miedo al cuelgue del controlador DRAM-less (ver 2026-08-17). Coste real:
  # el disco se queda en PS0 para siempre y no baja a PS3 (0.03W) ni PS4
  # (0.005W), o sea bateria quemada en reposo (44-49 C medidos con el equipo
  # quieto). El valor es el maximo de latencia que el kernel acepta al elegir
  # estado, usando entrada+salida de la tabla del propio disco:
  #   PS3 = 5000 + 10000 us =  15 ms -> entra
  #   PS4 = 54000 + 45000 us = 99 ms -> entra (100000 us)
  # Si vuelven los cuelgues bajo escritura sostenida: bajar a 25000 (solo PS3,
  # sin PS4, ~45 ms menos de latencia) o volver a 0 (APST apagado).
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=100000" ];

  # Writeback pronto y en tandas pequeñas: el kernel vacía la page cache de forma
  # continua en vez de acumular ~12G sucios (dirty_ratio 20) y volcarlos de golpe,
  # lo que satura el controlador del NVMe sin DRAM durante copias/extracciones
  # grandes. 5/10 mantiene las escrituras en ráfagas cortas y controlables.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };
}
