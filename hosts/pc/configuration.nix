{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/core/user.nix

    # DESKTOP ENVIRONMENT (uncomment when ready)
    # ../../modules/desktop/hyprland.nix

    # THEMING (uncomment when ready)
    # ../../modules/theming/stylix.nix
    # ../../modules/theming/plymouth.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_zen;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  # ============================================================
  # HIGH-PERFORMANCE GRAPHICS — INJECT GPU-SPECIFIC CONFIG HERE
  # ============================================================
  # Discrete GPU acceleration (NVIDIA/AMD):
  #   - Enable proprietary driver: services.xserver.videoDrivers = [ "nvidia" ];
  #   - OR open-source:            services.xserver.videoDrivers = [ "amdgpu" "modesetting" ];
  #
  # OpenGL / Vulkan:
  #   - hardware.opengl = {
  #       enable = true;
  #       driSupport = true;
  #       extraPackages = with pkgs; [ vaapiVdpau libvdpau-va-gl ];
  #     };
  #
  # Max display refresh rate / resolution:
  #   - Set via monitor config in Hyprland (e.g. monitor=DP-1,2560x1440@165)
  #   - Or via services.xserver.resolutions / xrandr for X11 sessions
  # ============================================================

  services.xserver.videoDrivers = [ "modesetting" ];
  hardware.opengl.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
    fastfetch
  ];

  services.openssh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
