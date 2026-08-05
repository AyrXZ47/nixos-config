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
