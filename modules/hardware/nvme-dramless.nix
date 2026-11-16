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
  #
  # VOLVIERON (2026-11-15 14:44-14:48): 143 s sin que el sistema loguee nada,
  # journald soltando 9 mensajes encolados de golpe con `lastseen` avanzando 3
  # minutos, load 15-22 con solo 3 tareas runnable e io.pressure full ~53%
  # (kernel, no journald). Sin OOM, sin errores de nvme/btrfs, sin suspend. Es
  # el mismo sintoma del 2026-08 y el disparador fue escritura sostenida
  # (`nix flake check` + `nix build` sobre el store). Se aplica el primer paso
  # documentado: PS4 fuera (99 ms -> 15 ms), PS3 se conserva por bateria.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=25000" ];

  # Writeback pronto y en tandas pequeñas: el kernel vacía la page cache de forma
  # continua en vez de acumular sucio y volcarlo de golpe, lo que satura el
  # controlador del NVMe sin DRAM durante copias/extracciones grandes.
  # 2026-11-15: en BYTES absolutos. Con las proporciones viejas (5/10 sobre
  # 14 GiB) cada rafaga podia ser 700 MB / 1.4 GB, y volcar eso congela la
  # sesion 30-90 s (medido: io.pressure full ~50%, sin OOM ni errores de
  # nvme/btrfs). 64/256 MB acota cada tanda a lo que este controlador aguanta;
  # el ratio queda de fallback por si alguien vuelve a 0 los bytes.
  boot.kernel.sysctl = {
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };
}
