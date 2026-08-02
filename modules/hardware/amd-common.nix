{ config, pkgs, lib, ... }:

{
  # AMD CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  # Zen kernel
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Common AMD GPU support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # AMD kernel modules
  boot.kernelModules = [ "kvm-amd" "amdgpu" ];
  # amdgpu SOLO en userspace: cargarlo en el initrd (boot.initrd.kernelModules)
  # colgaba ~38s en el probe MST/DP ([drm] pre_validate_dsc) y atrasaba el boot
  # entero, sin ganancia real (no hace falta KMS temprano).

  # PipeWire for pro audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  security.rtkit.enable = true;

  # Performance
  boot.kernelParams = [
    "quiet"
    "splash"
    "loglevel=3"
    # NOTA: "nowatchdog" está deliberadamente FUERA. Con el watchdog apagado un
    # freeze de todo el sistema no deja NINGUNA traza en el journal (el congelado
    # del 2026-08-02 de ~10 min fue invisible salvo por el gap). El NMI watchdog
    # + hung-task son las únicas herramientas que dicen DÓNDE se quedó colgado
    # (btrfs commit, NVMe, amdgpu, CPU). Si un boot requiere reintroducirlo,
    # documentar por qué.
    "split_lock_detect=off"
    # CPU: driver pstate activo y sin mitigaciones (elección de rendimiento).
    # max_cstate=1 (sin deep C-states) vive en amd-desktop.nix, NO aquí: la
    # laptop necesita C-states profundos para reposar y ahorrar batería.
    "amd_pstate=active"
    "mitigations=off"
    # GPU: desbloquea todo el rango de clocks/OC/fan vía /sys (no cambia nada solo)
    "amdgpu.ppfeaturemask=0xffffffff"
    # NVMe sin DRAM (XPG SPECTRIX S20G): APST apagado. Con APST activo el controlador
    # entra a bajo consumo y, bajo una ráfaga de escritura sostenida (copia/extracción
    # grande), dejaba de completar I/O en silencio (sin timeouts ni errores en journal);
    # btrfs se quedaba esperando el commit de transacción y el sistema entero se
    # congelaba. default_ps_max_latency_us=0 desactiva todos los estados de bajo consumo.
    "nvme_core.default_ps_max_latency_us=0"
    # ASPM apagado en todo el PCIe: con APST ya off, el freeze (btrfs endio-write en
    # wait_current_trans, journald en watchdog timeout) volvió a ocurrir el 2026-08-01
    # con escritura sostenida. En estos ADATA DRAM-less la gestión de enlace PCIe
    # (ASPM L0s/L1) también produce stalls de I/O silenciosos en AMD.
    "pcie_aspm=off"
  ];

  # Writeback pronto y en tandas pequeñas: el kernel vacía la page cache de forma
  # continua en vez de acumular ~12G sucios (dirty_ratio 20) y volcarlos de golpe,
  # lo que satura el controlador del NVMe sin DRAM durante copias/extracciones
  # grandes. 5/10 mantiene las escrituras en ráfagas cortas y controlables.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    # Con el watchdog activo, volcar los backtraces de TODAS las CPUs al
    # detectar un soft lockup: en un freeze multi-CPU el stack de la CPU
    # colgada sola suele ser inútil (está en el spinlock).
    "kernel.softlockup_all_cpu_backtrace" = 1;
  };

  # ZRAM
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  # Discos SSD a pleno: TRIM continuo
  services.fstrim.enable = true;
}
