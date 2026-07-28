{ config, pkgs, lib, ... }:

let
  cfg = config.modules.desktop.hyprland;
in
{
  options.modules.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    programs.uwsm.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    environment.systemPackages = with pkgs; [
      hyprpanel
      wl-clipboard
      wlogout
      swaylock-effects
      swayidle
      polkit_gnome
      brightnessctl
      pulseaudio
      pavucontrol
    ];

    security.polkit.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    fonts.packages = with pkgs; [ jetbrains-mono nerdfonts ];

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
