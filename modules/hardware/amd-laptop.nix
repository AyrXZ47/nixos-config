{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  boot.kernelParams = [
    "amd_pstate=guided"
    "mitigations=off"
  ];

  # Hybrid power management
  powerManagement = {
    cpuFreqGovernor = "schedutil";
    enable = true;
  };

  services.power-profiles-daemon.enable = true;

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
