{ config, pkgs, lib, ... }:

let
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
      -- Catch-all: máxima frecuencia soportada (highrr). Reproductible en
      -- cualquier host sin hardcodear nombres (pc 100 Hz, laptop, vm).
      -- vrr = 1: pedir Adaptive-Sync en TODAS las salidas. Solo se activa de
      -- verdad si el panel lo tiene encendido en su OSD (Adaptive-Sync / FreeSync);
      -- si esta apagado ahi, `hyprctl monitors` sigue mostrando vrr=false aunque
      -- el host lo pida. Se verifica con: hyprctl monitors | grep vrr
      hl.monitor({ output = "", mode = "highrr", position = "auto", scale = "1", vrr = 1 })

      ------------------
      ---- AUTOSTART ----
      ------------------
      hl.on("hyprland.start", function()
        -- Escritorios numerados SOLO en el monitor principal; el secundario se
        -- queda con uno vacio esperando que le arrastren una ventana (estilo
        -- GNOME). Va antes que el shell para que los workspaces ya existan
        -- cuando Caelestia dibuja la barra.
        hl.exec_cmd("${config.xdg.configHome}/hypr/scripts/workspace-bind.sh")
        -- Caelestia (Quickshell) reemplaza a Wayle como shell. El CLI vive en el
        -- wrapper de caelestia-shell; `-d` lo desacopla de la terminal.
        hl.exec_cmd("caelestia shell -d")
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
        -- kdeconnect: el daemon corre como unidad systemd "app-org.kde.kdeconnect.
        -- daemon-autostart" (ver abajo), no por exec-once: el portal RemoteDesktop
        -- deriva el app id del llamador desde el nombre de su unidad systemd y sin
        -- unidad queda vacio (el backend de hypr-kdeconnect lo rechaza).
        -- (idle.sh/hypridle eliminado: el idle vive en Caelestia, ver shell.json)
        -- Forzar cursor Material Bibata Deep Blue tambien en la sesion
        -- Hyprland (ademas del XCURSOR_THEME global de home-manager):
        -- hyprcursor a veces no pilla el tema del sistema y deja el default;
        -- esto lo fija al arrancar.
        hl.exec_cmd("hyprctl setcursor Bibata-Material-Deep-Blue 30")
      end)

      ------------------------
      ---- LOOK AND FEEL ----
      ------------------------
      hl.config({
        general = {
          gaps_in = 5,
          -- gaps_out por-lado en formato TABLA (la config lua NO acepta string
          -- css para hl.config: exige entero o tabla). Con la barra de Caelestia
          -- a la IZQUIERDA (exclusive) el hueco a absorber esta a la izquierda;
          -- antes el -10 right compensaba la barra derecha de wayle. Simetrico.
          gaps_out = { top = 10, right = 10, bottom = 10, left = 10 },
          border_size = 4,
          layout = "dwindle",
          col = {
            active_border = { colors = { "rgba(ed1044ff)", "rgba(9900ffff)", "rgba(00aaffff)" }, angle = 45 },
            inactive_border = "rgba(1e1e3aff)",
          },
        },

        decoration = {
          rounding = 12,
          -- Vidrio biselado: translúcido pero legible (0.8 activa / 0.6
          -- inactiva). Steam y reproductores quedan exentos via reglas
          -- (opacity "N override" fuerza opacidad absoluta).
          active_opacity = 0.8,
          inactive_opacity = 0.6,
          blur = {
            enabled = true,
            size = 12,
            passes = 3,
            ignore_opacity = true,
          },
          -- Neón: la sombra coloreada es el "destello" — glow difuminado (blur)
          -- alrededor de la ventana, gradiente activo (ed1044→00aaff) vs azul
          -- apagado inactivo.
          shadow = {
            enabled = true,
            range = 20,
            render_power = 2,
            color = { colors = { "rgba(ed104477)", "rgba(9900ff77)", "rgba(00aaff77)" }, angle = 45 },
            color_inactive = "rgba(1e1e3a44)",
          },
          -- Glow interior nativo: ilumina el vidrio desde el borde hacia dentro.
          -- Gradiente activo (ed1044→00aaff) vs azul apagado inactivo.
          glow = {
            enabled = true,
            range = 30,
            render_power = 2,
            color = { colors = { "rgba(ed104455)", "rgba(9900ff55)", "rgba(00aaff55)" }, angle = 45 },
            color_inactive = "rgba(1e1e3a33)",
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

        -- Pantalla tactil: swipe con UN dedo por el borde superior/inferior de la
        -- pantalla = cambiar de workspace. ES el gesto que el user SI usa
        -- (restaurado 2026-08-17; el gesto de 3 dedos del TRACKPAD que no
        -- usaba sigue fuera: intertouch + hl.gesture eliminados).
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
          -- VRR (FreeSync): el panel refresca cuando la GPU entrega el frame, en
          -- vez de a un reloj fijo. No da mas FPS: saca el tearing y el judder
          -- cuando el juego no clava justo los Hz del monitor.
          -- 1 = siempre activo (pedido explicito). Ojo: si el panel parpadea con
          -- fps bajos, 2 lo limita a fullscreen y suele alcanzar.
          vrr = 1,
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
      -- Touchpad desactivado por defecto (el user no lo usa; el trackpoint va
      -- por su propio dispositivo, no se toca). Toggle con SUPER+G con
      -- notificacion (no SUPER+B: ese es el toggle-frost del blur).
      hl.device({ name = "synps/2-synaptics-touchpad", enabled = false })

      ------------------------
      ---- ANIMACIONES -------
      ------------------------
      -- Curva "standard" por defecto de Caelestia (animations.lua) para workspaces.
      hl.curve("standard", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
      hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
      -- Curvas de rebote: "bounce" es el bounce fuerte del viejo Wayle
      -- (workspace-bounce), "bounce-natural" lo suaviza. Se dejan definidas
      -- ambas para probarlas en vivo con workspace-anim.sh (SUPER+ALT+A).
      hl.curve("bounce", { type = "bezier", points = { {0.05, 1.8}, {0.2, 1.0} } })
      hl.curve("bounce-natural", { type = "bezier", points = { {0.1, 1.4}, {0.3, 1.0} } })

      hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "overshot", style = "slideright" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "default", style = "popin 80%" })
      hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
      hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
      -- Workspaces: slidefadevert + overshot, elegida por el humano con el
      -- selector SUPER+ALT+A (ola 3). Las curvas "bounce"/"bounce-natural"
      -- siguen definidas arriba para probar variantes en vivo.
      hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "overshot", style = "slidefadevert" })

      -----------------------
      ---- WINDOW RULES -----
      -----------------------
      hl.window_rule({ name = "pavucontrol-float", match = { class = "pavucontrol" }, float = true })
      hl.window_rule({ name = "blueberry-float", match = { class = "blueberry" }, float = true })
      hl.window_rule({ name = "volume-float", match = { title = "Volume Control" }, float = true })
      -- kitty (incluye las ventanas de `hyprdev`/`netrunner`, misma clase):
      -- vidrio esmerilado — blur del compositor detrás de la transparencia
      -- propia (background_opacity). opacity "1 override" fuerza 1.0 absoluto
      -- para que el texto se mantenga opaco y no se apile la opacidad de
      -- Hyprland con la de kitty. El match de clase es de cadena COMPLETA
      -- (regex_match), por eso `kitty` a secas basta.
      hl.window_rule({ name = "kitty-glass", match = { class = "kitty" }, opacity = "1 override" })
      -- steam: exento de blur y transparencia (opacidad total).
      hl.window_rule({ name = "steam-solid", match = { class = "steam" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "steam-app-solid", match = { class = "steam_app_.*" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "gamescope-solid", match = { class = "gamescope" }, no_blur = true, opacity = "1 override" })
      -- Reproductores de video: sólidos (no se lava el contenido) y sin blur para que
      -- el compositor no re-borronee el fondo en cada frame del video.
      hl.window_rule({ name = "mpv-solid", match = { class = "mpv" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "celluloid-solid", match = { class = "io.github.celluloid_player.Celluloid" }, no_blur = true, opacity = "1 override" })
      hl.window_rule({ name = "vlc-solid", match = { class = "vlc" }, no_blur = true, opacity = "1 override" })
      -- kdeconnect presenter ("Presentation remote" del celular): overlay fullscreen
      -- transparente que dibuja el puntero. Tres trampas de Hyprland descubiertas:
      -- 1) clase real = org.kde.kdeconnect.daemon (applicationName de Qt; anclada ^$:
      --    el match es de cadena completa y "org.kde.kdeconnect" no matcheaba).
      -- 2) con blur (ignore_opacity=true) se veia como panel opaco -> no_blur.
      -- 3) el fullscreen (solicitado por Qt o forzado) NO funciona con
      --    no_initial_focus (bug); sin el, la ventana roba foco y las slides
      --    pierden su fullscreen. Solucion: flotante a tamaño de monitor
      --    (size/move con expresiones monitor_w/h), sin foco, sin animacion.
      hl.window_rule({ name = "kdeconnect-presenter", match = { class = "^org\\.kde\\.kdeconnect\\.daemon$" }, float = true, size = { "(monitor_w)", "(monitor_h)" }, move = { 0, 0 }, no_initial_focus = true, no_blur = true, no_anim = true })
      -- GUIs de simulacion/HDL lanzadas desde la terminal (gtkwave, matplotlib,
      -- logisim): nacen FLOTANTES y MAXIMIZADAS (fullscreen modo 1, el estilo
      -- LibreOffice: cubre todo el mosaico respetando los gaps y la zona
      -- reservada de la barra de Caelestia (izquierda), verificado en vivo:
      -- margen uniforme, borde a unos px de la barra) encima de las terminales. Flotante = el layout en
      -- mosaico no se toca (las terminales nunca se redimensionan, bug
      -- documentado de opencode) y al cerrar la GUI queda todo como estaba.
      -- La regla aplica al mapear (atomica), a diferencia de guirun
      -- (eliminado) que movia la ventana a otro workspace despues de varios
      -- segundos de terminales ensanchandose. Sin no_initial_focus: la GUI
      -- toma el foco (el fullscreen/maximize ademas no funciona con esa
      -- regla, bug documentado en kdeconnect-presenter).
      -- ponytail: el match es de cadena COMPLETA; app nueva = anadir su class.
      hl.window_rule({ name = "sims-guis", match = { class = "^(gtkwave|python3|python|Tk|matplotlib|logisim-evolution)$" }, float = true, maximize = true })

      -----------------------
      ---- LAYER RULES ------
      -----------------------
      -- ignore_alpha descarta el blur en pixeles con opacidad <= al valor. Los
      -- drawers pintan su superficie con alpha = transparency.base (0.34 desde
      -- que se subio la transparencia), asi que un umbral por encima los dejaba
      -- SIN blur. 0.3 queda por debajo del base para que el blur se aplique.
      hl.layer_rule({ name = "caelestia-drawers-blur", match = { namespace = "caelestia-drawers" }, blur = true, ignore_alpha = 0.3 })
      hl.layer_rule({ name = "caelestia-area-picker", match = { namespace = "caelestia-area-picker" }, blur = true })

      -----------------------
      ---- KEYBINDINGS ------
      -----------------------
      hl.bind("SUPER + Backspace", hl.dsp.exec_cmd("kitty"))
      hl.bind("SUPER + F2", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/touchpad-toggle.sh"))
      -- Mirror/Extended: bindings DETERMINISTAS, sin toggle. SUPER+D es
      -- siempre Mirror, SUPER+SHIFT+D es siempre Extended. Antes alternaban y
      -- no habia forma de saber cual te tocaba.
      hl.bind("SUPER + D", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/monitor-mirror.sh mirror"))
      hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/monitor-mirror.sh extended"))
      -- Foco entre monitores SIN cambiar de escritorio: el cursor/foco salta al
      -- otro monitor y cada uno sigue mostrando lo suyo (lo que ya hacias a
      -- mano con el mouse). Verificado 2026-10-28: hl.dsp.focus({ monitor = "r" })
      -- funciona; "right" no (responde "monitor not found").
      hl.bind("SUPER + ALT + Right", hl.dsp.focus({ monitor = "r" }))
      hl.bind("SUPER + ALT + Left", hl.dsp.focus({ monitor = "l" }))
      -- rofi retirado: TODO pasa por el launcher de Caelestia (SUPER+CTRL+Space
      -- para apps, y `>ack` dentro del launcher para las acciones).
      -- Caelestia: launcher, dashboard, menu de sesion y utilities. Reemplazan
      -- al dropdown dashboard de Wayle. SUPER+N (netrunner) sigue siendo
      -- terminal, por eso el sidebar usa SUPER+CTRL+N.
      hl.bind("SUPER + CTRL + N", hl.dsp.global("caelestia:sidebar"))
      hl.bind("SUPER + CTRL + Space", hl.dsp.global("caelestia:launcher"))
      hl.bind("SUPER + CTRL + D", hl.dsp.global("caelestia:dashboard"))
      -- SUPER+CTRL+Q abre el menu de sesion. Restaurado 2026-08-12: se habia
      -- retirado junto con SUPER+M, pero el menu NO ejecuta nada por si solo
      -- (exige un click sobre la accion); lo que mataba el trabajo era SUPER+M
      -- (hl.dsp.exit), y ese sigue eliminado mas abajo.
      hl.bind("SUPER + CTRL + Q", hl.dsp.global("caelestia:session"))
      hl.bind("SUPER + CTRL + U", hl.dsp.global("caelestia:utilities"))
      hl.bind("SUPER + CTRL + K", hl.dsp.global("caelestia:showall"))
      -- Clipboard/emoji pickers nativos de Caelestia (fuzzel). Sustituyen al
      -- rofi+cliphist del modulo custom de Wayle; el historial sigue en
      -- cliphist porque Caelestia lo usa por debajo en el CLI.
      hl.bind("SUPER + SHIFT + V", hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
      hl.bind("SUPER + Period", hl.dsp.exec_cmd("pkill fuzzel || caelestia emoji -p"))
      -- Screenshot nativo (area picker con freeze) ademas de los hyprshot del
      -- repo; el picker de color ya existe arriba via hyprpicker.
      hl.bind("SUPER + Delete", hl.dsp.window.close())
      -- SUPER+M (hl.dsp.exit: mataba la sesion Hyprland entera, con todas las
      -- apps abiertas) RETIRADO 2026-08-12 por el mismo motivo. Para cerrar
      -- sesion queda el menu de sesion de Caelestia, que pide un click.
      hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
      -- Pin = always on top + visible en todos los workspaces (requiere ventana flotante).
      hl.bind("SUPER + T", hl.dsp.window.pin({ action = "toggle" }))
      -- SUPER+R (rofi run) fuera: el launcher de Caelestia ya busca binarios
      -- ademas de apps. Se deja como acceso al selector de wallpaper propio.
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

      -- SUPER+ALT+SHIFT+N: mover TODAS las ventanas del workspace ACTIVO al N
      -- (follow=true, estilo GNOME: la vista acompana a las ventanas).
      -- Compacta huecos de escritorios vacios navegando al destino.
      -- Para N>9, invocar el script a mano.
      for i = 1, 9 do
        hl.bind("SUPER + ALT + SHIFT + " .. i, hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/workspace-move-all.sh " .. i))
      end

      hl.bind("SUPER + W", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/time-to-work.sh"))
      -- netrunner abre sus propias ventanas kitty independientes (clase
      -- `kitty` por defecto): el dedupe de Caelestia las colapsa a un icono.
      hl.bind("SUPER + N", hl.dsp.exec_cmd("kitty zsh -ic netrunner"))
      hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/switch-layout.sh"))
      hl.bind("SUPER + L", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/lock.sh"))
      -- Esmerilado on/off (blur + transparencia) con notificación.
      hl.bind("SUPER + B", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/toggle-frost.sh"))

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

      -- Selector de animación de workspaces (fuzzel): aplica en vivo con
      -- hyprctl eval. Temporal, vive hasta el próximo reload/rebuild.
      hl.bind("SUPER + ALT + A", hl.dsp.exec_cmd("${config.xdg.configHome}/hypr/scripts/workspace-anim.sh"))

      -- Ratón: LMB arrastra (mover), RMB redimensiona (sin estos binds el config
      -- sobreescribe los defaults de Hyprland).
      hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

      -- Multimedia: volumen y micrófono (repeat + locked = bindel/bindl legacy)
      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
      -- Brillo por los global shortcuts de Caelestia (panel interno + DDC/CI):
      -- su servicio Brightness es quien pinta el OSD; brightness.sh se retiró.
      hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"))
      hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"))
      hl.bind("SUPER + F12", hl.dsp.global("caelestia:brightnessUp"))
      hl.bind("SUPER + F11", hl.dsp.global("caelestia:brightnessDown"))
      -- Brillo: vuelve por los globales de Caelestia (pinta el OSD). El knob
      -- apunta al device que elige brightnessctl; con el DDC del principal
      -- roto (probe -17, ver hosts/pc/configuration.nix) solo mueve el que
      -- si responde.
      hl.bind("SUPER + XF86AudioRaiseVolume", hl.dsp.global("caelestia:brightnessUp"))
      hl.bind("SUPER + XF86AudioLowerVolume", hl.dsp.global("caelestia:brightnessDown"))
      -- ponytail: sin panel interno, el unico backlight es ddcci8 y CADA cambio
      -- es una transaccion DDC/CI por i2c AUX: medidos 66 ms por write el
      -- 2026-10-28 (10 writes encadenados = 653 ms, el driver los serializa;
      -- la lectura en cambio es 1 ms porque el kernel la cachea). Con
      -- `repeating = true` mantener la tecla encolaba ~15 writes por segundo y
      -- el panel quedaba segundos atras: ESE era el "el brillo no responde al
      -- toque". Sin repeat, un toque = un write = 66 ms.
      -- Techo a subir si vuelve a molestar: coalescer (guardar el valor
      -- objetivo y aplicar solo el ultimo cada ~80 ms) via shim de brightnessctl
      -- o servicio propio, en vez de encolar un write por evento.

      -- Control de reproducción: Caelestia expone shortcuts globales de Hyprland
      -- (caelestia:media*) que van por MPRIS, así que SUPER+F7 pausa lo que sea
      -- que esté sonando (YouTube/Firefox, VLC, mpv...). El `|| mpc` como
      -- fallback para MPD ya no aplica: el global shortcut no devuelve estado,
      -- y Caelestia cubre MPRIS que es el caso real.
      hl.bind("SUPER + F7", hl.dsp.global("caelestia:mediaToggle"))
      hl.bind("SUPER + F6", hl.dsp.global("caelestia:mediaPrev"))
      hl.bind("SUPER + F8", hl.dsp.global("caelestia:mediaNext"))

      -----------------------
      ---- GESTOS -----------
      -----------------------
      -- Gesto de 3 dedos del trackpad (workspaces) ELIMINADO 2026-08-17: nunca
      -- funciono (requeria el param psmouse.synaptics_intertouch del kernel,
      -- tambien quitado) y el user no lo usa ni lo quiere.
    '';
  };

  home.packages = with pkgs; [
    # hyprlock/hypridle fuera: lock e idle los hace Caelestia (module caelestia.nix).
    brightnessctl
    pavucontrol
    libnotify
    wl-clipboard
    hyprshot
    kdePackages.gwenview
    tree-sitter
    cliphist
    setxkbmap
    # CLI de self-test de inyeccion de input (--self-test-motion/absolute/scroll)
    hypr-kdeconnect-fix
    # Agente de secretos de NetworkManager (ver el servicio gnome-keyring-secrets
    # de abajo). El applet solo aporta el binario `nm-applet`; el agente que NM
    # necesita para pedir la PSK lo pone gnome-keyring.
    gnome-keyring
    networkmanagerapplet
  ];

  # --- Agente BlueZ (emparejar HID) ---
  # Caelestia/quickshell 0.3.2 maneja org.bluez.Adapter1 y Device1 (por eso el
  # panel lista, conecta y hasta llama Pair()) pero NO implementa
  # org.bluez.Agent1: no tiene forma de contestar el passkey. Sin default agent
  # bluez corta el pairing con "new_auth() No agent available for request type 2"
  # y el teclado BLE nunca bonda. El AuthAgent de blueman-applet registra el
  # default agent con capability KeyboardDisplay: el dialogo de confirmacion
  # sale del applet (tray), no del shell. Requiere services.blueman.enable en
  # modules/desktop/hyprland.nix.
  services.blueman-applet.enable = true;

  # --- Agente de secretos de NetworkManager ---
  # SIN esto, NM no puede pedir la PSK del Wi-Fi cuando el AP cae y el perfil
  # tiene que re-autenticar: falla al instante con
  #   device (wlp4s0): no secrets: No agents were available for this request.
  # y el dialogo de contrasena NUNCA llega a mostrarse (Caelestia es solo un
  # front-end de nmcli, no un agente de secretos). Olvidar la red empeora las
  # cosas: borra la PSK cacheada y ya no hay quien la vuelva a pedir.
  # Fedora/Arch no lo sufren porque GNOME/KDE arrancan gnome-keyring/kwalletd
  # con la sesion; una sesion Hyprland minima no arranca ninguno.
  # gnome-keyring-daemon con --components=secrets registra org.freedesktop.secrets
  # en la session D-Bus; el paquete ademas instala
  # share/dbus-1/services/org.freedesktop.secrets.service, asi que el bus puede
  # re-lanzarlo por activacion. Se corre en --foreground porque systemd exige un
  # proceso en primer plano para Type=dbus (un --daemonize haria que el ExecStart
  # devuelva de inmediato y systemd perderia el tracking del servicio).
  # El keyring nace con password vacia (no hay PAM que lo abra) y la PSK del
  # Wi-Fi vive en /etc/NetworkManager/system-connections (root, no en el keyring);
  # el agente aqui solo necesita ESTAR REGISTRADO para que NM pueda pedirla.
  systemd.user.services.gnome-keyring-secrets = {
    Unit = {
      Description = "GNOME Keyring: agente de secretos (org.freedesktop.secrets)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.secrets";
      ExecStart = "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --foreground --components=secrets";
      Restart = "on-failure";
      RestartSec = "1s";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

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

  # kdeconnectd como unidad con nombre "app-<appid>-autostart": es el unico modo en
  # que xdg-desktop-portal asigna app id a un proceso host (lee la unidad systemd del
  # llamador y valida que exista <appid>.desktop). Sin eso, el backend RemoteDesktop
  # rechaza la sesion ("refusing RemoteDesktop session for app id ''") y el remote
  # input del celular no mueve nada. En Plasma lo lanza systemd con el mismo patron.
  systemd.user.services."app-org.kde.kdeconnect.daemon-autostart" = {
    Unit = {
      Description = "KDE Connect daemon";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnectd";
      Restart = "on-failure";
    };
    Install = { WantedBy = [ "graphical-session.target" ]; };
  };

  # Sunshine (host de Moonlight): se probo y se descarto. Moonlight es una app
  # aparte que hay que instalar en la TV, con cuenta y PIN: no es transparente
  # como Cast/Miracast. Ver odd/tasks/miracast-pantallas-tema.md.


  # cliphist: limite de historial en 20 items. Era 6, pero el humano perdía
  # contexto al elegir; 20 mantiene el historial corto sin crecer sin control
  # (captura TODO lo copiado, incl. contraseñas de KeepassXC).
  xdg.configFile."cliphist/config".text = "max-items 20\n";

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
        hyprctl dispatch 'hl.dsp.exec_cmd("kitty", { workspace = 4 })'
      '';
    };

    # Toggle de disposicion de monitores: Mirror <-> Extended (nombres en
    # ingles por pedido explicito). SUPER+D = Mirror, SUPER+SHIFT+D = Extended;
    # los dos son deterministas, ya no alternan. No hay auto-espejo al conectar
    # un monitor: causaba las "pantallas locas" al arrancar. Con menos de 2
    # salidas activas el script no hace nada.
    # hyprctl keyword esta bloqueado en Hyprland 0.56 ("non-legacy parsers"):
    # el runtime va via hyprctl eval de la API hl.monitor(..., mirror = "X").
    # Dos invariantes que este script NO rompe:
    #  1) el primario no se toca NUNCA. Reaplicarle mode/position/scale perdia
    #     la geometria configurada del monitor principal: ese era el "extender
    #     falla". Solo se tocan las salidas que estan espejadas (o las que se
    #     van a espejar).
    #  2) al espejar, el secundario corre el MISMO timing que el primario (se
    #     elige el modo mas cercano de su propia lista). Con timings distintos
    #     Hyprland mostraba cuadros viejos/tearing en la salida espejada.
    # mirror = "none" (string) es lo que des-espeja: verificado 2026-10-28 con
    # una salida HEADLESS (mirrorOf pasa de "1" a "none"). mirror = false no
    # parsea ("string type requires a string").
    # notify-send (no "wayle notify", ya retirado: ese subcommand solo controlaba
    # la lista, no enviaba texto).
    "hypr/scripts/monitor-mirror.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        command -v jq >/dev/null || { echo "falta jq" >&2; exit 1; }

        apply() {
          hyprctl eval "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = \"$4\", mirror = \"$5\" })" >/dev/null
        }

        active=$(hyprctl monitors all -j | jq -c '[.[] | select(.disabled == false)]')
        if [ "$(echo "$active" | jq 'length')" -lt 2 ]; then
          notify-send "Solo hay un monitor"
          exit 0
        fi

        # Primario = el enfocado (el que usa el humano), fallback el primero.
        primary=$(echo "$active" | jq -r '(map(select(.focused == true))[0] // .[0]) | .name')
        pmon=$(echo "$active" | jq -c --arg p "$primary" '.[] | select(.name == $p)')

        # Modo del primario traducido a la lista del secundario: misma
        # resolucion, Hz mas cercano. Devuelve una entrada VALIDA de
        # availableModes (sin el sufijo Hz), no un timing inventado.
        best_mode() {
          echo "$1" | jq -r \
            --argjson w "$(echo "$pmon" | jq '.width')" \
            --argjson h "$(echo "$pmon" | jq '.height')" \
            --argjson r "$(echo "$pmon" | jq '.refreshRate')" '
            [ .availableModes[] | select(startswith("\($w)x\($h)@"))
              | { s: ., r: (sub(".*@"; "") | sub("Hz$"; "") | tonumber) } ]
            | sort_by((.r - $r) | if . < 0 then -. else . end)
            | (.[0].s // "preferred") | sub("Hz$"; "")'
        }

        mirrored=$(echo "$active" | jq -c '[.[] | select(.mirrorOf != "none")]')

        # Mirror (SUPER+D): idempotente, reaplicarlo no rompe nada.
        if [ "''${1:-mirror}" != "extended" ]; then
          for name in $(echo "$active" | jq -r --arg p "$primary" '.[] | select(.name != $p) | .name'); do
            mon=$(echo "$active" | jq -c --arg n "$name" '.[] | select(.name == $n)')
            apply "$name" "$(best_mode "$mon")" "auto" "$(echo "$mon" | jq -r '.scale')" "$primary"
          done
          notify-send "Mirror"
          exit 0
        fi

        # Extended (SUPER+SHIFT+D): se restauran SOLO las salidas espejadas, cada
        # una con la geometria que ella misma reporta. El primario queda intacto.
        # Despues se reafirman los escritorios numerados en el principal para que
        # el secundario quede vacio y no se robe uno (estilo GNOME).
        for name in $(echo "$mirrored" | jq -r '.[].name'); do
          mon=$(echo "$mirrored" | jq -c --arg n "$name" '.[] | select(.name == $n)')
          apply "$name" "$(echo "$mon" | jq -r '"\(.width)x\(.height)@\(.refreshRate)"')" "auto" "$(echo "$mon" | jq -r '.scale')" "none"
        done
        "${config.xdg.configHome}/hypr/scripts/workspace-bind.sh" || true
        notify-send "Extended"
      '';
    };

    # Coalescer del brillo para el knob (SUPER + perilla de volumen).

    # Escritorios numerados SOLO en el monitor principal; cada secundario recibe
    # un escritorio propio y vacio esperando que le arrastren una ventana (asi se
    # comporta GNOME en extended, que es lo que se pidio). Sin esto Hyprland crea
    # el workspace en el monitor ENFOCADO, y `time-to-work` (SUPER+W) terminaba
    # mandando uno de los escritorios 1-4 al secundario.
    # Se reaplica al arrancar y cada vez que se pasa a Extended
    # (monitor-mirror.sh); los nombres de salida no se hardcodean nunca.
    "hypr/scripts/workspace-bind.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail
        command -v jq >/dev/null || exit 1

        # Argumento opcional: cuantos escritorios numerados atar (default 12).
        last="''${1:-12}"

        mons=$(hyprctl monitors -j | jq -c '[.[] | select(.disabled == false)]')
        [ "$(echo "$mons" | jq 'length')" -ge 1 ] || exit 0

        # Principal = el monitor en x=0 (el que Hyprland deja mas a la
        # izquierda); si ninguno, el enfocado. Para forzar otro, pasar el nombre
        # como 3er argumento.
        main=$(echo "$mons" | jq -r '(map(select(.focused == true))[0] // .[0]) | .name')

        # 1..MAIN_LAST quedan en el principal; de ahi en adelante van al primer
        # secundario. Asi el secundario queda clavado a los escritorios 9+, que
        # el humano no usa, y SUPER+9 lo alcanza comodo. Con un solo monitor,
        # todo cae en el principal. Arg 2 = ultimo escritorio del principal.
        # Principal = el monitor en x=0 (el que Hyprland deja mas a la
        # izquierda). Antes era el ENFOCADO, y con el cursor en el otro monitor
        # el bind se aplicaba al que no era: eso hacia imposible recuperar el
        # principal despues de apagar y prender un monitor. Override: 3er arg.
        # 2do arg = ultimo escritorio del principal (default 8).
        main_last="''${2:-8}"
        main="''${3:-}"
        [ -n "$main" ] || main=$(echo "$mons" | jq -r 'map(select(.x == 0))[0].name // empty')
        [ -n "$main" ] || main=$(echo "$mons" | jq -r '(map(select(.focused == true))[0] // .[0]) | .name')

        secondary=$(echo "$mons" | jq -r --arg m "$main" '[.[] | select(.name != $m)][0].name // empty')
        for n in $(seq 1 "$last"); do
          target="$main"
          if [ -n "$secondary" ] && [ "$n" -gt "$main_last" ]; then
            target="$secondary"
          fi
          # persistent=true ademas MUEVE el workspace si ya existia en el otro
          # monitor (verificado 2026-10-28: ws 3 paso de HDMI-A-2 a DP-2). Una
          # regla sin persistent solo aplica a workspaces nuevos, y por eso el
          # 9 seguia respondiendo al principal hasta reiniciar la sesion.
          # default=true NO sirve para esto (probado: no migra).
          hyprctl eval "hl.workspace_rule({ workspace = \"$n\", monitor = \"$target\", persistent = true })" >/dev/null
        done
      '';
    };

    # El espejo ya no se aplica en hotplug: solo manual con SUPER+D
    # (monitor-mirror.sh). Con <2 salidas fisicas el script no hace nada.
    "hypr/scripts/mpvpaper-pause.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Pausa/reanuda el wallpaper via IPC nativo de mpv (mpvpaper es un
        # wrapper de mpv; el socket lo abre el propio mpv via input-ipc-server).
        # Arg: on|off. Espera hasta 5s a que el socket exista: al cambiar de
        # wallpaper el nuevo mpv nace justo antes del unpause y el socket puede
        # no estar listo todavia (sin el retry, el wallpaper quedaba estatico
        # en AC hasta el siguiente evento del cargador - visto 2026-08-17).
        [ $# -eq 1 ] || exit 1
        sock="/run/user/$(id -u)/mpvpaper.sock"
        for _ in $(seq 10); do
          [ -S "$sock" ] && break
          sleep 0.5
        done
        [ -S "$sock" ] || exit 0
        paused=0; [ "$1" = on ] && paused=1
        ${pkgs.python3}/bin/python3 - "$paused" "$sock" <<'PY'
        import json, socket, sys
        s = socket.socket(socket.AF_UNIX)
        try:
            s.connect(sys.argv[2])
            s.sendall((json.dumps({"command": ["set_property", "pause", sys.argv[1] == "1"]}) + "\n").encode())
            s.close()
        except OSError:
            pass
        PY
      '';
    };
    "hypr/scripts/touchpad-toggle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Alterna el touchpad (SUPER+G). Mismo patron que toggle-frost.sh: el
        # estado vive en XDG_RUNTIME_DIR (se limpia al cerrar sesion, volviendo
        # al default desactivado). El trackpoint es otro dispositivo y no se
        # toca. SUPER+B (frost) y sus binds no se tocan.
        state="$XDG_RUNTIME_DIR/touchpad-on"
        dev="synps/2-synaptics-touchpad"

        if [ -f "$state" ]; then
          rm -f "$state"
          hyprctl eval 'hl.device({ name = "synps/2-synaptics-touchpad", enabled = false })'
          notify-send -t 2000 -a hyprland -u low "Touchpad OFF"
        else
          touch "$state"
          hyprctl eval 'hl.device({ name = "synps/2-synaptics-touchpad", enabled = true })'
          notify-send -t 2000 -a hyprland -u low "Touchpad ON"
        fi
      '';
    };
    "hypr/scripts/wallpaper-set.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Solo dos responsabilidades:
        #   1) guardar la ruta FUENTE en wallpaper-source.txt (la usa
        #      caelestia-wallpaper.sh para saber si el fondo es video o imagen).
        #   2) lanzar el fondo ya, sin depender del shell.
        # El esquema Material You es FIJO (cyberpunk) y lo garantiza el activation
        # de caelestia.nix: ya no se recalcula en cada cambio de wallpaper (el CLI
        # disparaba el postHook hasta 3 veces -> mpvpaper duplicados).
        dir="${wallpapersDir}"
        f="$1"
        if [ -z "$f" ]; then
          f=$(find "$dir" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.webm' -o -name '*.mkv' \) 2>/dev/null | shuf -n1)
          [ -z "$f" ] && f=$(find "$dir" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) 2>/dev/null | shuf -n1)
        fi
        [ -z "$f" ] && exit 0

        state="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia"
        mkdir -p "$state"
        printf '%s' "$f" > "$state/wallpaper-source.txt"

        ~/.config/hypr/scripts/caelestia-wallpaper.sh "$f"
      '';
    };
    "hypr/scripts/wallpaper-cycle.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec ~/.config/hypr/scripts/wallpaper-set.sh
      '';
    };
    "hypr/scripts/caelestia-restart.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Reinicia el shell de Caelestia tras un rebuild (la instancia viva apunta al
        # store anterior y el IPC `caelestia shell ...` falla con exit 255).
        #
        # Self-heal: borrar ~/.config/caelestia/shell.json para adoptar el seed y
        # reiniciar SIN rebuild dejaba la shell en DEFAULTS (sin blur, sin cava,
        # sin acciones del launcher). Si falta, se copia del symlink estable
        # `shell.default.json` (xdg.configFile -> seed del store) antes de relanzar.
        f="$HOME/.config/caelestia/shell.json"
        d="$HOME/.config/caelestia/shell.default.json"
        if [ ! -f "$f" ] && [ -f "$d" ]; then
          cp "$d" "$f"
          chmod u+w "$f"
        fi
        pkill -f 'quickshell.*caelestia-shell' 2>/dev/null
        sleep 0.5
        # El indicador de layout lee estas reglas xkb. Se exporta aqui ademas de
        # sessionVariables (caelestia.nix) para que valga sin relogin: la sesion
        # viva no hereda todavia la variable nueva tras un rebuild.
        export CAELESTIA_XKB_RULES_PATH="${pkgs.xkeyboard-config}/share/X11/xkb/rules/base.lst"
        caelestia shell -d
      '';
    };
    # postHook de Caelestia: el CLI (caelestia-cli) lo invoca al cambiar de
    # wallpaper/esquema. Recibe WALLPAPER_PATH (ruta de la imagen que se le pasó
    # al CLI) y SCHEME_*. Como background.wallpaperEnabled=false en shell.json,
    # Caelestia NO pinta fondo: el fondo REAL lo pinta mpvpaper aquí (idempotente:
    # si ya corre con el mismo wallpaper, no relanza).
    #
    # OJO (recursión evitada): este hook NO vuelve a llamar a
    # `caelestia wallpaper`, porque set_wallpaper() -> apply_colours() ->
    # postHook() y sería un bucle.
    #
    # wallpaper-set.sh guarda la ruta original en
    # $XDG_STATE_HOME/caelestia/wallpaper-source.txt para saber si el fondo es
    # video o imagen.
    "hypr/scripts/caelestia-wallpaper.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Se invoca de dos formas: desde wallpaper-set.sh con la ruta como $1
        # (fondo directo, sin depender del shell) y desde caelestia-cli como
        # postHook con WALLPAPER_PATH en el entorno (cuando cambia el esquema).
        # ponytail: sin `set -e`: postHook best-effort, no debe abortar el
        # cambio de esquema.
        img="''${1:-''${WALLPAPER_PATH:-}}"
        srcfile="''${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/wallpaper-source.txt"
        src="$(cat "$srcfile" 2>/dev/null || true)"

        # El fondo real es el ORIGEN (video o imagen), no el frame del esquema.
        wall="''${src:-$img}"
        [ -n "$wall" ] && [ -f "$wall" ] || exit 0

        # Idempotencia: si ya corre mpvpaper con ESTE mismo wallpaper, no hacer
        # nada. El CLI dispara el postHook varias veces por cambio; sin esta
        # guarda se relanzaba y quedaban procesos duplicados (pkill perdia la
        # carrera).
        if pgrep -af 'mpvpaper' | grep -qF -- "$wall"; then
          exit 0
        fi

        pkill -x .mpvpaper-wrapp 2>/dev/null
        sleep 0.2
        # hwdec=vaapi: descodifica el video en la GPU (VCN/Radeon), no en la CPU.
        # Sin esto el fondo animado costaba ~274% de CPU en la laptop. -p pausa el
        # video cuando lo tapa una ventana (ahorra CPU/batería).
        # pause=yes + input-ipc-server: el wallpaper nace SIEMPRE congelado
        # (foto del primer frame) y el reproductor queda a la escucha del IPC;
        # mpvpaper-pause.sh lo reanuda si no estamos en bateria. Asi en bateria
        # NUNCA descodifica ni un frame desde el boot (era el drenaje de 22W->12.6W
        # medido; el arranque reproduciendo drenaba la sesion completa).
        rm -f /run/user/$(id -u)/mpvpaper.sock
        mpvpaper -f -p -o "no-audio
loop-file=inf
hwdec=vaapi
pause=yes
input-ipc-server=/run/user/$(id -u)/mpvpaper.sock" ALL "$wall"
        # Bateria = un supply de SISTEMA (scope=System, excluye ratones/teclados
        # inalambricos) descargandose. Un desktop sin bateria (o tras UPS) no la
        # tiene => el wallpaper vive siempre. Antes se miraba /supply/AC/online,
        # que solo existe en la laptop: en el PC el cat devolvia vacio y el
        # wallpaper quedaba congelado para siempre.
        on_battery() {
          for s in /sys/class/power_supply/*/status; do
            [ -f "$s" ] || continue
            sc="''${s%/status}/scope"
            { [ ! -f "$sc" ] || [ "$(cat "$sc" 2>/dev/null)" = System ]; } || continue
            [ "$(cat "$s" 2>/dev/null)" = Discharging ] && return 0
          done
          return 1
        }
        on_battery || "$HOME/.config/hypr/scripts/mpvpaper-pause.sh" off
      '';
    };
    "hypr/scripts/wallpaper-menu.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Selector de wallpaper con fuzzel (la misma UI que usa Caelestia para
        # clipboard/emoji). Muestra miniatura del PRIMER FRAME de cada video: el
        # cache de frames lo comparte caelestia-wallpaper.sh (mismo hash sha1 ->
        # mismo PNG), asi que aqui solo se busca.
        #
        # fuzzel recibe el icono por linea con el protocolo \0icon\x1f<ruta>
        # (igual que rofi). CRITICO: la lista va por PIPE DIRECTO a fuzzel, sin
        # variable intermedia — bash come los \0 en cualquier command
        # substitution y los iconos desaparecen.
        dir="${wallpapersDir}"
        set="$HOME/.config/hypr/scripts/wallpaper-set.sh"
        cache="''${XDG_CACHE_HOME:-$HOME/.cache}/caelestia/wallpaper-frame"
        mkdir -p "$cache"

        list_f="$cache/.menu-list"
        find "$dir" -maxdepth 1 -type f \
          \( -name '*.mp4' -o -name '*.webm' -o -name '*.mkv' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \) \
          | sort | while IFS= read -r f; do
              b=$(basename "$f")
              case "''${f##*.}" in
                mp4|webm|mkv)
                  h=$(sha1sum "$f" 2>/dev/null | cut -d' ' -f1)
                  icon="$cache/$h.png"
                  # Video ilegible o frame no generable: icono generico en vez
                  # de un PNG fantasma (fuzzel mostraria un hueco roto).
                  if [ -z "$h" ] || { [ ! -f "$icon" ] && ! ${pkgs.ffmpeg}/bin/ffmpeg -y -v error -i "$f" -frames:v 1 "$icon" 2>/dev/null; }; then
                    icon="video-x-generic"
                  fi
                  ;;
                *) icon="$f" ;;
              esac
              printf '%s\0icon\x1f%s\n' "$b" "$icon"
            done > "$list_f"
        [ -s "$list_f" ] || exit 0

        # fuzzel en modo dmenu (NO --dmenu0: ese usa NUL como separador de
        # linea y chocaria con el \0 del protocolo de iconos). El input se pasa
        # tal cual por stdin.
        pick=$(fuzzel --dmenu --prompt="Wallpaper  " < "$list_f") || exit 0
        [ -z "$pick" ] && exit 0
        "$set" "$dir/$pick"
      '';
    };
    # Hooks que consume lock.sh: perfil RGB "apagado" al bloquear, el de
    # arranque al desbloquear. Se declaran aqui (scope de Home Manager) y no en
    # openrgb.nix: alla `home.file` quedaba anidado junto a opciones NixOS del
    # usuario HM y HM lo descartaba en silencio (los hooks no existian en disco).
    "hypr/scripts/openrgb-lock-before" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec ${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules2
      '';
    };

    # Perfil RGB al APAGAR o REINICIAR. Se aplica AQUI (al iniciar el apagado)
    # y no en el ExecStop de systemd, porque a esa altura el sistema ya se esta
    # desmantelando: el proceso `openrgb -p ...` arranca, intenta re-detectar el
    # SMBus/USB (~6-14s) y muere antes de pintar nada. Confirmado en los logs de
    # OpenRGB: "NetworkClient] Connection attempt failed".
    #
    # En este punto la sesion y su servidor OpenRGB siguen VIVOS, asi que basta
    # el cliente con --nodetect (sin re-escanear el SMBus, que es lo que puede
    # colgar el equipo). El flag lo decide el primer argumento: "off" = apagar,
    # "reboot" = reiniciar.
    "hypr/scripts/power-with-rgb" = {
      executable = true;
      # `systemctl` y `poweroff` van por RUTA ABSOLUTA del store, no por nombre:
      # este script es el UNICO camino al apagado desde el menu de sesion
      # (session.commands), asi que no puede depender del PATH del shell que lo
      # invoca. `exec` al final garantiza que el codigo de salida sea el de
      # systemd y que el apagado no se pierda en un subshell.
      text = ''
        #!/usr/bin/env bash
        # Pinta el perfil de apagado ANTES de cortar energia. Best-effort DE
        # VERDAD: si OpenRGB falla O SE CUELGA, el apagado sigue igual.
        #
        # El `|| true` solo cubre un exit code distinto de cero; un cliente
        # OpenRGB colgado bloquea el shell para siempre y el `||` nunca se
        # alcanza, con lo que el menu de sesion dejaba de poder apagar el
        # equipo (hallazgo R3-OPENRGB-HANG). `timeout` acota la espera y el
        # repo ya documenta que OpenRGB puede colgarse al hablar por SMBus.
        # Ruta absoluta del store, igual que openrgb/systemctl: este script no
        # depende del PATH de quien lo invoca.
        ${pkgs.coreutils}/bin/timeout 10 ${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules2 >/dev/null 2>&1 || true
        exec ${pkgs.systemd}/bin/systemctl "$1"
      '';
    };
    "hypr/scripts/openrgb-lock-after" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        exec ${pkgs.openrgb}/bin/openrgb --client --nodetect -p RGBRules1
      '';
    };

    # Bloqueo: lo pinta Caelestia (WlSessionLock), pero ademas hay dos
    # side-effects del repo que el shell no conoce:
    #   1) cliphist wipe: el historial captura TODO (incl. passwords de
    #      KeepassXC) y quedaban en claro en ~/.cache/cliphist.
    #   2) OpenRGB: al bloquear se apaga el perfil y al volver se restaura.
    # El "after" ya no puede ser un `wait`: el IPC de Caelestia no bloquea.
    # Se sondea `lock isLocked` en segundo plano (patron ya usado en hyprdev
    # para no depender de sleeps ciegos).
    "hypr/scripts/lock.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        cliphist wipe
        [ -x "$HOME/.config/hypr/scripts/openrgb-lock-before" ] && "$HOME/.config/hypr/scripts/openrgb-lock-before"
        caelestia shell lock lock >/dev/null 2>&1 || exit 0
        # Restaura cuando el lock se libere. SIN tope de iteraciones: el lock
        # puede durar horas (antes 60x2s=120s; al agotarse pintaba RGBRules1
        # estando aun bloqueada y dejaba de correr, asi que al desbloquear de
        # verdad RGBRules1 nunca volvia). Solo se rinde si el IPC falla varias
        # veces seguidas (el shell murio/reinicia), no ante un fallo aislado.
        (
          miss=0
          while sleep 2; do
            # Binario nativo (no el CLI Python): el sondeo corre cada 2 s
            # mientras dure el lock y no vale la pena arrancar un interprete.
            locked=$(${pkgs.caelestia-shell}/bin/caelestia-shell ipc call lock isLocked 2>/dev/null || echo "")
            if [ -z "$locked" ]; then
              miss=$((miss + 1))
              [ "$miss" -ge 5 ] && exit 0
              continue
            fi
            miss=0
            [ "$locked" = "false" ] && break
          done
          [ -x "$HOME/.config/hypr/scripts/openrgb-lock-after" ] && "$HOME/.config/hypr/scripts/openrgb-lock-after"
        ) >/dev/null 2>&1 &
      '';
    };

    # hyprlock/hypridle ELIMINADOS: Caelestia trae lock (WlSessionLock) e idle
    # (IdleMonitors con los timeouts de shell.json) propios. Mantener los dos
    # sistemas pelearía por la sesión y duplicaría bloqueos.
    "hypr/scripts/switch-layout.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Solo cambia el layout. El feedback visual lo da el indicador kbLayout
        # de la barra de Caelestia (shell.json); no hay notificacion ni nativa
        # (HyprKeyboard::layoutChanged) ni DBus. "all" cambia todos los teclados.
        hyprctl switchxkblayout all next
      '';
    };

    "hypr/scripts/toggle-frost.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Alterna de un saque: esmerilado (blur + transparencia) Y neon del marco.
        # El estado vive en un marcador bajo XDG_RUNTIME_DIR (se limpia al cerrar
        # sesión, volviendo al default del config). Con config Lua "hyprctl
        # keyword" no funciona: los cambios se aplican con "hyprctl eval".
        #
        # El "neon" son TRES cosas: el gradiente de 3 colores del borde activo
        # (45 grados, 4px), el shadow exterior y el glow interior, los tres con
        # el mismo gradiente (definidos en el config de este mismo archivo).
        # Apagado queda un borde liso gris-azulado SIN sombra ni glow: se sigue
        # viendo cual esta enfocada, sin nada de neon.
        state="$XDG_RUNTIME_DIR/frost-off"
        NEON='{ "rgba(ed1044ff)", "rgba(9900ffff)", "rgba(00aaffff)" }'
        FLAT='{ "rgba(3a3a5aff)", "rgba(3a3a5aff)", "rgba(3a3a5aff)" }'

        if [ -f "$state" ]; then
          # sólido -> esmerilado + neon
          rm -f "$state"
          hyprctl eval "hl.config({ decoration = { blur = { enabled = true }, active_opacity = 0.8, inactive_opacity = 0.6, shadow = { enabled = true }, glow = { enabled = true } }, general = { col = { active_border = { colors = $NEON, angle = 45 } } } })"
          notify-send -t 2000 -a hyprland -u low "Cyberpunk ON"
        else
          # esmerilado + neon -> sólido
          touch "$state"
          hyprctl eval "hl.config({ decoration = { blur = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0, shadow = { enabled = false }, glow = { enabled = false } }, general = { col = { active_border = { colors = $FLAT, angle = 45 } } } })"
          notify-send -t 2000 -a hyprland -u low "Cyberpunk OFF"
        fi
      '';
    };

    # Mueve todas las ventanas del workspace activo a otro (N): compacta huecos
    # de escritorios vacios. Reusa el mecanismo probado (hyprctl -j
    # clients + python + hyprctl eval), porque con config Lua los strings legacy
    # de "hyprctl dispatch ..." ya no se parsean (ver time-to-work.sh).
    "hypr/scripts/workspace-move-all.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        # Arg: workspace destino N. Ventanas pinned NO se mueven (viven en todos
        # los workspaces). follow=true: estilo GNOME, la vista acompana.
        [ -n "$1" ] || exit 1
        cur=$(hyprctl -j activeworkspace 2>/dev/null | ${pkgs.python3}/bin/python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["id"])
except Exception:
    pass')
        [ -n "$cur" ] || exit 0
        [ "$cur" = "$1" ] && exit 0
        n=0
        while read -r a; do
          [ -n "$a" ] || continue
          hyprctl eval "hl.dispatch(hl.dsp.window.move({ workspace = $1, follow = true, window = \"address:$a\" }))" >/dev/null 2>&1 || true
          n=$((n+1))
        done < <(${pkgs.python3}/bin/python3 -c '
import json, sys
try:
    for w in json.load(sys.stdin):
        if w["workspace"]["id"] == int(sys.argv[1]) and not w.get("pinned"):
            print(w["address"])
except Exception:
    pass' "$cur" < <(hyprctl -j clients 2>/dev/null))
        [ "$n" -gt 0 ] && notify-send -t 2000 -a hyprland -u low "ws $cur -> $1 ($n ventanas)"
      '';
    };

    # Prueba EN VIVO las animaciones de workspace (Hyprland las da, no
    # Caelestia). No toca la config: aplica con hyprctl eval y se pierde en el
    # próximo reload/rebuild. Con argumentos `style curve` aplica directo.
    "hypr/scripts/workspace-anim.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        allowed_styles=(slide slidevert fade slidefade slidefadevert)
        allowed_curves=(standard overshot bounce bounce-natural)

        allowed() {
          local needle="$1"; shift
          for item in "$@"; do [ "$item" = "$needle" ] && return 0; done
          return 1
        }

        apply() {
          # Allowlist antes de interpolar en hyprctl eval (H2 auditoria ola 2):
          # solo estilos/curvas de los arrays; el menu ya sale de ahi.
          allowed "$1" "''${allowed_styles[@]}" || { echo "style no permitido: $1" >&2; exit 1; }
          allowed "$2" "''${allowed_curves[@]}" || { echo "curve no permitido: $2" >&2; exit 1; }
          hyprctl eval "hl.animation({ leaf = 'workspaces', enabled = true, speed = 5, bezier = '$2', style = '$1' })"
          msg="workspace-anim: style=$1 curve=$2 (temporal: se pierde en el próximo reload/rebuild)"
          echo "$msg"
          notify-send -t 2000 -a hyprland -u low "Workspace anim" "$1 / $2 (temporal)" 2>/dev/null || true
        }

        if [ -n "$2" ]; then
          apply "$1" "$2"
        else
          pick=$(for s in "''${allowed_styles[@]}"; do
            for c in "''${allowed_curves[@]}"; do
              printf '%s %s\n' "$s" "$c"
            done
          done | fuzzel --dmenu --prompt="Workspace anim  ") || exit 0
          [ -z "$pick" ] && exit 0
          read -r style curve <<< "$pick"
          apply "$style" "$curve"
        fi
      '';
    };
    # rofi/*.rasi + tema cyberpunk retirados: el launcher es Caelestia y los
    # pickers usan fuzzel (misma UI que clipboard/emoji).
  };

  xdg.mimeApps.enable = false;

  # xdg.mimeApps genera un symlink read-only al store; Dolphin no puede
  # guardar "abrir con" ahí. Se siembra un archivo real escribible (si ya
  # existe y no tiene ids rotos, KDE conserva sus asociaciones manuales).
  #
  # gwenview (kdePackages) declara org.kde.gwenview.desktop visible, así que
  # no necesita override como lo requerían imv/swayimg (NoDisplay=true).

  # nvim no trae .desktop (nixpkgs no lo empaqueta): sin él, los defaults de
  # texto del seed (text/plain=nvim.desktop, etc.) apuntan a nada y Dolphin
  # vuelve a preguntar. Entrada visible en el perfil (mismo truco).
  # gnuradio (nixpkgs) no empaqueta su .desktop: sin el, GRC no sale en el
  # menu de aplicaciones. Mismo truco que nvim: entrada visible en el perfil.
  xdg.desktopEntries.gnuradio-companion = {
    name = "GNU Radio Companion";
    exec = "gnuradio-companion %F";
    type = "Application";
    icon = "${pkgs.gnuradio}/${pkgs.python3.sitePackages}/gnuradio/grc/gui/icon.png";
    categories = [ "Development" "Electronics" ];
    mimeType = [ "application/x-gnuradio-grc" ];
  };

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
image/avif=org.kde.gwenview.desktop
image/bmp=org.kde.gwenview.desktop
image/gif=org.kde.gwenview.desktop
image/heif=org.kde.gwenview.desktop
image/jpeg=org.kde.gwenview.desktop
image/jpg=org.kde.gwenview.desktop
image/jxl=org.kde.gwenview.desktop
image/pbm=org.kde.gwenview.desktop
image/png=org.kde.gwenview.desktop
image/svg+xml=org.inkscape.Inkscape.desktop
image/tiff=org.kde.gwenview.desktop
image/webp=org.kde.gwenview.desktop
image/x-bmp=org.kde.gwenview.desktop
image/x-exr=org.kde.gwenview.desktop
image/x-portable-bitmap=org.kde.gwenview.desktop
image/x-portable-graymap=org.kde.gwenview.desktop
image/x-portable-pixmap=org.kde.gwenview.desktop
image/x-tga=org.kde.gwenview.desktop
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
    # los stubs -N (gwenview-2, firefox-2, ...) y se usa el id real. Tambien
    # los atajos que el make de omnetpp registraba ahi (ide/shell apuntando a
    # "setenv", rotos en NixOS): el paquete nuevo ya no los genera.
    rm -f "$HOME/.local/share/applications/"*-[0-9].desktop
    rm -f "$HOME/.local/share/applications/"omnetpp-*.desktop
    if [ -f "$f" ]; then
      # Migración única: si el archivo guarda ids de stubs rotos (generados por
      # el diálogo) o ids de visores de imagen muertos (imv/swayimg, reemplazados
      # por gwenview), se regenera desde el seed; si no, MERGE: se anaden los
      # tipos del seed que falten (los seeds nuevos llegan a máquinas con
      # archivo ya existente) sin tocar lo que el usuario eligió a mano en el
      # diálogo "abrir con".
      if grep -qE -- '-[0-9]+\.desktop|=imv\.desktop|=swayimg\.desktop' "$f"; then
        cp "$f" "$f.bak"
        write_seed "$f"
      else
        tmp="$(mktemp)"
        write_seed "$tmp"
        while IFS= read -r line; do
          mime=''${line%=*}
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

  # Caelestia: config.json fue un error de la migración (caelestia-cli lee
  # ÚNICAMENTE ~/.config/caelestia/cli.json, ver modules/desktop/caelestia.nix).
  # El archivo huérfano no lo gestiona Home Manager, así que se borra una vez.
  home.activation.rmObsoleteCaelestiaConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.config/caelestia/config.json"
    # Residuos de un intento viejo de gestionar el wallpaper por bateria
    # (unidades "bad/ignored" que fallaban en cada boot). Hoy lo cubre
    # mpvpaper-pause.sh + Caelestia; estos symlinks apuntan a un store muerto.
    rm -f "$HOME/.config/systemd/user/wallpaper-power-state.service" \
          "$HOME/.config/systemd/user/wallpaper-power-state.timer"
    rm -f "$HOME/.config/systemd/user/timers.target.wants/wallpaper-power-state.timer"
  '';

  # Publica los wallpapers del repo (assets/wallpapers, store read-only) en
  # ~/Pictures/Wallpapers, que es el `paths.wallpaperDir` de Caelestia y lo que
  # mira su launcher (>wallpaper). Symlinks, no copias: los mp4 pesan cientos
  # de MB y el store ya los tiene. El launcher del shell solo lista imágenes
  # (FileSystemModel.Images), así que los mp4 no aparecen ahí — se eligen con
  # SUPER+SHIFT+W (wallpaper-menu.sh). Los symlinks igual sirven para dejar
  # imágenes propias en esa carpeta.
  home.activation.materializeWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/Pictures/Wallpapers"
    run mkdir -p "$dest"
    for f in ${wallpapersDir}/*; do
      run ln -sfn "$f" "$dest/$(basename "$f")"
    done
  '';

}
