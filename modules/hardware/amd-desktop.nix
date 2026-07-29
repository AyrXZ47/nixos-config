{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  # Ryzen 5700X optimization
  boot.kernelParams = [
    "amd_pstate=active"
    "mitigations=off"
    "processor.max_cstate=1"
  ];

  powerManagement.cpuFreqGovernor = "performance";

  # RX 7600 GPU
  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
}
