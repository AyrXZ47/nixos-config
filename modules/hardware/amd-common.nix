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
    # NVMe sin DRAM: el APST apagado (nvme_core.default_ps_max_latency_us=0) y el
    # writeback corto (vm.dirty_*) viven en nvme-dramless.nix, que importa SOLO la
    # laptop (la S20G pasa alli tras el swap pc<->laptop). La pc tiene disco con DRAM.
    # ASPM apagado en todo el PCIe: con APST ya off, el freeze (btrfs endio-write en
    # wait_current_trans, journald en watchdog timeout) volvió a ocurrir el 2026-08-01
    # con escritura sostenida. En estos ADATA DRAM-less (SATA, siguen en la pc) la
    # gestión de enlace PCIe (ASPM L0s/L1) también produce stalls de I/O silenciosos en AMD.
    "pcie_aspm=off"
  ];

  # Con el watchdog activo, volcar los backtraces de TODAS las CPUs al
  # detectar un soft lockup: en un freeze multi-CPU el stack de la CPU
  # colgada sola suele ser inútil (está en el spinlock).
  boot.kernel.sysctl = {
    "kernel.softlockup_all_cpu_backtrace" = 1;
  };

  # ZRAM
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  # Discos SSD a pleno: TRIM continuo
  services.fstrim.enable = true;
}
