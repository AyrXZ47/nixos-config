{ config, pkgs, lib, ... }:

{
  # AMD CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  # Kernel CachyOS (overlay de chaotic-nyx, ver flake.nix): 7.3.0 compilado con
  # clang thin-LTO y -O3, PREEMPT full, HZ 1000, hugepages always, sched_ext.
  # Se DESCARGA de nyx-cache.chaotic.cx (kernel + modulos cacheados), no compila.
  # Por que no zen: zen es -O2 sin LTO y el scheduler de CachyOS reparte mejor
  # la latencia, que es lo que se siente en Hyprland/juegos.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

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
  # quiet/splash/loglevel=3 se declaran UNA vez en nix-optimization.nix (todos
  # los hosts); duplicarlos aca solo ensuciaba la cmdline.
  boot.kernelParams = [
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
    # pcie_aspm=off ya NO vive aqui: es solo para pc (ADATA SATA) y server — ver
    # amd-desktop.nix y hosts/server/configuration.nix. En la laptop ASPM off
    # costaria bateria sin beneficio (la S20G esta cubierta por el APST off).
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

  # TRIM: la politica vive en modules/core/nix-optimization.nix (manual, sin
  # timer). No re-activar services.fstrim aca: era un `enable = true` redundante
  # con el default y ahora choca con la definicion de ese modulo.
}
