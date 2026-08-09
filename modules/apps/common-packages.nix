{ config, pkgs, lib, ... }:

let
  # ponytail: mixxx crashea en el file dialog (QGtk3Theme → g_settings_set_property abort).
  # Trigger: QT_QPA_PLATFORMTHEME=gtk3 global. Desactivamos el platform theme solo para
  # mixxx; su theming no depende de él (qt.style/kdeglobals lo cubren).
  mixxx = pkgs.symlinkJoin {
    name = "mixxx";
    paths = [ pkgs.mixxx ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      mv $out/bin/mixxx $out/bin/.mixxx-wrapped
      makeWrapper $out/bin/.mixxx-wrapped $out/bin/mixxx --unset QT_QPA_PLATFORMTHEME
    '';
  };
in
{
  imports = [ ./actual.nix ];

  # Actual Budget desktop app (todos los hosts; firefox sigue siendo el browser default)
  modules.apps.actual.enable = true;

  services.ollama.enable = true;

  # Contexto 16k: con el default de 4096, las sesiones largas de aider llenaban el
  # contexto y MTP (decodificacion especulativa) se desactivaba ("speculative
  # decoding not supported by this context") -> caia de ~44 a ~18 t/s.
  services.ollama.environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = "16384";
    # Reserva VRAM para el escritorio: sin esto ollama se come los 8GiB completos
    # y Hyprland renderiza desde GTT (ram del sistema) -> la UI se arrastra.
    # OLLAMA_GPU_OVERHEAD va en BYTES (envconfig/config.go): el valor previo de
    # 1024 era 1KiB, un no-op -> por eso el desktop seguía congelándose.
    # 1073741824 = 1GiB reservados; el resto va a IA local.
    OLLAMA_GPU_OVERHEAD = "1073741824";
  };

  environment.systemPackages = with pkgs; [
      # Browsers
    tor-browser
    brave-origin

    # Office & Productivity
    libreoffice-fresh
    keepassxc

    # LaTeX completo (scheme-full: todas las colecciones, fuentes y utilidades)
    (texlive.combine { inherit (texlive) scheme-full; })

    # Graphics & Design
    blender
    gimp
    krita
    inkscape

    # Engineering & Simulation
    kicad
    freecad
    openrocket
    openmotor
    qucs-s
    simulide
    logisim-evolution

    # Audio & Video Production
    audacity
    mixxx
    shotcut
    obs-studio
    vlc
    ffmpeg

    # AI & Development
    octave
    ollama
    aider-chat

      # Virtualization
    virt-manager

    # Networking & VPN
    proton-vpn

    # Android
    android-tools

    # Embedded & IoT (arduino, esp32, stm32)
    arduino-cli
    esptool
    stm32flash
    openocd

    # Raspberry Pi
    rpiboot
    raspberrypi-eeprom
    picocom

    # Dev toolchains
    rustup
    pnpm

    # Fun
    cbonsai

    # Audio Routing
    qpwgraph

    # Utility
    usbutils
    scrcpy
    syncthing
    smartmontools
    cmatrix
    nvtopPackages.amd
    amdgpu_top
    popsicle
  # Dolphin standalone (sin Plasma) necesita el stack KIO completo para
  # desbloquear/montar discos (kded, kio-extras: prompts de passphrase, kioslaves).
  # plasma-workspace aporta el modulo kded "soliduiserver" que muestra el dialogo
  # de passphrase al hacer click en un disco LUKS (Solid depende de el: llama a
  # org.kde.kded6 /modules/soliduiserver; sin el, el click se cuelga).
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde kio kio-extras kio-fuse kded plasma-workspace ark okular partitionmanager filelight ]);
}
