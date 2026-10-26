{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
    ../../modules/apps/ollama-bin.nix
  ];

  # RX 7600: el driver (amdgpu + modesetting) lo declara amd-common.nix.

  # Tuneado de rendimiento del escritorio (vivía en amd-common, ahora solo aquí):
  # laptop y server NO heredan esto. La laptop usa governor powersave + C-states
  # profundos + GPU dpm auto para batería/temperatura.
  powerManagement.cpuFreqGovernor = "performance";

  # Sched-ext: scx_lavd decide a quien le toca CPU por criticidad de latencia
  # (Hyprland y juegos por encima de un `nix build`), en userspace sobre el
  # kernel. Solo necesita CONFIG_SCHED_CLASS_EXT, que trae el kernel de CachyOS
  # (zen tambien lo trae desde 6.12). Si el kernel no lo soporta, el modulo
  # arranca condicionado a /sys/kernel/sched_ext y no rompe nada.
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
    # scx_lavd tiene tres modos de energia mutuamente excluyentes
    # (--performance / --balanced / --powersave). La pc vive enchufada: maximo.
    extraArgs = [ "--performance" ];
  };
  boot.kernelParams = [
    "processor.max_cstate=1"
    # ASPM apagado en todo el PCIe (vivia en amd-common, es SOLO pc/server): con
    # APST ya off, el freeze (btrfs endio-write en wait_current_trans, journald
    # en watchdog timeout) volvio a ocurrir el 2026-08-01 con escritura sostenida.
    # En los ADATA DRAM-less (SATA, siguen en la pc) la gestion de enlace PCIe
    # (ASPM L0s/L1) tambien produce stalls de I/O silenciosos en AMD. La laptop NO
    # lo hereda: ASPM off le costaria bateria sin beneficio (la S20G la cubre el
    # default_ps_max_latency_us=0 de nvme-dramless.nix).
    "pcie_aspm=off"
  ];

  # GPU AMD a tope desde el arranque: power_dpm_force_performance_level=high (clocks
  # máximos) + pp_power_profile=1 (3D fullscreen). Sin cuello de botella por throttling.
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
        # Perfil 3D_FULL_SCREEN (1). OJO: el nodo se llama pp_power_profile_mode,
        # NO pp_power_profile (ese nunca existio: el write viejo era un no-op
        # silencioso, la GPU quedaba en BOOTUP_DEFAULT). Con
        # power_dpm_force_performance_level=high los clocks ya estan clavados al
        # maximo; esto es el perfil fino para cuando se use auto/manual.
        if [ -f "$d/pp_power_profile_mode" ]; then
          echo 1 > "$d/pp_power_profile_mode" 2>/dev/null || true
        fi
        # Power limit al máximo que permite el firmware (desktop: 145W -> 162W).
        # Solo escribe power1_cap_max, asi cada tarjeta queda en su propio maximo.
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
