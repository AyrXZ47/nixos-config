{ config, pkgs, lib, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    xwayland.enable = true;
    systemd.enable = false;

    settings = {
      monitor = [
        "Virtual-1, 1920x1080@60, 0x0, 1"
        ", preferred, auto, 1"
      ];

      exec-once = [
        "wayle shell"
        "waybar"
        "${pkgs.awww}/bin/awww-daemon"
        "${pkgs.bash}/bin/bash -c 'sleep 1 && ${pkgs.awww}/bin/awww img $(${pkgs.coreutils}/bin/shuf -n1 -e ${../../assets/wallpapers}/*)'"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "dunst"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];

      exec = [
        "hyprctl setcursor Bibata-Modern-Classic 24"
      ];

      input = {
        kb_layout = "us,latam";
        kb_options = "grp:alt_shift_toggle";
        follow_mouse = 1;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
        sensitivity = 0.0;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = lib.mkForce "rgba(00f0ffee)";
        "col.inactive_border" = lib.mkForce "rgba(1a0b1cee)";
        layout = "dwindle";
      };

      decoration = {
        rounding = 12;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          new_optimizations = true;
          ignore_opacity = true;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 3;
          color = lib.mkForce "rgba(1a0b1cee)";
        };
      };

      layerrule = [
        "blur on, match:namespace wayle"
        "blur on, match:namespace rofi"
        "blur on, match:namespace wlogout"
        "ignore_alpha 0, match:namespace wayle"
        "ignore_alpha 0, match:namespace rofi"
        "ignore_alpha 0, match:namespace wlogout"
      ];

      animations = {
        enabled = true;
        bezier = [ "overshot, 0.05, 0.9, 0.1, 1.05" ];
        animation = [
          "windows, 1, 5, overshot, slide"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, overshot, slidevert"
        ];
      };

      dwindle = {
        preserve_split = true;
      };

      master = {
        new_status = "slave";
      };

      bind = [
        "SUPER, Backspace, exec, wezterm"
        "SUPER, A, exec, rofi -show drun -show-icons"
        "SUPER, Q, killactive"
        "SUPER, M, exit"
        "SUPER, V, togglefloating"
        "SUPER, R, exec, rofi -show run"
        "SUPER, J, layoutmsg, togglesplit"

        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"

        "SUPER SHIFT, left, movewindow, l"
        "SUPER SHIFT, right, movewindow, r"
        "SUPER SHIFT, up, movewindow, u"
        "SUPER SHIFT, down, movewindow, d"

        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER, 6, workspace, 6"
        "SUPER, 7, workspace, 7"
        "SUPER, 8, workspace, 8"
        "SUPER, 9, workspace, 9"

        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
        "SUPER SHIFT, 6, movetoworkspace, 6"
        "SUPER SHIFT, 7, movetoworkspace, 7"
        "SUPER SHIFT, 8, movetoworkspace, 8"
        "SUPER SHIFT, 9, movetoworkspace, 9"

        "SUPER SHIFT, E, exec, wlogout --protocol layer-shell"

        "SUPER, mouse_down, workspace, e+1"
        "SUPER, mouse_up, workspace, e-1"

        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86MonBrightnessUp, exec, brightnessctl s 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl s 10%-"
      ];

      bindel = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
      ];

      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];

      windowrule = [
        "match:class pavucontrol, float on"
        "match:class blueberry, float on"
        "match:title Volume Control, float on"
        "match:class imv, float on"
      ];
    };
  };

  programs.rofi = {
    enable = true;
    theme = lib.mkForce ./themes/rofi/launcher.rasi;
  };

  home.packages = with pkgs; [
    dunst
    hyprpaper
    swaylock-effects
    swayidle
    wlogout
    brightnessctl
    pavucontrol
    libnotify
    wl-clipboard
    hyprshot
    swayimg
    imv
    tree-sitter
    awww
    cliphist
    waybar
  ];

  xdg.configFile = {
    "wayle/config.toml" = {
      text = ''
        [bar]
        location = "top"
        exclusive = true
        layer = "top"
        rounding = "none"
        button-variant = "block-prefix"
        button-rounding = "sm"

        [[bar.layout]]
        monitor = "*"
        show = true
        left = ["hyprland-workspaces"]
        center = []
        right = ["systray"]

        [styling]
        theme-provider = "wayle"
        theming-monitor = ""

        [wallpaper]
        engine-enabled = false

        [osd]
        enabled = true
        position = "bottom"
        duration = 2500
      '';
    };
    "rofi/launcher.rasi" = {
      source = ./themes/rofi/launcher.rasi;
    };
    "wlogout/style.css" = {
      text = ''
        * {
          background-image: none;
          box-shadow: none;
        }

        window {
          background: rgba(20, 20, 30, 0.85);
        }

        button {
          border-radius: 12px;
          border-color: rgba(255, 255, 255, 0.1);
          border-width: 1px;
          background: rgba(30, 30, 44, 0.9);
          color: #cdd6f4;
          margin: 8px;
          padding: 12px 24px;
        }

        button:hover {
          background: rgba(0, 170, 255, 0.3);
          border-color: #00aaff;
        }
      '';
    };
    "waybar/config.jsonc" = {
      source = ./themes/waybar/config.jsonc;
    };
    "waybar/style.css" = {
      source = ./themes/waybar/style.css;
    };
  };

  xdg.mimeApps.enable = true;

  xdg.mimeApps.defaultApplications = {
    "image/avif" = "imv.desktop";
    "image/bmp" = "imv.desktop";
    "image/gif" = "imv.desktop";
    "image/jpeg" = "imv.desktop";
    "image/jpg" = "imv.desktop";
    "image/png" = "imv.desktop";
    "image/svg+xml" = "imv.desktop";
    "image/tiff" = "imv.desktop";
    "image/webp" = "imv.desktop";
    "image/x-bmp" = "imv.desktop";
    "image/x-portable-bitmap" = "imv.desktop";
    "image/x-portable-graymap" = "imv.desktop";
    "image/x-portable-pixmap" = "imv.desktop";
    "image/x-tga" = "imv.desktop";
    "image/x-xbitmap" = "imv.desktop";
    "image/x-xpixmap" = "imv.desktop";
  };

}
