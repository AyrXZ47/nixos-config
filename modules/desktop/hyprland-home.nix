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
    # systemd.enable: sin la integración, graphical-session.target nunca se
    # activa y xdg-desktop-portal (Requisite=graphical-session.target desde
    # portal 1.22) no puede arrancar -> file dialogs/portales rotos tras el
    # bump de nixpkgs (el 1.20 usaba Requires=dbus.service). El target
    # hyprland-session de HM activa graphical-session.target al iniciar la
    # sesión.
    systemd.enable = true;

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
        -- qpwgraph demonio: minimizado en el tray y aplicando el patchbay
        -- guardado. Ambas cosas son ajustes nativos de qpwgraph: "Start minimized
        -- to system tray" (Options) y guardar el patchbay activado una sola vez
        -- (File > Save Patchbay As); al arrancar restaura el último archivo. Para
        -- editar rutas se lanza qpwgraph de nuevo (instancia unica -> muestra la UI).
        hl.exec_cmd("qpwgraph")
        hl.exec_cmd("${config.xdg.configHome}/hypr/scripts/wallpaper-set.sh")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
        hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        -- kdeconnect como daemon de fondo (el autostart XDG de kdeconnect solo
        -- se lanza en sesiones Plasma; en Hyprland hay que arrancarlo a mano).
        hl.exec_cmd("kdeconnectd")
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

        -- Pantalla tactil: deslizar desde el borde lateral de la pantalla cambia
        -- de workspace (equivalente al swipe de 3 dedos de GNOME en la pantalla).
        gestures = {
          workspace_swipe_touch = true,
        },

        render = {
          -- fp16: la mitad de bandwidth de composicion; clave para sostener
          -- 170Hz + blur. El 0 previo (fp32) no tenia comentario que lo justifique.
          use_fp16 = 1,
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

      -------------------------
      ---- AUTOSCROLL MOUSE ----
      -------------------------
      -- Botón central + mover = scroll (estilo trackpoint), nativo de libinput.
      -- Reemplaza a wayland-wheeltani (que grababa el dispositivo y no
      -- funcionaba). El dongle 2.4G expone dos nodos de puntero; se cubren
      -- ambos (los que no matcheen se ignoran).
      hl.device({ name = "2.4g-dongle-1", scroll_method = "on_button_down", scroll_button = 2 })
      hl.device({ name = "2.4g-mouse", scroll_method = "on_button_down", scroll_button = 2 })

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
      -- kdeconnect presenter ("Presentation remote" del celular): ventana fullscreen
      -- transparente; con blur (ignore_opacity=true) se veia como un panel opaco
      -- borroso que tapa el escritorio. Sin blur solo queda el puntero dibujado.
      hl.window_rule({ name = "kdeconnect-presenter", match = { class = "org.kde.kdeconnect" }, no_blur = true })

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
      -- Pin = always on top + visible en todos los workspaces (requiere ventana flotante).
      hl.bind("SUPER + T", hl.dsp.window.pin({ action = "toggle" }))
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
      -- SUPER+P = captura inmediata del monitor activo sin interacción. "hyprshot
      -- -m output" a secas usa slurp -or (pide arrastrar/click); "-m active -m
      -- output" resuelve el monitor por hyprctl y captura al instante.
      hl.bind("SUPER + P", hl.dsp.exec_cmd("hyprshot -m active -m output -o ~/Pictures/Screenshots"))

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

      -- Control de reproducción: wayle media usa MPRIS, así que SUPER+F7 pausa
      -- lo que sea que esté sonando (YouTube/Firefox, VLC, mpv...). El `|| mpc`
      -- es el fallback para MPD cuando no hay reproductor MPRIS activo.
      hl.bind("SUPER + F7", hl.dsp.exec_cmd("wayle media play-pause || mpc toggle"))
      hl.bind("SUPER + F6", hl.dsp.exec_cmd("wayle media previous || mpc prev"))
      hl.bind("SUPER + F8", hl.dsp.exec_cmd("wayle media next || mpc next"))

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
    hyprlock
    hypridle
    brightnessctl
    pavucontrol
    libnotify
    wl-clipboard
    hyprshot
    imv
    tree-sitter
    cliphist
    setxkbmap
    # CLI de self-test de inyeccion de input (--self-test-motion/absolute/scroll)
    hypr-kdeconnect-fix
  ];

  # --- Remote input de KDE Connect (portal RemoteDesktop) ---
  # kdeconnect en Wayland inyecta teclado/raton llamando a org.freedesktop.portal.RemoteDesktop;
  # sin un backend que lo implemente ("Remote input" del celular no hace nada). wlr y gtk no lo
  # tienen y xdg-desktop-portal-hyprland tampoco (solo ScreenCast/Screenshot/GlobalShortcuts/
  # InputCapture). hypr-kdeconnect-fix (flake.nix) expone esa interfaz y reenvia los eventos a
  # zwlr_virtual_pointer/zwp_virtual_keyboard, que Hyprland si expone. El backend arranca por
  # activacion D-Bus (el unit Type=dbus de abajo) cuando kdeconnect lo pide; para entonces el
  # entorno de la sesion (WAYLAND_DISPLAY) ya esta en el manager de systemd.
  xdg.configFile."xdg-desktop-portal/portals.conf".text = ''
    [preferred]
    org.freedesktop.impl.portal.RemoteDesktop=hypr-kdeconnect
  '';
  # Metadata del portal: el frontend escanea $XDG_DATA_HOME/xdg-desktop-portal/portals/.
  xdg.dataFile."xdg-desktop-portal/portals/hypr-kdeconnect.portal".text = ''
    [portal]
    DBusName=org.freedesktop.impl.portal.desktop.hypr_kdeconnect
    Interfaces=org.freedesktop.impl.portal.RemoteDesktop;
    UseIn=Hyprland;
  '';
  # Activacion D-Bus de usuario (dbus-broker en NixOS): systemd arranca el unit al recibir
  # la primera llamada RemoteDesktop.
  xdg.dataFile."dbus-1/services/org.freedesktop.impl.portal.desktop.hypr_kdeconnect.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.impl.portal.desktop.hypr_kdeconnect
    Exec=${pkgs.hypr-kdeconnect-fix}/bin/hypr-kdeconnect-portal
    SystemdService=hypr-kdeconnect-portal.service
  '';
  systemd.user.services.hypr-kdeconnect-portal = {
    Unit = {
      Description = "KDE Connect RemoteDesktop portal backend (hypr-kdeconnect-fix)";
      PartOf = [ "xdg-desktop-portal.service" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.impl.portal.desktop.hypr_kdeconnect";
      ExecStart = "${pkgs.hypr-kdeconnect-fix}/bin/hypr-kdeconnect-portal";
      Restart = "on-failure";
      RestartSec = "1s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      RestrictSUIDSGID = true;
      RestrictAddressFamilies = [ "AF_UNIX" ];
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
    };
  };

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
    # Bloqueo: hyprlock al instante y, en paralelo, el hook de OpenRGB aplica el
    # perfil "apagado"; al desbloquear restaura el perfil normal. Los hooks solo
    # corren si el módulo openrgb está activo (el `[ -x ... ]` lo decide).
    "hypr/scripts/lock.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        hyprlock &
        _hyprlock_pid=$!
        [ -x "$HOME/.local/bin/openrgb-lock-before" ] && "$HOME/.local/bin/openrgb-lock-before"
        wait "$_hyprlock_pid"
        [ -x "$HOME/.local/bin/openrgb-lock-after" ] && "$HOME/.local/bin/openrgb-lock-after"
      '';
    };
    # hypridle (daemon de idle nativo de Hyprland) escucha las señales de logind:
    # loginctl lock-session (SUPER+L y el dropdown de wayle) emite la señal D-Bus
    # Lock y hypridle corre lock_cmd (lock.sh → hyprlock). No hay listeners de
    # inactividad: solo se bloquea manual o antes de dormir.
    "hypr/scripts/idle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec hypridle
      '';
    };
    "hypr/hypridle.conf".text = ''
      general {
          lock_cmd = pidof hyprlock || ${config.xdg.configHome}/hypr/scripts/lock.sh
          before_sleep_cmd = loginctl lock-session
      }
    '';

    # hyprlock: la config debe existir o hyprlock sale con error y la sesión NO se
    # bloquea. Autenticación: PAM (contraseña, vía security.pam.services.hyprlock)
    # y huella nativa por fprintd (auth fingerprint:enabled), en paralelo.
    # background path=screenshot usa screencopy de Hyprland; el color es solo el
    # fallback (algunos lockers daban pantalla blanca con screenshot; no aplica).
    "hypr/hyprlock.conf".text = ''
      general {
          hide_cursor = true
          immediate_render = true
      }

      background {
          path = screenshot
          color = rgb(10, 10, 18)
          blur_passes = 3
          blur_size = 8
          contrast = 0.9
          brightness = 0.8
      }

      auth {
          pam:enabled = true
          fingerprint:enabled = true
      }

      input-field {
          size = 360, 60
          position = 0, -100
          outline_thickness = 3
          dots_size = 0.2
          dots_spacing = 0.2
          dots_center = true
          outer_color = rgb(255, 0, 102)
          inner_color = rgb(10, 10, 18)
          font_color = rgb(212, 212, 240)
          fade_on_empty = false
          placeholder_text = Password
          fail_text = $FAIL
          check_color = rgb(0, 255, 136)
          fail_color = rgb(255, 0, 64)
          rounding = 8
      }

      label {
          text = cmd[update:1000] echo "$(date +'%H:%M')"
          color = rgb(255, 0, 102)
          font_size = 44
          font_family = "JetBrains Mono"
          position = 0, 120
          halign = center
          valign = center
      }

      label {
          text = $FPRINTPROMPT
          color = rgb(136, 136, 170)
          font_size = 13
          position = 0, -170
          halign = center
          valign = center
      }
    '';
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
  # guardar "abrir con" ahí. Se siembra un archivo real escribible (si ya
  # existe y no tiene ids rotos, KDE conserva sus asociaciones manuales).
  #
  # imv upstream declara su .desktop con NoDisplay=true: KDE no lo ofrece en
  # el diálogo "abrir con" (obliga a "browse" a un binario, que genera stubs
  # NoDisplay que KDE descarta al resolver el default y re-pregunta siempre).
  # Se sobreescribe con una entrada visible que sombrea la del perfil.
  xdg.desktopEntries.imv = {
    name = "imv";
    exec = "imv %F";
    type = "Application";
    icon = "multimedia-photo-viewer";
    mimeType = [
      "image/avif"
      "image/bmp"
      "image/gif"
      "image/heif"
      "image/jpeg"
      "image/jpg"
      "image/png"
      "image/svg+xml"
      "image/tiff"
      "image/webp"
      "image/x-bmp"
      "image/x-portable-bitmap"
      "image/x-portable-graymap"
      "image/x-portable-pixmap"
      "image/x-tga"
      "image/x-xbitmap"
      "image/x-xpixmap"
    ];
  };

  # nvim no trae .desktop (nixpkgs no lo empaqueta): sin él, los defaults de
  # texto del seed (text/plain=nvim.desktop, etc.) apuntan a nada y Dolphin
  # vuelve a preguntar. Mismo truco que imv: entrada visible en el perfil.
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    exec = "nvim %F";
    type = "Application";
    terminal = true;
    icon = "utilities-terminal";
    categories = [ "Utility" "TextEditor" ];
    mimeType = [
      "text/plain"
      "text/markdown"
      "text/x-log"
      "application/json"
      "application/xml"
      "text/xml"
      "application/yaml"
      "application/x-subrip"
      "text/vtt"
      "text/csv"
    ];
  };

  home.activation.materializeMimeapps = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/mimeapps.list"
    write_seed() {
      cat > "$1" <<EOF
[Default Applications]
application/pdf=org.kde.okular.desktop
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
image/avif=imv.desktop
image/bmp=imv.desktop
image/gif=imv.desktop
image/heif=imv.desktop
image/jpeg=imv.desktop
image/jpg=imv.desktop
image/png=imv.desktop
image/svg+xml=org.inkscape.Inkscape.desktop
image/tiff=imv.desktop
image/webp=imv.desktop
image/x-bmp=imv.desktop
image/x-portable-bitmap=imv.desktop
image/x-portable-graymap=imv.desktop
image/x-portable-pixmap=imv.desktop
image/x-tga=imv.desktop
image/x-xbitmap=imv.desktop
image/x-xpixmap=imv.desktop
text/plain=nvim.desktop
application/x-keepass2=org.keepassxc.KeePassXC.desktop
audio/mpeg=vlc.desktop
audio/flac=vlc.desktop
audio/ogg=vlc.desktop
audio/wav=vlc.desktop
audio/mp4=vlc.desktop
audio/opus=vlc.desktop
audio/aac=vlc.desktop
audio/x-m4a=vlc.desktop
video/mp4=vlc.desktop
video/webm=vlc.desktop
video/quicktime=vlc.desktop
video/x-matroska=vlc.desktop
video/3gpp=vlc.desktop
video/x-msvideo=vlc.desktop
video/avi=vlc.desktop
application/zip=org.kde.ark.desktop
application/x-7z-compressed=org.kde.ark.desktop
application/x-rar=org.kde.ark.desktop
application/gzip=org.kde.ark.desktop
application/x-tar=org.kde.ark.desktop
application/x-xz=org.kde.ark.desktop
application/x-bzip2=org.kde.ark.desktop
# Office -> LibreOffice
application/msword=writer.desktop
application/vnd.ms-word=writer.desktop
application/vnd.openxmlformats-officedocument.wordprocessingml.document=writer.desktop
application/vnd.openxmlformats-officedocument.wordprocessingml.template=writer.desktop
application/vnd.oasis.opendocument.text=writer.desktop
application/vnd.oasis.opendocument.text-template=writer.desktop
application/rtf=writer.desktop
application/vnd.ms-excel=calc.desktop
application/vnd.openxmlformats-officedocument.spreadsheetml.sheet=calc.desktop
application/vnd.openxmlformats-officedocument.spreadsheetml.template=calc.desktop
application/vnd.oasis.opendocument.spreadsheet=calc.desktop
application/vnd.oasis.opendocument.spreadsheet-template=calc.desktop
application/vnd.ms-powerpoint=impress.desktop
application/vnd.openxmlformats-officedocument.presentationml.presentation=impress.desktop
application/vnd.openxmlformats-officedocument.presentationml.template=impress.desktop
application/vnd.oasis.opendocument.presentation=impress.desktop
# Texto/codigo -> nvim (tipos reales: .md->text/markdown, .sh->application/x-shellscript,
# .py->text/x-python, .yml->application/yaml, .srt->application/x-subrip, .vtt->text/vtt)
text/markdown=nvim.desktop
application/json=nvim.desktop
application/xml=nvim.desktop
text/xml=nvim.desktop
application/yaml=nvim.desktop
application/x-shellscript=nvim.desktop
text/x-python=nvim.desktop
text/x-c=nvim.desktop
text/x-c++src=nvim.desktop
text/x-tex=nvim.desktop
text/x-log=nvim.desktop
text/calendar=nvim.desktop
application/x-subrip=nvim.desktop
text/vtt=nvim.desktop
text/csv=nvim.desktop
# Ebooks -> okular
application/epub+zip=okularApplication_epub.desktop
application/x-mobipocket-ebook=okularApplication_mobi.desktop
application/x-fictionbook+xml=okularApplication_fb.desktop
application/x-cbz=okularApplication_comicbook.desktop
application/vnd.comicbook-rar=okularApplication_comicbook.desktop
application/postscript=okularApplication_ghostview.desktop
application/x-dvi=okularApplication_dvi.desktop
# Audio/video extra -> vlc (del celular, descargas y rips)
audio/x-matroska=vlc.desktop
audio/x-ms-wma=vlc.desktop
audio/midi=vlc.desktop
audio/x-aiff=vlc.desktop
audio/3gpp=vlc.desktop
audio/3gpp2=vlc.desktop
audio/AMR=vlc.desktop
audio/x-flac=vlc.desktop
audio/ac3=vlc.desktop
audio/eac3=vlc.desktop
audio/webm=vlc.desktop
audio/mpegurl=vlc.desktop
audio/x-mpegurl=vlc.desktop
video/x-flv=vlc.desktop
video/mp2t=vlc.desktop
video/x-ms-wmv=vlc.desktop
video/3gp=vlc.desktop
video/3gpp2=vlc.desktop
video/ogg=vlc.desktop
video/x-ogm+ogg=vlc.desktop
video/mpeg=vlc.desktop
# Discos/imagenes -> ark (iso real: .iso->application/vnd.efi.iso)
application/x-cd-image=org.kde.ark.desktop
application/vnd.efi.iso=org.kde.ark.desktop
application/vnd.rar=org.kde.ark.desktop
application/x-compress=org.kde.ark.desktop
application/x-lzma=org.kde.ark.desktop
application/x-lz4=org.kde.ark.desktop
application/x-lzip=org.kde.ark.desktop
application/zstd=org.kde.ark.desktop
application/x-zstd-compressed-tar=org.kde.ark.desktop
application/x-compressed-tar=org.kde.ark.desktop
application/x-bzip-compressed-tar=org.kde.ark.desktop
application/x-bzip2-compressed-tar=org.kde.ark.desktop
application/x-xz-compressed-tar=org.kde.ark.desktop
# Flash de imagenes -> popsicle
application/vnd.efi.img=com.system76.Popsicle.desktop
application/x-raw-disk-image=com.system76.Popsicle.desktop
# Archivos propios de cada app -> su creadora (comportamiento GNOME: el unico
# que los produce es el default; .xcf->gimp aunque krita_xcf tambien lo declare)
application/x-blender=blender.desktop
application/x-krita=org.kde.krita.desktop
image/x-xcf=gimp.desktop
image/x-psd=gimp.desktop
image/vnd.adobe.photoshop=gimp.desktop
application/x-audacity-project=audacity.desktop
application/x-audacity-project+sqlite3=audacity.desktop
application/vnd.mlt+xml=org.shotcut.Shotcut.desktop
application/x-kicad-project=org.kicad.kicad.desktop
application/x-kicad-pcb=org.kicad.pcbnew.desktop
application/x-kicad-schematic=org.kicad.eeschema.desktop
application/x-gerber=org.kicad.gerbview.desktop
application/x-excellon=org.kicad.gerbview.desktop
application/x-extension-fcstd=org.freecad.FreeCAD.desktop
model/stl=org.freecad.FreeCAD.desktop
model/step=org.freecad.FreeCAD.desktop
model/obj=org.freecad.FreeCAD.desktop
model/vrml=org.freecad.FreeCAD.desktop
model/vnd.collada+xml=org.freecad.FreeCAD.desktop
image/vnd.dxf=org.freecad.FreeCAD.desktop
image/vnd.dwg=org.freecad.FreeCAD.desktop
image/svg+xml-compressed=org.inkscape.Inkscape.desktop
image/x-eps=org.inkscape.Inkscape.desktop
image/x-emf=org.inkscape.Inkscape.desktop
image/x-wmf=org.inkscape.Inkscape.desktop
application/illustrator=org.inkscape.Inkscape.desktop
EOF
    }
    # El diálogo "Open with" de KDE, al elegir un binario por "browse", genera
    # .desktop NoDisplay en ~/.local/share/applications (con sufijo -N); KDE los
    # descarta al resolver el default y re-pregunta siempre. Se limpian TODOS
    # los stubs -N (imv-2, firefox-2, ...) y se usa el id real.
    rm -f "$HOME/.local/share/applications/"*-[0-9].desktop
    if [ -f "$f" ]; then
      # Migración única: si el archivo guarda ids de stubs rotos (generados por
      # el diálogo), se regenera desde el seed; si no, MERGE: se anaden los
      # tipos del seed que falten (los seeds nuevos llegan a máquinas con
      # archivo ya existente) sin tocar lo que el usuario eligió a mano en el
      # diálogo "abrir con".
      if grep -qE -- '-[0-9]+\.desktop' "$f"; then
        cp "$f" "$f.bak"
        write_seed "$f"
      else
        tmp="$(mktemp)"
        write_seed "$tmp"
        while IFS= read -r line; do
          mime=''${line%%=*}
          [ "$mime" = "$line" ] && continue
          grep -q "^$mime=" "$f" || printf '%s\n' "$line" >> "$f"
        done < "$tmp"
        rm -f "$tmp"
      fi
    else
      write_seed "$f"
    fi
    # KDE ignora los caches ksycoca nuevos y sigue usando uno viejo (nixpkgs#292632):
    # sin esto, Dolphin resuelve las asociaciones contra un cache desactualizado
    # y re-pregunta "abrir con" aunque ya haya default. Al limpiarlos Y
    # reconstruirlos al vuelo con el entorno NUEVO, el cache queda correcto al
    # instante (el kbuildsycoca6 headless no necesita display).
    #
    # El rebuild SOLO produce servicios si existe /etc/xdg/menus/applications.menu
    # (se provee en common-packages): sin el archivo, kbuildsycoca6 no indexa
    # NINGUN .desktop (las apps entran via <DefaultAppDirs/> del menu; Plasma lo
    # encuentra porque su sesion pone XDG_MENU_PREFIX=plasma-, Hyprland no) y
    # ksycoca queda con 0 servicios -> Dolphin pregunta "abrir con" para todo.
    rm -f "$HOME/.cache/ksycoca6_"*
    "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6" --noincremental >/dev/null 2>&1 || true
  '';

  # Previews de Dolphin para todo tipo de archivo (imágenes, vídeo, audio, pdfs...):
  # se siembra [PreviewSettings] la primera vez. ffmpegthumbs (common-packages)
  # aporta el preview de vídeo; sin él, Dolphin no muestra miniaturas de vídeo
  # (ni siquiera del móvil por MTP).
  #
  # OJO: el formato de lista de KConfig es SEPARADA POR COMAS, no por ';'
  # (KConfigGroup::writeEntry(QStringList) serializa con ','). Una semilla con
  # ';' se lee como UN SOLO string -> ningun plugin coincide -> Dolphin no
  # genera NINGUN preview. Verificado: kwriteconfig6 escribe comas.
  #
  # Previews REMOTOS (MTP/celular): FilePreviewJob salta los archivos remotos
  # con `size > MaximumRemoteSize`, y el default de MaximumRemoteSize es 0 ->
  # sin previews de nada en mtp://. Se siembra 256 GiB (cubre videos 4K/8K
  # largos del celular) + EnableRemoteFolderThumbnail. El costo de generar es
  # bajo: Dolphin usa kio-fuse (common-packages) que monta el archivo remoto
  # via FUSE y el thumbnailer solo lee los primeros frames; sin kio-fuse el
  # fallback descarga el archivo completo (lento para videos de GBs).
  home.activation.materializeDolphinPreview = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="$HOME/.config/dolphinrc"
    write_seed() {
      cat >> "$f" <<'EOF'

[PreviewSettings]
Plugins=imagethumbnail,jpegthumbnail,svgthumbnail,directorythumbnail,textthumbnail,audiothumbnail,ffmpegthumbs,comicbookthumbnail,djvu,ebook,exr,kraora,opendocument
MaximumRemoteSize=274877906944
EnableRemoteFolderThumbnail=true
EOF
    }
    if grep -q '^Plugins=.*;' "$f" 2>/dev/null; then
      # Migración única: la semilla antigua (pre-fix) usaba ';' y mataba todos
      # los previews; se reemplaza la línea rota por el formato con comas.
      cp "$f" "$f.bak"
      sed -i 's|^Plugins=.*$|Plugins=imagethumbnail,jpegthumbnail,svgthumbnail,directorythumbnail,textthumbnail,audiothumbnail,ffmpegthumbs,comicbookthumbnail,djvu,ebook,exr,kraora,opendocument|' "$f"
    elif ! grep -q '\[PreviewSettings\]' "$f" 2>/dev/null; then
      write_seed
    fi
    # Previews remotos: se garantizan las dos claves dentro del grupo (si el
    # seed ya las puso, los grep los saltan; si no, se insertan tras el header).
    grep -q '^MaximumRemoteSize=' "$f" 2>/dev/null || sed -i '/^\[PreviewSettings\]/a MaximumRemoteSize=274877906944' "$f"
    grep -q '^EnableRemoteFolderThumbnail=' "$f" 2>/dev/null || sed -i '/^\[PreviewSettings\]/a EnableRemoteFolderThumbnail=true' "$f"
  '';

}
