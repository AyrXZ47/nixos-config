{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
    inputs.hydenix.nixosModules.default
    ./modules/system
    ./hardware/vm-hardware.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    
    # Aquí conectamos tus dotfiles visuales
    users."yovick" =
      { ... }:
      {
        imports = [
          inputs.hydenix.homeModules.default
          ./modules/hm
        ];
      };
  };

  # Aquí creamos tu cuenta en el sistema
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
