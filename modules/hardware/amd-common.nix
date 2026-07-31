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
  boot.initrd.kernelModules = [ "amdgpu" ];

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
  ];

  powerManagement.cpuFreqGovernor = "performance";

  # ZRAM
  zramSwap.enable = true;
  zramSwap.memoryPercent = 50;

  # Discos SSD a pleno: TRIM continuo
  services.fstrim.enable = true;

  # GPU AMD a tope desde el arranque: power_dpm_force_performance_level=high (clocks
  # máximos) + pp_power_profile=1 (3D fullscreen). Sin cuello de botella por throttling.
  # ponytail: forzar "high" aumenta consumo y temperatura; si una máquina (p.ej. laptop
  # en batería) prefiere auto, mover este servicio a amd-desktop.nix o quitar el echo.
  systemd.services.amdgpu-perf = {
    description = "Fuerza la GPU AMD al máximo rendimiento";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for d in /sys/class/drm/card*/device; do
        [ -f "$d/power_dpm_force_performance_level" ] && echo high > "$d/power_dpm_force_performance_level"
        [ -f "$d/pp_power_profile" ] && echo 1 > "$d/pp_power_profile"
      done
    '';
  };
}
