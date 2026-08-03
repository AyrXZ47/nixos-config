{ config, pkgs, lib, ... }:

let
  adi1090x-src = pkgs.fetchFromGitHub {
    owner = "adi1090x";
    repo = "rofi";
    rev = "512a585fff6da5b2a90e5948059b062516ddb2e7";
    hash = "sha256-iUX0Quae06tGd7gDgXZo1B3KYgPHU+ADPBrowHlv02A=";
  };
  wallpapersDir = ../../assets/wallpapers;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    # Lua config (hyprland.lua): hyprlang se depreca en Hyprland 0.57.
    configType = "lua";
    xwayland.enable = true;
    systemd.enable = false;

    extraConfig = ''
      -- Configuración Hyprland (lua) — generada por Home Manager.
      -- https://wiki.hypr.land/Configuring/Start/

      ------------------
      ---- MONITORES ----
      ------------------
      hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = "1" })
      -- PC: DP-1 a máx res / máx refresco (170 Hz); el catch-all "preferred" elige 60.
      hl.monitor({ output = "DP-1", mode = "1920x1080@170", position = "auto", scale = "1" })
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "1" })

      ------------------
      ---- AUTOSTART ----
      ------------------
      hl.on("hyprland.start", function()
        hl.exec_cmd("wayle shell")
        hl.exec_cmd("${config.xdg.configHome}/hypr/scripts/wallpaper-set.sh")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
        hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("${config.xdg.configHome}/hypr/scripts/idle.sh")
        hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
      end)

      ------------------------
      ---- LOOK AND FEEL ----
      ------------------------
      hl.config({
        general = {
          gaps_in = 5,
          gaps_out = 10,
          border_size = 2,
          layout = "dwindle",
          col = {
            active_border = { colors = { "rgba(ff0066ff)", "rgba(9900ffff)", "rgba(00aaffff)" }, angle = 45 },
            inactive_border = "rgba(1e1e3aff)",
          },
        },

        decoration = {
          rounding = 12,
          -- Vidrio esmerilado con opacidad media: blur intacto pero el contenido
          -- (texto/video) queda legible. Steam, wezterm y reproductores quedan
          -- exentos via reglas (opacity "N override" fuerza opacidad absoluta).
          active_opacity = 0.8,
          inactive_opacity = 0.7,
          blur = {
            enabled = true,
            size = 16,
            passes = 4,
            ignore_opacity = true,
          },
          shadow = {
            enabled = true,
            range = 12,
            render_power = 3,
          },
        },

        -- Teclado: latam/us (switchxkblayout cicla entre estas). El bloque input
        -- se perdió en la migración a Lua y sin kb_layout el switch no tenía nada
        -- que alternar.
        input = {
          kb_layout = "latam,us",
          follow_mouse = 1,
          touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
          },
          sensitivity = 0.0,
        },

        render = {
          use_fp16 = 0,
        },

        dwindle = {
          preserve_split = true,
        },

        master = {
          new_status = "slave",
        },

        misc = {
          disable_xdg_env_checks = true,
        },
      })

      ------------------------
      ---- ANIMACIONES -------
      ------------------------
      hl.curve("bounce", { type = "bezier", points = { {0.05, 1.8}, {0.2, 1.0} } })
      hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

      hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "overshot", style = "slideright" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
      hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
      hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "bounce", style = "slidevert" })

      -----------------------
      ---- WINDOW RULES -----
      -----------------------
      hl.window_rule({ name = "pavucontrol-float", match = { class = "pavucontrol" }, float = true })
      hl.window_rule({ name = "blueberry-float", match = { class = "blueberry" }, float = true })
      hl.window_rule({ name = "volume-float", match = { title = "Volume Control" }, float = true })
      hl.window_rule({ name = "imv-float", match = { class = "imv" }, float = true })
      -- wezterm: transparencia propia (window_background_opacity) sin blur del compositor.
      -- opacity "1 override": fuerza 1.0 absoluto (el multiplicador daría 1.0*0.75).
      hl.window_rule({ name = "wezterm-solid", match = { class = "org.wezfurlong.wezterm" }, no_blur = true, opacity = "1 override" })
      -- steam: exento de blur y transparencia (opacidad total).
      hl.window_rule({ name = "steam-solid", match = { class = "steam" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "steam-app-solid", match = { class = "steam_app_.*" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "gamescope-solid", match = { class = "gamescope" }, no_blur = true, opacity = "1 override" })
      -- Reproductores de video: sólidos (no se lava el contenido) y sin blur para que
      -- el compositor no re-borronee el fondo en cada frame del video.
      hl.window_rule({ name = "mpv-solid", match = { class = "mpv" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "celluloid-solid", match = { class = "io.github.celluloid_player.Celluloid" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "vlc-solid", match = { class = "vlc" }, no_blur = true, opacity = "1 override" })

      -----------------------
      ---- LAYER RULES ------
      -----------------------
      hl.layer_rule({ name = "wayle-blur", match = { namespace = "wayle" }, blur = true, ignore_alpha = 1 })

      -----------------------
      ---- KEYBINDINGS ------
      -----------------------
      hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("wezterm"))
      hl.bind("SUPER + A", hl.dsp.exec_cmd("rofi -show drun -show-icons"))
      hl.bind("SUPER + Delete", hl.dsp.window.close())
      hl.bind("SUPER + M", hl.dsp.exit())
      hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
      hl.bind("SUPER + R", hl.dsp.exec_cmd("rofi -show run"))
      hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))

      hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
      hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
      hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
      hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))

      hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
      hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
      hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

      for i = 1, 9 do
        hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = i }))
        hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
      end

      hl.bind("SUPER + W", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/time-to-work.sh"))
      hl.bind("SUPER + N", hl.dsp.exec_cmd("wezterm start -- zsh -ic netrunner"))
      hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/switch-layout.sh"))
      hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))

      -- Screenshots (región / ventana / pantalla)
      hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))
      hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/Screenshots"))
      hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprshot -m output -o ~/Pictures/Screenshots"))

      hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

      -- Deslizarse entre escritorios como GNOME (la animación slidevert está arriba).
      hl.bind("SUPER + ALT + up", hl.dsp.focus({ workspace = "-1" }))
      hl.bind("SUPER + ALT + down", hl.dsp.focus({ workspace = "+1" }))

      -- Ratón: LMB arrastra (mover), RMB redimensiona (sin estos binds el config
      -- sobreescribe los defaults de Hyprland).
      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Multimedia: volumen, micrófono y brillo (repeat + locked = bindel/bindl legacy)
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh up"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh down"), { locked = true, repeating = true })
      hl.bind("SUPER + F12", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh up"))
      hl.bind("SUPER + F11", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh down"))
      hl.bind("SUPER + XF86AudioRaiseVolume", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh up"))
      hl.bind("SUPER + XF86AudioLowerVolume", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/brightness.sh down"))

      -----------------------
      ---- GESTOS -----------
      -----------------------
      -- Trackpad: 3 dedos en horizontal = cambiar de escritorio.
      -- API nueva (Hyprland 0.51+): hl.gesture; las claves gestures:workspace_swipe
      -- quedaron deprecadas/eliminadas.
      hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    '';
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
        # Con config Lua, "hyprctl dispatch exec [workspace N]" ya no se parsea
        # (error: ']' expected); la regla de workspace se pasa como 2º argumento
        # del dispatcher hl.dsp.exec_cmd. La regla sigue forzando la apertura en
        # ese escritorio aunque la app tarde en mapear su ventana.
        hyprctl dispatch 'hl.dsp.exec_cmd("mixxx", { workspace = 1 })'
        hyprctl dispatch 'hl.dsp.exec_cmd("obsidian", { workspace = 2 })'
        hyprctl dispatch 'hl.dsp.exec_cmd("firefox", { workspace = 3 })'
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
        # hwdec=vaapi: descodifica el video en la GPU (VCN/Radeon), no en la CPU.
        # Sin esto el fondo animado costaba ~274% de CPU en la laptop. -p pausa el
        # video cuando lo tapa una ventana (ahorra CPU/batería).
        mpvpaper -f -p -o "no-audio
loop-file=inf
hwdec=vaapi" ALL "$f"
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
    # swayidle escucha las señales de logind: loginctl lock-session (SUPER+L y el
    # dropdown de wayle) SOLO emite la señal D-Bus Lock, nadie la procesaba y el
    # systemd.user.services.swaylock (wantedBy lock.target) jamás arrancaba.
    # Aquí se ejecuta lock.sh al recibir Lock y antes de dormir.
    "hypr/scripts/idle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec swayidle -w \
          lock "$HOME/.config/hypr/scripts/lock.sh" \
          before-sleep "$HOME/.config/hypr/scripts/lock.sh"
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
      @theme "launchers/type-3/style-1"

      * {
          background:     #000B1E;
          background-alt: #0A1528;
          foreground:     #0ABDC6;
          selected:       #0ABDC6;
          active:         #00FF00;
          urgent:         #FF0000;
      }

      window {
          background-color: #000B1E;
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
