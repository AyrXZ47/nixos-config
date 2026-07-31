{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Ollama en GPU: Vulkan funciona con cualquier Radeon/APU (RADV) sin rocm pesado.
  services.ollama.package = pkgs.ollama-vulkan;

  # Sin capadores: hereda de amd-common CPU governor "performance", amd_pstate=active,
  # max_cstate=1 y GPU dpm high. power-profiles-daemon está deshabilitado porque
  # cambiaría el governor y caparía el rendimiento.
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

  networking.networkmanager.wifi.backend = "iwd";
}
