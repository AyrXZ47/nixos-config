{ config, pkgs, lib, ... }:

let
  adi1090x-src = pkgs.fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "512a585fff6da5b2a90e5948059b062516ddb2e7";
    hash = "sha256-iUX0Quae06tGd7gDgXZo1B3KYgPHU+ADPBrowHlv02A=";
  };
  wallpapersDir = ../../assets/wallpapers;

  # Autoscroll estilo navegador con click medio: libinput on_button_down no
  # funciona en ratones con rueda, así que se usa este plugin (ABI contra la
  # misma version de Hyprland del flake). Con direct_activation el click medio
  # hace autoscroll siempre; SUPER+A alterna al modo normal.
  hypr-autoscroll = pkgs.stdenv.mkDerivation {
    pname = "hypr-autoscroll";
    version = "unstable-2026-07-25";
    src = pkgs.fetchFromGitHub {
      owner = "estebanhiram";
      repo = "hypr-autoscroll";
      rev = "301508bf19d2bd29993a0fca32b4b8abcf64aabb";
      hash = "sha256-0tr35AEm24ertylt+g6TCjDADRp4yQpeu6j+vNO77Uc=";
    };
    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.hyprland ] ++ pkgs.hyprland.buildInputs;
    buildPhase = ''
      runHook preBuild
      make clean all
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp build/hypr-autoscroll.so $out/lib/libhypr-autoscroll.so
      runHook postInstall
    '';
    meta = {
      description = "Autoscroll de click medio estilo navegador para Hyprland";
      homepage = "https://github.com/estebanhiram/hypr-autoscroll";
      license = pkgs.lib.licenses.bsd3;
      platforms = pkgs.lib.platforms.linux;
    };
  };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    plugins = [ hypr-autoscroll ];
    xwayland.enable = true;
    systemd.enable = false;

    settings = {
      monitor = [
        "Virtual-1, 1920x1080@60, 0x0, 1"
        ", preferred, auto, 1"
      ];

      exec-once = [
        "wayle shell"
        "${config.xdg.configHome}/hypr/scripts/wallpaper-set.sh"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];

      exec = [
        "hyprctl setcursor Bibata-Modern-Classic 24"
      ];

      input = {
        kb_layout = "latam,us";
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
        "col.active_border" = "rgba(ff0066ff) rgba(9900ffff) rgba(00aaffff) 45deg";
        "col.inactive_border" = "rgba(1e1e3aff)";
      };

      decoration = {
        rounding = 12;
        active_opacity = 0.8;
        inactive_opacity = 0.75;
        blur = {
          enabled = true;
          size = 12;
          passes = 3;
          ignore_opacity = true;
        };
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
        };
      };

      render = {
        use_fp16 = 0;
      };

      layerrule = [
        "blur on, ignore_alpha 1, match:namespace wayle"
        "blur on, ignore_alpha 1, match:namespace rofi"
      ];

      animations = {
        enabled = true;
        bezier = [
          "bounce, 0.05, 1.8, 0.2, 1.0"
          "overshot, 0.05, 0.9, 0.1, 1.05"
        ];
        animation = [
          "windows, 1, 6, overshot, slideright"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, bounce, slidevert"
        ];
      };

      dwindle = {
        preserve_split = true;
      };

      master = {
        new_status = "slave";
      };

      misc = {
        disable_xdg_env_checks = true;
      };

      plugin.hypr_autoscroll = {
        enabled = true;
        direct_activation = true;
      };

      bindd = [
        "SUPER, A, Toggle middle-button autoscroll, hypr-autoscroll:middle-mode, toggle"
      ];

      bind = [
        "SUPER, Backspace, exec, wezterm"
        "SUPER, A, exec, rofi -show drun -show-icons"
        "SUPER, Delete, killactive"
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
        "SUPER, L, exec, loginctl lock-session"

        "SUPER, mouse_down, workspace, e+1"
        "SUPER, mouse_up, workspace, e-1"

        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ", XF86MonBrightnessUp, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh up"
        ", XF86MonBrightnessDown, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh down"
        "SUPER, F12, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh up"
        "SUPER, F11, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh down"
        "SUPER, XF86AudioRaiseVolume, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh up"
        "SUPER, XF86AudioLowerVolume, exec, ${config.xdg.configHome}/hypr/scripts/brightness.sh down"
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
        "match:class org.wezfurlong.wezterm, opacity 1 1 1"
        "match:class steam, no_blur on, opacity 1 1 1"
        "match:class steam_app_.*, no_blur on, opacity 1 1 1"
        "match:class gamescope, no_blur on, opacity 1 1 1"
      ];
    };
  };

  programs.rofi = {
    enable = true;
    extraConfig = {
      display-drun = "";
      display-run = "";
      display-filebrowser = "";
      display-window = "";
      drun-display-format = "{name}";
      show-icons = true;
    };
    theme = lib.mkForce "~/.config/rofi/cyberpunk.rasi";
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
    setxkbmap
  ];

  # cliphist: limite de historial en 18 items (config file, default 750).
  xdg.configFile."cliphist/config".text = "max-items 18\n";

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
    "hypr/scripts/brightness.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # ponytail: panel interno (portatil) via brightnessctl; monitor externo
        # via DDC/CI (ddcutil sobre i2c). El detect en cada llamada re-escaneaba
        # todos los buses i2c y decenas de procesos peleaban el flock -> journal
        # lleno y delays de minutos; por eso ahora se decide por /sys/class/backlight
        # (chequeo barato) y se serializa con flock. "down" usa "10 - 5" (con
        # espacio): "10 -5" lo traga getopt como opcion y no hace nada.
        # Ceiling: si el monitor externo no implementa DDC/CI, setvcp falla.
        if ls /sys/class/backlight/*/brightness >/dev/null 2>&1; then
          case "$1" in
            up) brightnessctl s +10% ;;
            down) brightnessctl s 10%- ;;
          esac
        else
          lock=/tmp/ddcutil-brightness.lock
          case "$1" in
            up)   exec flock -w 1 "$lock" ddcutil setvcp 10 + 5 ;;
            down) exec flock -w 1 "$lock" ddcutil setvcp 10 - 5 ;;
          esac
        fi
      '';
    };
    "hypr/scripts/wallpaper-set.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        dir="${wallpapersDir}"
        f="$1"
        if [ -z "$f" ]; then
          f=$(find "$dir" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.webm' -o -name '*.mkv' \) 2>/dev/null | shuf -n1)
          [ -z "$f" ] && f=$(find "$dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) 2>/dev/null | shuf -n1)
        fi
        [ -z "$f" ] && exit 0
        pkill -x .mpvpaper-wrapp 2>/dev/null
        sleep 0.2
        mpvpaper -f -o "no-audio
loop-file=inf" ALL "$f"
      '';
    };
    "hypr/scripts/wallpaper-cycle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec ~/.config/hypr/scripts/wallpaper-set.sh
      '';
    };
    "hypr/scripts/wallpaper-menu.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        dir="${wallpapersDir}"
        set="$HOME/.config/hypr/scripts/wallpaper-set.sh"
        action=$(printf "Next wallpaper\nSet wallpaper" | rofi -dmenu -p "Wallpaper" -theme-str 'window {width: 300px;} listview {lines: 2; columns: 1;} element-icon {size: 0px;}')
        [ -z "$action" ] && exit 0
        case "$action" in
          "Next wallpaper")
            "$set"
            ;;
          "Set wallpaper")
            pick=$(find "$dir" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.webm' -o -name '*.mkv' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) | sort | while read f; do basename "$f"; done | rofi -dmenu -p "wallpaper" -theme-str 'window {width: 600px;} listview {lines: 15; columns: 1;} element-icon {size: 0px;}')
            [ -z "$pick" ] && exit 0
            "$set" "$dir/$pick"
            ;;
        esac
      '';
    };
    # Bloqueo: swaylock al instante y, en paralelo, el hook de OpenRGB aplica el
    # perfil "apagado"; al desbloquear restaura el perfil normal. Los hooks solo
    # corren si el módulo openrgb está activo (el `[ -x ... ]` lo decide).
    "hypr/scripts/lock.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        swaylock &
        _swaylock_pid=$!
        [ -x "$HOME/.local/bin/openrgb-lock-before" ] && "$HOME/.local/bin/openrgb-lock-before"
        wait "$_swaylock_pid"
        [ -x "$HOME/.local/bin/openrgb-lock-after" ] && "$HOME/.local/bin/openrgb-lock-after"
      '';
    };
    "hypr/scripts/switch-layout.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        if command -v hyprctl >/dev/null 2>&1; then
          dev=$(hyprctl devices | awk '/^\t\t[a-zA-Z0-9._-]+$/{d=$1} /main: yes/{print d}' | tail -1)
          [ -n "$dev" ] && hyprctl switchxkblayout "$dev" next
          sleep 0.1
          layout=$(hyprctl devices | awk '/active keymap: /{km=$0} /main: yes/{print km}' | tail -1 | sed 's/.*active keymap: //')
        else
          current=$(setxkbmap -query 2>/dev/null | grep '^layout' | awk '{print $2}')
          if [ "$current" = "latam" ]; then
            setxkbmap us
            layout="us"
          else
            setxkbmap latam
            layout="latam"
          fi
        fi
        [ -n "$layout" ] && notify-send -t 2000 -a layout -u low " $layout"
      '';
    };

    "rofi/launcher.rasi" = {
      source = ./themes/rofi/launcher.rasi;
    };
    "rofi/cyberpunk.rasi".text = ''
      @theme "launchers/type-7/style-6"

      * {
          background:     #000B1E;
          background-alt: #0A1528;
          foreground:     #0ABDC6;
          selected:       #0ABDC6;
          active:         #00FF00;
          urgent:         #FF0000;
      }

      window {
          transparency: "real";
          background-color: rgba(0, 11, 30, 0.66);
      }
    '';
    "rofi/launchers".source = "${adi1090x-src}/files/launchers";
    "rofi/colors".source = "${adi1090x-src}/files/colors";
    "rofi/applets".source = "${adi1090x-src}/files/applets";
    "rofi/powermenu".source = "${adi1090x-src}/files/powermenu";
    "rofi/scripts".source = "${adi1090x-src}/files/scripts";
    "rofi/fonts".source = "${adi1090x-src}/fonts";
  };

  xdg.mimeApps.enable = false;

  # xdg.mimeApps genera un symlink read-only al store; Dolphin no puede
  # guardar "abrir con" ahí. Se siembra un archivo real escribible una sola vez
  # (si ya existe, KDE conserva sus asociaciones manuales entre switches).
  home.activation.materializeMimeapps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/mimeapps.list"
    if [ ! -f "$f" ]; then
      cat > "$f" <<EOF
[Default Applications]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
image/avif=imv.desktop
image/bmp=imv.desktop
image/gif=imv.desktop
image/jpeg=imv.desktop
image/jpg=imv.desktop
image/png=imv.desktop
image/svg+xml=imv.desktop
image/tiff=imv.desktop
image/webp=imv.desktop
image/x-bmp=imv.desktop
image/x-portable-bitmap=imv.desktop
image/x-portable-graymap=imv.desktop
image/x-portable-pixmap=imv.desktop
image/x-tga=imv.desktop
image/x-xbitmap=imv.desktop
image/x-xpixmap=imv.desktop
application/x-keepass2=org.keepassxc.KeePassXC.desktop
EOF
    fi
  '';

}
