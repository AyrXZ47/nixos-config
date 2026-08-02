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
    "nowatchdog"
    "split_lock_detect=off"
    # CPU al tope: driver pstate activo, sin mitigaciones, sin deep C-states
    # (CPU nunca entra a estados que retrasen la respuesta). ponytail: quitar
    # "processor.max_cstate=1" si se prefiere ahorro en batería.
    "amd_pstate=active"
    "mitigations=off"
    "processor.max_cstate=1"
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

  powerManagement.cpuFreqGovernor = "performance";

  # Writeback pronto y en tandas pequeñas: el kernel vacía la page cache de forma
  # continua en vez de acumular ~12G sucios (dirty_ratio 20) y volcarlos de golpe,
  # lo que satura el controlador del NVMe sin DRAM durante copias/extracciones
  # grandes. 5/10 mantiene las escrituras en ráfagas cortas y controlables.
  boot.kernel.sysctl = {
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
  };

  # ZRAM
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  # Discos SSD a pleno: TRIM continuo
  services.fstrim.enable = true;

  # GPU AMD a tope desde el arranque: power_dpm_force_performance_level=high (clocks
  # máximos) + pp_power_profile=1 (3D fullscreen). Sin cuello de botella por throttling.
  # ponytail: forzar "high" aumenta consumo y temperatura; si una máquina (p.ej. laptop
  # en batería) prefiere auto, mover este servicio a amd-desktop.nix o quitar el echo.
  # Reintenta la escritura porque el reinicio de udevd durante el switch puede devolver
  # EPERM transitorio; solo falla si ninguna tarjeta quedó en high.
  systemd.services.amdgpu-perf = {
    description = "Fuerza la GPU AMD al máximo rendimiento";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ok=0
      for d in /sys/class/drm/card[0-9]/device; do
        if [ -f "$d/power_dpm_force_performance_level" ]; then
          for try in 1 2 3; do
            if echo high > "$d/power_dpm_force_performance_level" 2>/dev/null; then
              ok=1
              break
            fi
            sleep 1
          done
        fi
        if [ -f "$d/pp_power_profile" ]; then
          echo 1 > "$d/pp_power_profile" 2>/dev/null || true
        fi
        # Power limit al máximo que permite el firmware (desktop: 145W -> 162W).
        # ponytail: sube consumo/temperatura/ruido; con el cap en 145W la RX 7600
        # se queda sin cabeza en cargas GPU-bound. Solo escribe power1_cap_max, asi
        # cada tarjeta (tambien la de la laptop) queda en su propio maximo seguro.
        for h in "$d"/hwmon/hwmon*; do
          if [ -f "$h/power1_cap_max" ]; then
            cap=$(cat "$h/power1_cap_max" 2>/dev/null) || true
            [ -n "$cap" ] && echo "$cap" > "$h/power1_cap" 2>/dev/null || true
          fi
        done
      done
      [ "$ok" = 1 ]
    '';
  };
}
