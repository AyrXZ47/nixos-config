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
      gtk = {
        enable = true;
        theme = {
          name = "Adwaita-dark";
          package = pkgs.gnome-themes-extra;
        };
        iconTheme = {
          name = "Papirus-Dark";
          package = pkgs.papirus-icon-theme;
        };
        gtk3.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
        gtk4.extraConfig = {
          gtk-application-prefer-dark-theme = 1;
        };
      };
      qt = {
        enable = true;
        platformTheme.name = "gtk3";
        style = {
          name = "adwaita-dark";
          package = pkgs.adwaita-qt;
        };
      };
      xdg.configFile."kdeglobals" = {
        text = ''
          [KDE]
          ColorScheme=BreezeDark
          widgetStyle=Breeze
          [General]
          colorScheme=BreezeDark
        '';
      };
      home.sessionVariables = {
        GTK_THEME = "Adwaita:dark";
        QT_QPA_PLATFORMTHEME = "gtk3";
        # Hyprland, no KDE: XDG_CURRENT_DESKTOP=KDE hace que xdg-open use kfmclient
        # (no instalado) y nunca abra el navegador (rompía gh auth login).
        XDG_CURRENT_DESKTOP = "Hyprland";
      };
      xdg.configFile."wayle/config.toml".text = ''
        [bar]
        location = "right"
        exclusive = true
        layer = "top"
        rounding = "none"
        module-gap = 0.3
        padding = 0.1
        padding-ends = 0.2
        inset-edge = 0.25
        bg = "transparent"
        border-location = "none"
        border-width = 0
        shadow = "none"

        button-variant = "block-prefix"
        button-rounding = "full"
        button-icon-size = 1.0
        button-icon-padding = 0.6
        button-label-size = 1.35
        button-label-weight = "bold"
        button-label-padding = 1.0
        button-gap = 0.5
        button-bg-opacity = 100
        button-opacity = 100
        button-border-location = "none"
        button-border-width = 0
        button-group-module-gap = 0.15
        button-group-padding = 0.15
        button-group-rounding = "full"
        button-group-background = "bg-elevated"
        button-group-opacity = 100
        button-group-border-location = "none"

        dropdown-shadow = true
        dropdown-opacity = 100
        dropdown-autohide = true
        dropdown-freeze-label = true

        [[bar.layout]]
        monitor = "*"
        show = true
        left = [
          { name = "top", modules = ["notifications", "clock"] },
        ]
        center = ["hyprland-workspaces"]
        right = [
          { name = "bottom", modules = [
            "custom-clipboard",
            "custom-wallpaper",
            "network",
            "bluetooth",
            "battery",
            "dashboard",
          ] },
        ]

        [styling]
        scale = 1.1
        rounding = "lg"
        theme-provider = "wayle"
        theming-monitor = ""

        [styling.palette]
        bg = "#0a0a12"
        surface = "#141428"
        elevated = "#1e1e3a"
        fg = "#d4d4f0"
        fg-muted = "#8888aa"
        primary = "#ff0066"
        red = "#ff0040"
        yellow = "#ffcc00"
        green = "#00ff88"
        blue = "#00aaff"

        # --- Modules ---

        [modules.clock]
        format = "%I\n%M"
        icon-show = false
        label-show = true
        label-color = "#ff0066"
        label-max-length = 0
        left-click = "dropdown:calendar"
        button-bg-color = "transparent"

        [modules.idle-inhibit]
        icon-inactive = "ld-bell-symbolic"
        icon-active = "ld-bell-off-symbolic"
        format = "{{ state }}"
        icon-show = true
        label-show = false
        left-click = "wayle idle toggle --indefinite"
        button-bg-color = "bg-elevated"

        [modules.hyprland-workspaces]
        display-mode = "label"
        label-use-name = false
        numbering = "absolute"
        app-icons-show = true
        app-icons-dedupe = true
        app-icons-empty = "tb-minus-symbolic"
        active-indicator = "background"
        min-workspace-count = 5
        container-bg-color = "#000000"
        active-color = "#ff0066"
        occupied-color = "#8888aa"
        empty-color = "#2a2a44"
        workspace-padding = 0.3
        icon-size = 1.0
        label-size = 0.85
        icon-gap = 0.2

        [modules.notifications]
        icon-show = true
        label-show = false
        icon-inactive = "preferences-system-notifications-symbolic"
        icon-active = "notifications-disabled-symbolic"
        left-click = "dropdown:notification"
        right-click = "wayle notify dnd"
        popup-position = "bottom-right"
        popup-max-visible = 5
        popup-duration = 5000
        popup-hover-pause = true
        popup-margin-x = 12
        popup-margin-y = 12
        popup-gap = 8
        popup-shadow = true
        popup-urgency-bar = "low"
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "bg-elevated"
        button-bg-color = "bg-elevated"

        [modules.brightness]
        level-icons = ["ld-sun-dim-symbolic", "ld-sun-medium-symbolic", "ld-sun-symbolic"]
        icon-show = true
        label-show = false
        left-click = "dropdown:brightness"
        border-color = "blue"
        icon-color = "blue"
        icon-bg-color = "blue"
        button-bg-color = "bg-elevated"

        [modules.battery]
        level-icons = ["battery-caution-symbolic", "battery-low-symbolic", "battery-medium-symbolic", "battery-good-symbolic", "battery-full-symbolic", "battery-full-charging-symbolic"]
        charging-icon = "battery-full-charging-symbolic"
        alert-icon = "battery-caution-symbolic"
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"

        [modules.network]
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"
        left-click = "dropdown:network"

        [modules.bluetooth]
        icon-show = true
        label-show = false
        border-color = "#000000"
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        button-bg-color = "bg-elevated"
        left-click = "dropdown:bluetooth"

        [modules.dashboard]
        icon-override = ""
        left-click = "dropdown:dashboard"
        dropdown-lock-command = "loginctl lock-session"
        dropdown-logout-command = "loginctl terminate-session $XDG_SESSION_ID"
        dropdown-reboot-command = "systemctl reboot"
        dropdown-poweroff-command = "systemctl poweroff"
        button-bg-color = "bg-elevated"

        [[modules.custom]]
        id = "wallpaper"
        icon-name = "ld-image-symbolic"
        icon-show = true
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        label-show = false
        tooltip-format = "Wallpaper"
        left-click = "~/.config/hypr/scripts/wallpaper-menu.sh"
        right-click = "~/.config/hypr/scripts/wallpaper-cycle.sh"
        button-bg-color = "bg-elevated"

        [[modules.custom]]
        id = "clipboard"
        icon-name = "edit-paste-symbolic"
        icon-show = true
        icon-color = "#ff0066"
        icon-bg-color = "transparent"
        label-show = false
        tooltip-format = "Clipboard"
        left-click = "cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"
        button-bg-color = "bg-elevated"

        # --- Wallpaper (mpvpaper, no awww engine) ---

        [wallpaper]
        engine-enabled = false
        cycling-enabled = false

        # --- OSD ---

        [osd]
        enabled = true
        position = "bottom"
        duration = 2500
      '';
      xdg.configFile."wayle/styles/index.scss".text = ''
        // Gap entre la barra (derecha) y los dropdowns
        popover.dropdown > contents > .dropdown {
            margin-right: calc(0.75rem * var(--global-scale));
        }

        // Bounce de los iconos de apps en el workspace activo
        @keyframes workspace-bounce {
            0%   { -gtk-icon-transform: scale(1) translateY(0); }
            50%  { -gtk-icon-transform: scale(1.5) translateY(-10px); }
            100% { -gtk-icon-transform: scale(1) translateY(0); }
        }

        .workspace.active .workspace-icon {
            animation-name: workspace-bounce;
            animation-duration: 0.6s;
            animation-timing-function: cubic-bezier(0.28, 0.84, 0.42, 1);
        }
      '';
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

    # udisks2: Dolphin lista/monta los discos extra (sda/sdb) sin fstab
    services.udisks2.enable = true;
    # Daemons runtime del dashboard de Wayle (red, bluetooth, batería)
    hardware.bluetooth.enable = true;
    services.upower.enable = true;
    # Brillo de monitores externos via DDC/CI (i2c) con ddcutil
    hardware.i2c.enable = true;
    services.udev.packages = [ pkgs.ddcutil ];
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
      mpvpaper
      cliphist
      (sddm-astronaut.override { embeddedTheme = "cyberpunk"; })
      wayle
      wl-clipboard
      swaylock-effects
      swayidle
      polkit_gnome
      brightnessctl
      ddcutil
    ];

    security.polkit.enable = true;
    # Montar/desbloquear discos (udisks2) sin pedir contraseña al usuario wheel
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel") &&
            (action.id == "org.freedesktop.udisks2.filesystem-mount" ||
             action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
             action.id == "org.freedesktop.udisks2.filesystem-unmount-others-seat" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
             action.id == "org.freedesktop.udisks2.encrypted-unlock-system" ||
             action.id == "org.freedesktop.udisks2.encrypted-lock")) {
          return polkit.Result.YES;
        }
      });
    '';

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

    systemd.user.services.swaylock = {
      description = "Swaylock - session lock";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.swaylock-effects}/bin/swaylock";
      };
      wantedBy = [ "lock.target" ];
    };
  };
}
