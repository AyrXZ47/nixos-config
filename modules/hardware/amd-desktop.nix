{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  # RX 7600 GPU
  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Ollama en GPU: ROCm para RDNA3 (gfx1102). La laptop usa -vulkan en amd-laptop.nix.
  services.ollama.package = pkgs.ollama-rocm;

  # Tuneado de rendimiento del escritorio (vivía en amd-common, ahora solo aquí):
  # laptop y server NO heredan esto. La laptop usa governor powersave + C-states
  # profundos + GPU dpm auto para batería/temperatura.
  powerManagement.cpuFreqGovernor = "performance";
  boot.kernelParams = [ "processor.max_cstate=1" ];

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
        if [ -f "$d/pp_power_profile" ]; then
          echo 1 > "$d/pp_power_profile" 2>/dev/null || true
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
