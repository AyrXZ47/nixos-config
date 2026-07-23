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

  # Agentes de integración para GNOME Boxes / KVM / QEMU
  services.spice-vdagentd.enable = true;
  services.qemuGuest.enable = true; # Sincroniza el ratón y el portapapeles

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
    kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
    loader.timeout = 0;
    plymouth = {
      enable = true;
      # CRÍTICO: 'spinner' o 'fade-in' dibujan la UI gráfica sin buscar el logo UEFI de la motherboard.
      theme = "spinner"; 
    };
    consoleLogLevel = 0;
    initrd.verbose = false;
    initrd.systemd.enable = true;
    initrd.kernelModules = [ "virtio_gpu" ];
    
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0" # Oculta el cursor parpadeante en la consola
      "video=1920x1080@60"         # FUERZA 1080p desde el milisegundo 0: Arregla SDDM y Plymouth
    ];
  };
}
