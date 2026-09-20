{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.modules.desktop.caelestia;

  # Fuentes que las plantillas del shell piden (Sass/Qt QML resuelven por
  # fontconfig; Material Symbols es la de los iconos, Rubik la de la UI).
  fonts = with pkgs; [
    material-symbols
    rubik
    nerd-fonts.caskaydia-cove
  ];

  # Runtime que el shell invoca por nombre (la derivación de nixpkgs ya lo
  # envuelve, pero se instala explícito para que lo vea el PATH de la sesión y
  # no dependa de que el wrapper del paquete se use para lanzarlo).
  cliRuntime = with pkgs; [
    fuzzel
    slurp
    grim
    swappy
    gpu-screen-recorder
    dart-sass
    cliphist
  ];

  # --- shell.json ---------------------------------------------------------
  # Generado como VALUE nativo de Nix y serializado con builtins.toJSON: así el
  # JSON siempre es válido y se puede editar sin miedo a comas colgantes
  # (escribirlo como text a mano invita a errores). Cubre el inventario Wayle:
  # barra a la izquierda (de fábrica en Caelestia), workspaces con iconos de
  # ventana (hyprdev/wezterm/steam), statusIcons, dashboard + session, idle
  # con los timeouts que antes no existían, lock con fprint del laptop.
  shellConfig = {
    appearance = {
      deformScale = 1;
      rounding.scale = 1;
      spacing.scale = 1;
      padding.scale = 1;
      font = {
        scale = 1;
        clock = "Rubik";
        workspaces = "Rubik";
      };
      anim.durations.scale = 1;
      # Transparencia/glass ~66% (antes 0.85, casi opaco).
      transparency = {
        enabled = true;
        base = 0.34;
        layers = 0.5;
      };
    };

    general = {
      # Logo de la barra: snowflake de NixOS (ruta absoluta; SysInfo la soporta
      # via Paths.absolutePath). Con "" caía al logo de Caelestia porque
      # Quickshell.iconPath("nix-snowflake") no lo encuentra fuera del tema.
      logo = "/run/current-system/sw/share/icons/hicolor/256x256/apps/nix-snowflake.png";
      showOverFullscreen = false;
      mediaGifSpeedAdjustment = 300;
      sessionGifSpeed = 0.7;
      apps = {
        terminal = [ "kitty" ];
        audio = [ "pavucontrol" ];
        playback = [ "mpv" ];
        explorer = [ "dolphin" ];
      };
      # Idle del shell: SOLO apaga la pantalla (dpms) a los 10 min. Sin autolock
      # ni suspensión (sin swap en disco, no habría hibernación real); el lock
      # es siempre manual.
      idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        inhibitWhenCharging = false;
        timeouts = [
          {
            timeout = 600;
            idleAction = "dpms off";
            returnAction = "dpms on";
          }
        ];
      };
      battery.warnLevels = [
        {
          level = 20;
          title = "Batería baja";
          message = "Te recomendamos conectar el cargador";
          icon = "battery_android_frame_2";
        }
        {
          level = 10;
          title = "Sigues sin conectar";
          message = "Conecta el cargador <b>ahora</b>";
          icon = "battery_android_frame_1";
        }
        {
          level = 5;
          title = "Batería crítica";
          message = "CONECTA EL CARGADOR YA!!";
          icon = "battery_android_alert";
          critical = true;
        }
      ];
      battery.criticalLevel = 3;
    };

    background = {
      enabled = true;
      # mpvpaper es el dueño del fondo (ver el postHook más abajo): Caelestia NO
      # pinta wallpaper. El visualiser sí queda activo (antes era el módulo cava
      # de la barra de Wayle).
      wallpaperEnabled = false;
      desktopClock = {
        enabled = false;
        scale = 1.0;
        position = "bottom-right";
        invertColors = false;
        background = {
          enabled = false;
          opacity = 0.7;
          blur = true;
        };
        shadow = {
          enabled = true;
          opacity = 0.7;
          blur = 0.4;
        };
      };
      visualiser = {
        enabled = true;
        autoHide = true;
        blur = false;
        rounding = 1;
        spacing = 1;
      };
    };

    bar = {
      persistent = true;
      showOnHover = true;
      dragThreshold = 20;
      scrollActions = {
        workspaces = true;
        volume = true;
        brightness = true;
      };
      popouts = {
        activeWindow = true;
        tray = true;
        statusIcons = true;
      };
      workspaces = {
        shown = 5;
        activeIndicator = true;
        occupiedBg = false;
        # Iconos de app por workspace: Caelestia NO deduplica (pinta uno por
        # ventana). El dedupe real (1 icono por clase) vive en el parche QML de
        # flake.nix sobre caelestia-shell; aquí se deja el máximo de iconos
        # visibles para que ese dedupe tenga margen.
        showWindows = true;
        showWindowsOnSpecialWorkspaces = true;
        maxWindowIcons = 8;
        # Estela fluida del indicador al cambiar de workspace.
        activeTrail = true;
        # Formas Material ("figuritas" del morphing) en vez de texto. Labels
        # vacíos -> cae al número del workspace.
        displayType = "shapes";
        label = "";
        occupiedLabel = "";
        activeLabel = "";
        capitalisation = "preserve";
        workspaceIcons = [ ];
        specialWorkspaceIcons = [
          {
            name = "special";
            icon = "star";
          }
          {
            name = "communication";
            icon = "forum";
          }
          {
            name = "music";
            icon = "music_cast";
          }
          {
            name = "todo";
            icon = "checklist";
          }
          {
            name = "sysmon";
            icon = "monitor_heart";
          }
        ];
        ignoredTags = [
          "hide_in_bar"
          "xwl_popup"
        ];
        # Wayle deduplicaba por clase (app-icons-dedupe): todas las ventanas de
        # hyprdev comparten clase hyprdev-<runid>, así que un glob las colapsa
        # en un icono de terminal. El resto replica el mapeo de los dots.
        windowIcons = [
          {
            regex = "hyprdev.*";
            icon = "terminal";
          }
          {
            regex = "^(org\\.wezfurlong\\.wezterm)$";
            icon = "terminal";
          }
          {
            regex = "steam(_app_(default|[0-9]+))?";
            icon = "sports_esports";
          }
        ];
      };
      activeWindow = {
        compact = false;
        inverted = false;
        showOnHover = true;
      };
      tray = {
        background = false;
        recolour = false;
        compact = false;
        iconSubs = [ ];
        # qpwgraph arranca minimizado al tray (patchbay de PipeWire): su icono
        # solo sirve para reabrir la UI, asi que se oculta. El id del
        # StatusNotifierItem es el applicationName de Qt ("qpwgraph").
        hiddenIcons = [ "qpwgraph" ];
      };
      clock = {
        background = false;
        showDate = false;
        showIcon = true;
      };
      statusIcons = [
        {
          id = "lockStatus";
          enabled = true;
        }
        {
          id = "audio";
          enabled = false;
        }
        {
          id = "microphone";
          enabled = false;
        }
        {
          id = "kbLayout";
          enabled = false;
        }
        {
          id = "network";
          enabled = true;
        }
        {
          id = "bluetooth";
          enabled = true;
        }
        {
          id = "battery";
          enabled = true;
        }
      ];
      entries = [
        {
          id = "workspaces";
          enabled = true;
        }
        {
          id = "spacer";
          enabled = true;
        }
        {
          id = "activeWindow";
          enabled = true;
        }
        {
          id = "spacer";
          enabled = true;
        }
        {
          id = "tray";
          enabled = true;
        }
        # clock fuera: el reloj/calendario no aporta en esta barra.
        {
          id = "statusIcons";
          enabled = true;
        }
        # power fuera: el apagado/logout vive en el menu de sesion
        # (SUPER+CTRL+Q). El logo NixOS (abre el launcher) va al fondo, en el
        # hueco que dejaba el apagado.
        {
          id = "logo";
          enabled = true;
        }
      ];
      excludedScreens = [ ];
    };

    border = {
      thickness = 10;
      rounding = 25;
      smoothing = 20;
    };

    dashboard = {
      enabled = true;
      showOnHover = true;
      showDashboard = true;
      showMedia = true;
      showPerformance = true;
      # Sin weatherLocation ni API keys: se apaga (el resto del dashboard
      # reemplaza al dropdown de Wayle: media + performance + lock/logout/…).
      showWeather = false;
      mediaUpdateInterval = 500;
      resourceUpdateInterval = 1000;
      dragThreshold = 50;
      performance = {
        showBattery = true;
        showGpu = true;
        showCpu = true;
        showMemory = true;
        showStorage = true;
        showNetwork = true;
      };
    };

    launcher = {
      enabled = true;
      showOnHover = false;
      maxShown = 7;
      maxWallpapers = 9;
      specialPrefix = "@";
      actionPrefix = ">";
      enableDangerousActions = false;
      dragThreshold = 50;
      vimKeybinds = false;
      favouriteApps = [ ];
      hiddenApps = [ ];
      useFuzzy = {
        apps = false;
        actions = false;
        schemes = false;
        variants = false;
        wallpapers = false;
      };
      # Acciones del launcher (>). Sustituyen a rofi: el prefijo `>` las lista.
      # Se reemplaza la lista entera (en este sistema de config un valor de
      # usuario pisa el default), así que van incluidas las que traía el shell
      # (Scheme/Variant/Light/Dark/Shutdown/Reboot/Logout/Lock/Sleep/Settings)
      # más las funciones propias del repo que antes vivían en rofi o en atajos
      # sueltos. Las de apagado quedan como `dangerous`.
      actions = [
        {
          name = "Wallpaper";
          icon = "image";
          description = "Elegir wallpaper (video o imagen)";
          command = [ "/home/yovick/.config/hypr/scripts/wallpaper-menu.sh" ];
        }
        {
          name = "Random wallpaper";
          icon = "casino";
          description = "Wallpaper aleatorio";
          command = [ "/home/yovick/.config/hypr/scripts/wallpaper-cycle.sh" ];
        }
        {
          name = "Scheme";
          icon = "palette";
          description = "Cambiar el esquema de color";
          command = [ "autocomplete" "scheme" ];
        }
        {
          name = "Cyberpunk";
          icon = "palette";
          description = "Volver al esquema cyberpunk";
          command = [ "caelestia" "scheme" "set" "-n" "cyberpunk" ];
        }
        {
          name = "Variant";
          icon = "colors";
          description = "Cambiar la variante del esquema";
          command = [ "autocomplete" "variant" ];
        }
        {
          name = "Light";
          icon = "light_mode";
          description = "Esquema en modo claro";
          command = [ "setMode" "light" ];
        }
        {
          name = "Dark";
          icon = "dark_mode";
          description = "Esquema en modo oscuro";
          command = [ "setMode" "dark" ];
        }
        {
          name = "Settings";
          icon = "settings";
          description = "Configurar el shell";
          command = [ "caelestia" "shell" "nexus" "open" ];
        }
        {
          name = "Clipboard";
          icon = "content_paste";
          description = "Historial del portapapeles";
          command = [ "caelestia" "clipboard" ];
        }
        {
          name = "Emoji";
          icon = "emoji_emotions";
          description = "Selector de emojis";
          command = [ "caelestia" "emoji" "-p" ];
        }
        {
          name = "Color picker";
          icon = "colorize";
          description = "Copiar el color de un pixel";
          command = [ "hyprpicker" "-a" "-f" "hex" ];
        }
        {
          name = "Screenshot";
          icon = "screenshot_region";
          description = "Captura de region";
          command = [ "hyprshot" "-m" "region" "-o" "/home/yovick/Pictures/Screenshots" ];
        }
        {
          name = "Next wallpaper";
          icon = "skip_next";
          description = "Siguiente wallpaper aleatorio";
          command = [ "/home/yovick/.config/hypr/scripts/wallpaper-cycle.sh" ];
        }
        {
          name = "Lock";
          icon = "lock";
          description = "Bloquear la sesion";
          command = [ "/home/yovick/.config/hypr/scripts/lock.sh" ];
        }
        {
          name = "Logout";
          icon = "logout";
          description = "Cerrar la sesion";
          command = [ "logout" ];
          dangerous = true;
        }
        {
          name = "Shutdown";
          icon = "power_settings_new";
          description = "Apagar";
          command = [ "poweroff" ];
          dangerous = true;
        }
        {
          name = "Reboot";
          icon = "restart_alt";
          description = "Reiniciar";
          command = [ "reboot" ];
          dangerous = true;
        }
      ];
    };

    # fprint del laptop (el sensor ya funciona vía fprintd, ver
    # modules/hardware/fingerprint.nix). Howdy NO está instalado.
    lock = {
      enabled = true;
      useWallpaper = false;
      recolourLogo = true;
      enableFprint = true;
      maxFprintTries = 3;
      enableHowdy = false;
      maxHowdyTries = 3;
      triggerHowdyOnWake = false;
      hideNotifs = false;
    };

    nexus = {
      wallpapersPerRow = 4;
      networkRescanInterval = 15000;
    };

    notifs = {
      expire = true;
      fullscreen = "On";
      defaultExpireTimeout = 5000;
      fullscreenExpireTimeout = 2000;
      clearThreshold = 0.3;
      expandThreshold = 20;
      actionOnClick = false;
      groupPreviewNum = 3;
      openExpanded = false;
    };

    osd = {
      enabled = true;
      hideDelay = 2000;
      enableBrightness = true;
      enableMicrophone = false;
    };

    services = {
      weatherLocation = "";
      # Celsius explícito: el default se adivina por locale y puede caer en
      # imperial.
      useFahrenheit = false;
      useFahrenheitPerformance = false;
      gpuType = "Auto";
      # 44 barras + espejo: el visualiser de fondo hereda el look del módulo
      # cava de la barra de Wayle (que en Caelestia no existe como módulo).
      visualiserBars = 44;
      audioIncrement = 0.1;
      brightnessIncrement = 0.1;
      maxVolume = 1.0;
      smartScheme = true;
      defaultPlayer = "mpv";
      playerAliases = [ ];
    };

    session = {
      enabled = true;
      dragThreshold = 30;
      vimKeybinds = false;
      icons = {
        logout = "logout";
        shutdown = "power_settings_new";
        hibernate = "downloading";
        reboot = "cached";
      };
      commands = {
        logout = [ "logout" ];
        shutdown = [ "poweroff" ];
        hibernate = [ "hibernate" ];
        reboot = [ "reboot" ];
      };
    };

    sidebar = {
      enabled = true;
      showOnHover = false;
      minHoverThreshold = 200;
      dragThreshold = 80;
    };

    utilities = {
      enabled = true;
      maxToasts = 4;
      cards = {
        keepAwake = true;
        recorder = true;
        quickToggles = true;
      };
      toasts = {
        fullscreen = "off";
        configLoaded = false;
        chargingChanged = true;
        gameModeChanged = true;
        dndChanged = true;
        audioOutputChanged = true;
        audioInputChanged = true;
        capsLockChanged = true;
        numLockChanged = true;
        kbLayoutChanged = false;
        kbLimit = true;
        vpnChanged = true;
        nowPlaying = false;
      };
      vpn = {
        enabled = false;
        provider = [ ];
      };
      quickToggles = [
        {
          id = "wifi";
          enabled = true;
        }
        {
          id = "bluetooth";
          enabled = true;
        }
        {
          id = "mic";
          enabled = true;
        }
        {
          id = "settings";
          enabled = true;
        }
        {
          id = "gameMode";
          enabled = true;
        }
        {
          id = "dnd";
          enabled = true;
        }
        {
          id = "vpn";
          enabled = false;
        }
      ];
    };

    paths = {
      # El launcher de wallpapers lee SOLO imágenes; los mp4 los sirve mpvpaper
      # por el postHook. Se apunta a ~/Pictures/Wallpapers (no al store de
      # assets/) porque el CLI hace `rglob` + filtro de tamaño y quiere una
      # carpeta escribible y estable, no una ruta de solo lectura que cambia.
      wallpaperDir = "~/Pictures/Wallpapers";
      lyricsDir = "~/Music/Lyrics/";
      sessionGif = "root:/assets/kurukuru.gif";
      mediaGif = "root:/assets/bongocat.gif";
      noNotifsPic = "root:/assets/dino.png";
      lockNoNotifsPic = "root:/assets/dino.png";
    };
  };
in
{
  options.modules.desktop.caelestia = {
    enable = lib.mkEnableOption "Caelestia shell (Quickshell)";

    # JSON por defecto de shell.json, materializado en el store. Lo consume el
    # activation de hyprland-home.nix para sembrarlo como archivo real (editable
    # por Nexus). Se expone como opción de solo lectura para cruzar el límite
    # NixOS -> Home Manager sin duplicar el objeto.
    shellJsonPath = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = "Ruta en el store con el shell.json por defecto de Caelestia.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Caelestia no está en nixpkgs como módulo de NixOS ni en Home Manager
    # upstream: se instala el paquete (con el CLI embebido) y la config estática
    # va por xdg.configFile de Home Manager.
    environment.systemPackages = [
      pkgs.caelestia-shell
      pkgs.caelestia-cli
      pkgs.quickshell
    ] ++ fonts ++ cliRuntime;

    modules.desktop.caelestia.shellJsonPath = pkgs.writeText "caelestia-shell.json" (builtins.toJSON shellConfig);

    fonts.packages = fonts;

    home-manager.users.yovick = {
      # shell.json NO va por xdg.configFile: seria un symlink read-only al store
      # y Nexus/Caelestia lo escriben en runtime -> "Failed to save config" en
      # cada cambio. Se siembra como archivo real con el servicio systemd de
      # abajo (idempotente: solo copia si no existe, respeta ediciones).
      #
      # config.json fue un error de la migración (el CLI solo lee cli.json): el
      # borrado vive en hyprland-home.nix, en scope de Home Manager (ahí sí hay
      # lib.hm.dag para ordenarlo tras writeBoundary).

      # OJO: caelestia-cli lee UN SOLO archivo para todo, `cli.json`
      # (`user_config_path = c_config_dir / "cli.json"` en utils/paths.py). Otra
      # ruta (config.json) se ignora por completo — error que dejó a mpvpaper
      # sin arrancar en el primer boot. Aqui va TODO lo del CLI:
      #  - theme.enableHypr=false: el CLI escribe el esquema de color en
      #    ~/.config/hypr/scheme/current.lua por defecto; con mpvpaper + Hyprland
      #    Lua eso pisaría la config del repo. El esquema lo consume el shell.
      #  - theme.enable*: el resto del theming ya lo lleva el repo
      #    (theme-base.nix, kdeglobals, rofi cyberpunk); Caelestia solo aporta el
      #    esquema de su propia UI.
      #  - wallpaper.postHook: arranca mpvpaper con el fondo real.
      xdg.configFile."caelestia/cli.json".text = builtins.toJSON {
        theme = {
          enableHypr = false;
          enableGtk = false;
          enableQt = false;
          enableBtop = false;
          enableHtop = false;
          enableNvtop = false;
          enableCava = false;
          enableDiscord = false;
          enableChromium = false;
          enableSpicetify = false;
          enableWarp = false;
          enableZed = false;
        };
        # Ruta absoluta: este módulo corre en el scope de NixOS, donde
        # config.xdg.configHome (opción de Home Manager) no existe.
        wallpaper.postHook = "/home/yovick/.config/hypr/scripts/caelestia-wallpaper.sh";
      };

      # --- Siembra de shell.json -----------------------------------------------
      # Corre en CADA `home-manager switch` (activation), no al login. El
      # servicio systemd anterior no arrancaba al cambiar de generación (el
      # target ya estaba activo) y shell.json quedaba sin crear -> Caelestia
      # usaba los defaults y "ningún cambio se aplicaba" (visto 2026-09-19: el
      # symlink viejo lo borró Home Manager al dejar de gestionarlo). Idempotente:
      #   - symlink previo al store (migración vieja) -> se reemplaza por copia.
      #   - archivo real ya editado por Nexus -> se respeta, NO se toca.
      #   - no existe -> se copia el default del repo.
      # El shell vigila shell.json (SettingsFile/QFileSystemWatcher) y lo
      # recarga en caliente, así que tras el switch no hace falta reiniciar.
      # Para volver al default: borrar ~/.config/caelestia/shell.json y rebuild.
      home.activation.caelestiaSeedConfig = {
        after = [ "writeBoundary" ];
        before = [ ];
        data = ''
          f="$HOME/.config/caelestia/shell.json"
          mkdir -p "$(dirname "$f")"
          # Symlink al store (read-only) de una generación anterior: fuera.
          if [ -L "$f" ]; then rm -f "$f"; fi
          # Archivo real: es del usuario (editado en Nexus), se respeta.
          if [ ! -f "$f" ]; then
            cp ${config.modules.desktop.caelestia.shellJsonPath} "$f"
            chmod u+w "$f"
          fi
        '';
      };

      # Reproducibilidad de la paleta: el esquema cyberpunk vive en el overlay
      # de caelestia-cli (read-only) y `scheme set` lo persiste en estado de
      # usuario, que NO se comparte entre hosts ni sobrevive a un borrado de
      # ~/.local/state. Re-aplicarlo aquí garantiza la misma paleta en todos.
      # ponytail: fija cyberpunk a propósito; si se quisieran esquemas
      # dinámicos, basta quitar este activation.
      home.activation.caelestiaCyberpunkScheme = {
        after = [ "writeBoundary" ];
        before = [ ];
        data = ''
          if command -v caelestia >/dev/null 2>&1; then
            cur=$(caelestia scheme get -n 2>/dev/null || true)
            if [ "$cur" != "cyberpunk" ]; then
              caelestia scheme set -n cyberpunk >/dev/null 2>&1 || true
            fi
          fi
        '';
      };
    };

    # El lock de Caelestia (WlSessionLock) usa sus propias unidades PAM en
    # assets/pam.d/{passwd,fprint,howdy}, NO /etc/pam.d. Pero el fprint tiene
    # una trampa conocida del repo (README): con services.fprintd.enable,
    # security.pam.services.<name>.fprintAuth defaulta a true. Eso solo afecta
    # a los servicios de /etc/pam.d (login/sddm/sudo/hyprlock), no al lock del
    # shell, así que no se toca aquí.
  };
}
