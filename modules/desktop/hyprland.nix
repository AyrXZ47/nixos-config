{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.hyprland;
in
{
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
    screenshotKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPER SHIFT, P";
      description = "Keybind for region screenshot";
    };
    screenshotWindowKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPER ALT, P";
      description = "Keybind for window screenshot";
    };
    screenshotScreenKey = lib.mkOption {
      type = lib.types.str;
      default = "SUPER, P";
      description = "Keybind for full screen screenshot";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.yovick = {
      imports = [ ./hyprland-home.nix ];
      wayland.windowManager.hyprland.settings.bind = [
        "${cfg.screenshotKey}, exec, hyprshot -m region -o ~/Pictures/Screenshots"
        "${cfg.screenshotWindowKey}, exec, hyprshot -m window -o ~/Pictures/Screenshots"
        "${cfg.screenshotScreenKey}, exec, hyprshot -m output -o ~/Pictures/Screenshots"
      ];
    };

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      ];
    };
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    environment.systemPackages = with pkgs; [
      (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      wayle
      wl-clipboard
      wlogout
      swaylock-effects
      swayidle
      polkit_gnome
      brightnessctl
    ];

    security.polkit.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];

    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      description = "polkit-gnome-authentication-agent-1";
      wantedBy = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };
  };
}
