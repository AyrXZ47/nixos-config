{ config, pkgs, lib, ... }:

{
  imports = [
    ./amd-common.nix
  ];

  # RX 7600 GPU
  services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];

  # Ollama en GPU: ROCm para RDNA3 (gfx1102). La laptop usa -vulkan en amd-laptop.nix.
  services.ollama.package = pkgs.ollama-rocm;

}
