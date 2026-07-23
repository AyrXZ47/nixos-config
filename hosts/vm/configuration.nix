{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    ../../modules/core
    ../../modules/desktop
    ./hardware-configuration.nix
  ];

  # --- [ TWEAKS DE ENERGÍA Y VIRTUALIZACIÓN ] ---
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.spice-vdagentd.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    
    users."yovick" =
      { ... }:
      {
        imports = [
          inputs.hydenix.homeModules.default
          ../../modules/home/default.nix
        ];
      };
  };

  users.users.yovick = {
    isNormalUser = true;
    initialPassword = "yovick"; 
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
    ]; 
    shell = pkgs.zsh; 
  };

  hydenix = {
    enable = true; 
    hostname = "nixos-vm"; 
    timezone = "America/Mexico_City"; 
    locale = "en_US.UTF-8"; 
  };

  system.stateVersion = "25.05";

  boot = {
    plymouth.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    
    initrd.kernelModules = [ "virtio_gpu" "qxl" ];
    
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
