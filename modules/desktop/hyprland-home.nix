{ config, pkgs, lib, ... }:

let
  adi1090x-src = pkgs.fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "512a585fff6da5b2a90e5948059b062516ddb2e7";
    hash = "sha256-iUX0Quae06tGd7gDgXZo1B3KYgPHU+ADPBrowHlv02A=";
  };
in
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
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];

      exec = [
        "hyprctl setcursor Bibata-Modern-Classic 24"
      ];

      input = {
        kb_layout = "us,latam";
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
        layout = "dwindle";
        "col.active_border" = "rgba(ff0066ff) rgba(00aaffff) 45deg";
        "col.inactive_border" = "rgba(1e1e3aff)";
      };

      decoration = {
        rounding = 12;
        blur = {
          enabled = true;
          size = 12;
          passes = 4;
          new_optimizations = true;
          ignore_opacity = true;
        };
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
        };
      };

      layerrule = [
        "blur, namespace:wayle"
        "blur, namespace:rofi"
        "ignorezero, namespace:wayle"
        "ignorezero, namespace:rofi"
      ];

      animations = {
        enabled = true;
        bezier = [
          "bounce, 0.05, 1.8, 0.2, 1.0"
          "overshot, 0.05, 0.9, 0.1, 1.05"
        ];
        animation = [
          "windows, 1, 6, bounce, slideright"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default, slidevert"
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

        "SUPER, T, exec, ${config.xdg.configHome}/hypr/scripts/time-to-work.sh"
        "SUPER, H, exec, ${config.xdg.configHome}/hypr/scripts/hypr-dev.sh"
        "SUPER, SPACE, exec, ${config.xdg.configHome}/hypr/scripts/switch-layout.sh"

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
    swaylock-effects
    swayidle
    brightnessctl
    pavucontrol
    libnotify
    wl-clipboard
    hyprshot
    swayimg
    imv
    tree-sitter
    cliphist
    awww
  ];

  xdg.configFile = {
    "hypr/scripts/time-to-work.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        hyprctl dispatch workspace 1
        mixxx &
        sleep 0.5
        hyprctl dispatch workspace 2
        obsidian &
        sleep 0.5
        hyprctl dispatch workspace 3
        firefox &
      '';
    };
    "hypr/scripts/hypr-dev.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        hyprctl dispatch exec "wezterm start -- zsh -ic nvim"
        sleep 0.6
        hyprctl dispatch layoutmsg orientationright
        sleep 0.1
        hyprctl dispatch exec "wezterm start -- zsh -ic 'headroom wrap opencode'"
        sleep 0.6
        hyprctl dispatch movefocus r
        sleep 0.1
        hyprctl dispatch layoutmsg orientationbottom
        sleep 0.1
        hyprctl dispatch exec "wezterm start -- zsh -ic 'headroom wrap aider --model ollama/qwen3.6:27b'"
        sleep 0.6
        hyprctl dispatch movefocus l
        sleep 0.1
        hyprctl dispatch layoutmsg orientationbottom
        sleep 0.1
        hyprctl dispatch exec "wezterm start"
        sleep 0.6
        hyprctl dispatch movefocus r
        sleep 0.1
        hyprctl dispatch movefocus d
        sleep 0.1
        hyprctl dispatch layoutmsg orientationbottom
        sleep 0.1
        hyprctl dispatch exec "wezterm start -- zsh -ic 'pipes-rs'"
        sleep 0.6
        hyprctl dispatch movefocus r
        sleep 0.1
        hyprctl dispatch layoutmsg orientationright
        sleep 0.1
        hyprctl dispatch exec "wezterm start -- zsh -ic 'cava'"
      '';
    };
    "hypr/scripts/wallpaper-cycle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        find ${../../assets/wallpapers} -type f | shuf -n1 | xargs -r awww img
      '';
    };
    "hypr/scripts/switch-layout.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        hyprctl switchxkblayout
        layout=$(hyprctl getoption input:kb_layout | sed -n 's/.*str: *//p' | cut -d, -f1)
        notify-send -t 2000 -a layout -u low "$layout"
      '';
    };

    "rofi/launcher.rasi" = {
      source = ./themes/rofi/launcher.rasi;
    };
    "rofi/launchers".source = "${adi1090x-src}/files/launchers";
    "rofi/colors".source = "${adi1090x-src}/files/colors";
    "rofi/applets".source = "${adi1090x-src}/files/applets";
    "rofi/powermenu".source = "${adi1090x-src}/files/powermenu";
    "rofi/scripts".source = "${adi1090x-src}/files/scripts";
    "rofi/fonts".source = "${adi1090x-src}/fonts";
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
