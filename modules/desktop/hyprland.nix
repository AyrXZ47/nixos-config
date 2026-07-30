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
      xdg.configFile."wayle/config.toml" = let
        extractColor = name: builtins.head (builtins.match ".*${name}: \"(#[0-9a-fA-F]+)\".*" (builtins.readFile config.stylix.base16Scheme));
        base00 = extractColor "base00";
        base01 = extractColor "base01";
        base02 = extractColor "base02";
        base03 = extractColor "base03";
        base04 = extractColor "base04";
        base05 = extractColor "base05";
        base08 = extractColor "base08";
        base0A = extractColor "base0A";
        base0B = extractColor "base0B";
        base0C = extractColor "base0C";
        base0D = extractColor "base0D";
      in {
        text = ''
          [bar]
          location = "right"
          exclusive = true
          layer = "top"
          rounding = "none"
          module-gap = 0.35
          button-variant = "block-prefix"
          button-rounding = "full"
          button-icon-size = 1.0
          button-icon-padding = 1.0
          button-label-size = 1.0
          button-label-padding = 1.0
          button-gap = 0.5
          button-bg-opacity = 100
          button-opacity = 100
          button-group-module-gap = 0.15

          [[bar.layout]]
          monitor = "*"
          show = true
          left = [
            "idle-inhibit",
            "clock",
            "hyprland-workspaces",
            "window-title",
          ]
          center = []
          right = [
            "volume",
            "microphone",
            "custom-wallpaper",
            "custom-usb",
            "custom-syncthing",
            "custom-clipboard",
            "network",
            "brightness",
            "battery",
            "custom-keybinds",
            "dashboard",
          ]

          [styling]
          scale = 1.01
          rounding = "sm"
          theme-provider = "wayle"
          theming-monitor = ""

          [styling.palette]
          bg = "${base00}"
          surface = "${base01}"
          elevated = "${base02}"
          fg = "${base05}"
          fg-muted = "${base04}"
          primary = "${base0D}"
          red = "${base08}"
          yellow = "${base0A}"
          green = "${base0B}"
          blue = "${base0C}"

          # --- Modules ---

          [modules.clock]
          format = "%I\n%M\n%p"
          icon-name = "tb-calendar-time-symbolic"
          icon-show = false
          label-show = true
          label-color = "primary"
          label-max-length = 0
          left-click = "gnome-calendar"

          [modules.idle-inhibit]
          icon-inactive = "tb-coffee-symbolic"
          icon-active = "tb-coffee-symbolic"
          format = "{{ state }}"
          icon-show = true
          label-show = false
          left-click = "wayle idle toggle --indefinite"

          [modules.hyprland-workspaces]
          display-mode = "label"
          label-use-name = false
          numbering = "absolute"
          app-icons-show = true
          app-icons-dedupe = true
          active-indicator = "background"

          [modules.window-title]
          format = "{{ title }}"
          icon-show = true
          label-show = true
          label-max-length = 1

          [modules.volume]
          level-icons = ["ld-volume-symbolic", "ld-volume-1-symbolic", "ld-volume-2-symbolic"]
          icon-muted = "ld-volume-x-symbolic"
          icon-show = true
          label-show = false
          left-click = "pavucontrol"
          middle-click = "wayle audio output-mute"

          [modules.microphone]
          icon-active = "ld-mic-symbolic"
          icon-muted = "ld-mic-off-symbolic"
          icon-show = true
          label-show = false
          left-click = "pavucontrol"
          middle-click = "wayle audio input-mute"

          [modules.network]
          wifi-connected-icon = "cm-wireless-connected-symbolic"
          wired-connected-icon = "cm-wired-symbolic"
          wired-disconnected-icon = "cm-wired-disconnected-symbolic"
          icon-show = true
          label-show = false
          left-click = "nm-connection-editor"

          [modules.brightness]
          level-icons = ["ld-sun-dim-symbolic", "ld-sun-medium-symbolic", "ld-sun-symbolic"]
          icon-show = true
          label-show = false
          left-click = "dropdown:brightness"

          [modules.battery]
          level-icons = ["md-battery_android_0-symbolic", "md-battery_android_frame_1-symbolic", "md-battery_android_frame_2-symbolic", "md-battery_android_frame_3-symbolic", "md-battery_android_frame_4-symbolic", "md-battery_android_frame_5-symbolic", "md-battery_android_frame_6-symbolic", "md-battery_android_frame_full-symbolic"]
          charging-icon = "md-battery_android_frame_bolt-symbolic"
          alert-icon = "md-battery_android_alert-symbolic"
          icon-show = true
          label-show = false

          [modules.dashboard]
          icon-override = ""
          left-click = "dropdown:dashboard"
          dropdown-lock-command = "loginctl lock-session"
          dropdown-logout-command = "loginctl terminate-session $XDG_SESSION_ID"
          dropdown-reboot-command = "systemctl reboot"
          dropdown-poweroff-command = "systemctl poweroff"

          [[modules.custom]]
          id = "wallpaper"
          command = "echo "
          interval-ms = 3600000
          icon-show = false
          label-show = true
          label-color = "primary"
          left-click = "~/.config/hypr/scripts/wallpaper-cycle.sh"

          [[modules.custom]]
          id = "usb"
          command = "if findmnt | grep -q /media; then echo ; else echo ; fi"
          interval-ms = 60000
          icon-show = false
          label-show = true
          left-click = "udisksctl dump | grep -oP 'block_devices/\\K[^/]+' | while read d; do udisksctl unmount -b /dev/$d && udisksctl power-off -b /dev/$d; done"

          [[modules.custom]]
          id = "syncthing"
          command = "if systemctl --user is-active syncthing >/dev/null 2>&1; then echo ; else echo ; fi"
          interval-ms = 30000
          icon-show = false
          label-show = true

          [[modules.custom]]
          id = "clipboard"
          command = "echo "
          interval-ms = 3600000
          icon-show = false
          label-show = true
          left-click = "cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"

          [[modules.custom]]
          id = "keybinds"
          command = "echo "
          interval-ms = 3600000
          icon-show = false
          label-show = true
          left-click = "wezterm start -e man hyprland"

          # --- Wallpaper Engine ---

          [wallpaper]
          engine-enabled = false

          # --- OSD ---

          [osd]
          enabled = true
          position = "bottom"
          duration = 2500
        '';
      };
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
      awww
      cliphist
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
