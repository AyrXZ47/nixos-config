{ config, pkgs, lib, ... }:

{
  # AMD CPU microcode
  hardware.cpu.amd.updateMicrocode = true;

  # El kernel vive en modules/core/kernel-cachyos.nix (igual para los 4 hosts).
  # Common AMD GPU support
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # X11/Wayland: amdgpu + modesetting en todos los hosts con GPU AMD. La VM no
  # hereda esto (no importa amd-common): usa solo modesetting, su virtio-gpu.
  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Mesa cachea los shaders compilados; el tope por defecto es 1 GB y al
  # llenarse expulsa entradas viejas -> recompilacion en caliente = stutter en
  # el primer minuto de cada juego (y de cada actualizacion de mesa). 8 GB es un
  # TOPE, no reserva nada: solo crece si hace falta.
  environment.sessionVariables.MESA_SHADER_CACHE_MAX_SIZE = "8G";

  # AMD kernel modules
  boot.kernelModules = [ "kvm-amd" "amdgpu" ];
  # amdgpu SOLO en userspace: cargarlo en el initrd (boot.initrd.kernelModules)
  # colgaba ~38s en el probe MST/DP ([drm] pre_validate_dsc) y atrasaba el boot
  # entero, sin ganancia real (no hace falta KMS temprano).

  # audio (pipewire/rtkit) vive en modules/core/audio.nix: igual en los 4.

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
