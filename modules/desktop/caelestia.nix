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
      # Transparencia/glass como el vidrio biselado del repo (0.85 base).
      transparency = {
        enabled = true;
        base = 0.85;
        layers = 0.4;
      };
    };

    general = {
      logo = "";
      showOverFullscreen = false;
      mediaGifSpeedAdjustment = 300;
      sessionGifSpeed = 0.7;
      apps = {
        terminal = [ "wezterm" ];
        audio = [ "pavucontrol" ];
        playback = [ "mpv" ];
        explorer = [ "dolphin" ];
      };
      # Antes solo existía hypridle con lock_cmd (sin timeouts); ahora el idle
      # es del shell y SÍ duerme la pantalla. El lock a los 5 min, dpms a los
      # 10, suspender+hibernar a los 30.
      idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        inhibitWhenCharging = false;
        timeouts = [
          {
            timeout = 300;
            idleAction = "lock";
            inhibitWhenAudio = true;
            inhibitWhenCharging = false;
            respectInhibitors = true;
          }
          {
            timeout = 600;
            idleAction = "dpms off";
            returnAction = "dpms on";
          }
          {
            timeout = 1800;
            idleAction = [ "suspendThenHibernate" ];
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
        showWindows = true;
        showWindowsOnSpecialWorkspaces = true;
        maxWindowIcons = 5;
        activeTrail = false;
        displayType = "shapes";
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
        hiddenIcons = [ ];
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
          id = "logo";
          enabled = true;
        }
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
        {
          id = "clock";
          enabled = true;
        }
        {
          id = "statusIcons";
          enabled = true;
        }
        {
          id = "power";
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
        kbLayoutChanged = true;
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

    fonts.packages = fonts;

    home-manager.users.yovick = {
      xdg.configFile."caelestia/shell.json".text = builtins.toJSON shellConfig;

      # El CLI (caelestia-cli) lee ~/.config/caelestia/cli.json. enableHypr=false
      # es CLAVE: por defecto el CLI escribe el esquema de color en
      # ~/.config/hypr/scheme/current.lua en cada cambio de wallpaper, y con
      # mpvpaper + Hyprland Lua eso pisaría la config del repo. Con el flag en
      # false, el esquema lo consume el shell (vía SCHEME_COLOURS del postHook)
      # y no toca Hyprland.
      xdg.configFile."caelestia/cli.json".text = builtins.toJSON {
        theme.enableHypr = false;
      };

      # El resto del tema (GTK/Qt/btop/…) no aplica: el repo ya lleva su propia
      # theming (theme-base.nix, kdeglobals, rofi cyberpunk). Caelestia solo
      # aporta el esquema de su propia UI.
      xdg.configFile."caelestia/config.json".text = builtins.toJSON {
        # Ruta absoluta: este módulo corre en el scope de NixOS, donde
        # config.xdg.configHome (opción de Home Manager) no existe.
        wallpaper.postHook = "/home/yovick/.config/hypr/scripts/caelestia-wallpaper.sh";
        theme = {
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
