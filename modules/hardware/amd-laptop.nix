{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Ollama en GPU: Vulkan funciona con cualquier Radeon/APU (RADV) sin rocm pesado.
  services.ollama.package = pkgs.ollama-vulkan;

  # Laptop = eficiencia: governor powersave (amd-pstate-epp gestiona boost y EPP),
  # sin max_cstate=1 (la CPU entra en C-states profundos al reposo) y GPU dpm en
  # auto (no hereda el amdgpu-perf de amd-desktop). power-profiles-daemon sigue
  # deshabilitado porque pelearía con el governor.
  powerManagement.cpuFreqGovernor = "powersave";
  services.power-profiles-daemon.enable = lib.mkForce false;

  # EPP balance_power: punto medio entre balanced y power. Ahorra en reposo pero
  # conserva el boost cuando hay carga, sin el corte agresivo de "power". Se
  # escribe por núcleo porque amd-pstate expone el EPP por policy (cpufreq dir).
  systemd.services.cpu-epp = {
    description = "Fija EPP de la CPU a balance_power";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference; do
        echo balance_power > "$d" 2>/dev/null || true
      done
    '';
  };

  # Touchpad Synaptics LEN2073: en protocolo PS/2 (synps/2) libinput detecta el
  # swipe de 3 dedos pero lo descarta al instante ("Touch jump", sin updates de
  # movimiento) -> el gesto de workspaces nunca disparaba. Este touchpad soporta
  # RMI4 por SMBus; forzarlo da multitouch real con seguimiento de 3+ dedos.
  boot.kernelParams = [ "psmouse.synaptics_intertouch=1" ];

  # ThinkPad specific
  services.libinput = {
    enable = true;
    touchpad = {
      naturalScrolling = true;
      disableWhileTyping = true;
      clickMethod = "clickfinger";
      accelProfile = "flat";
    };
  };

  hardware.sensor.iio.enable = true;
}
