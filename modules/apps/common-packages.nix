{ config, pkgs, lib, ... }:

let
  # ponytail: mixxx crashea en el file dialog (QGtk3Theme → g_settings_set_property abort).
  # Trigger: QT_QPA_PLATFORMTHEME=gtk3 global. Desactivamos el platform theme solo para
  # mixxx; su theming no depende de él (qt.style/kdeglobals lo cubren).
  #
  # Mixxx 2.5.x tiene una fuga de memoria durante el análisis de librería (aquí
  # llegó a ~53 GB de RSS → OOM global y 30s de congelamiento por el thrash de
  # swap; en análisis normal con 6k canciones no pasa de unos GB). Se lanza
  # dentro de un cgroup con MemoryMax=8G: si vuelve a fugarse, el OOM del
  # cgroup lo mata limpio y rápido, sin tocar al resto del sistema. Subir el
  # límite en este archivo si un uso legítimo lo llegara a necesitar.
  # KiCad completo: librerias, 3D, scripting, ngspice e i18n ya vienen en el
  # default de nixpkgs. Los addons oficiales (kikit: panelizado y gerber,
  # kikit-library) no, y el PCM de KiCad no puede instalarlos en el store de
  # solo lectura; se montan con el override `addons` de nixpkgs.
  kicad = pkgs.kicad.override {
    addons = with pkgs.kicadAddons; [ kikit kikit-library ];
  };
  mixxx = pkgs.symlinkJoin {
    name = "mixxx";
    paths = [ pkgs.mixxx ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      mv $out/bin/mixxx $out/bin/.mixxx-wrapped
      makeWrapper ${pkgs.systemd}/bin/systemd-run $out/bin/mixxx \
        --unset QT_QPA_PLATFORMTHEME \
        --add-flags "--user --scope --quiet -p MemoryMax=8G" \
        --add-flags "$out/bin/.mixxx-wrapped"
    '';
  };
  # Shotcut busca `ffmpeg` y `whisper-cli` EN EL MISMO DIRECTORIO que su propio
  # binario (applicationDirPath): subtitlesdock.cpp:666 y settings.cpp:2049.
  # En nixpkgs no viven ahí, así que "Import Subtitles" dice "ffmpeg not found"
  # y el Speech-to-Text invoca al propio shotcut (que rechaza los flags de
  # whisper). Fix: symlinkJoin que los coloca junto a shotcut.
  # REGLA GENERAL GPU: whisper-cpp va con vulkanSupport (RX 7600).
  # ponytail: si nixpkgs algún día empaqueta shotcut con ambos adyacentes,
  # borrar el wrapper y volver al paquete plano.
  shotcut = pkgs.symlinkJoin {
    name = "shotcut";
    paths = [ pkgs.shotcut ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ln -s ${pkgs.ffmpeg_8}/bin/ffmpeg $out/bin/ffmpeg
      ln -s ${
        (pkgs.whisper-cpp.override { vulkanSupport = true; })
      }/bin/whisper-cli $out/bin/whisper-cli
    '';
  };
in
{
  imports = [ ./actual.nix ./omnetpp.nix ./python.nix ];

  # Actual Budget desktop app (todos los hosts; firefox sigue siendo el browser default)
  modules.apps.actual.enable = true;

  # Wireshark: el modulo de NixOS instala el wrapper setuid de dumpcap; el
  # usuario va en el grupo "wireshark" (ver modules/core/user.nix) para poder
  # capturar sin ser root.
  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  services.ollama.enable = true;

  # Contexto 16k por defecto (el default de ollama es 4096): sesiones largas
  # llenaban el contexto y desactivaban MTP (decodificacion especulativa)
  # ("speculative decoding not supported by this context") -> caia de ~44 a ~18 t/s.
  # OJO (leccion R1): esta env var NO aplica a modelos con num_ctx propio en su
  # Modelfile (qwen3.8:27b fija 131072 y la ignora). El control real es el num_ctx
  # por request (cliente: Obsidian Copilot, `ollama run --num-ctx`). Con 8 GiB de
  # VRAM usar num_ctx <= 8192: el KV cache de 131k no cabe y la maquina se traba.
  services.ollama.environmentVariables = {
    OLLAMA_CONTEXT_LENGTH = "16384";
    # Truco 1: flash attention -> menos VRAM para el KV cache y atencion mas rapida.
    # Truco 2: KV cache en q8_0 (mitad de memoria que f16) -> mas capas caben en la
    # GPU. Ambos suman ~5-15% de t/s; el 2x real viene de MoE a3b + num_ctx 8192.
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
    # Reserva VRAM para el escritorio: sin esto ollama se come los 8GiB completos
    # y Hyprland renderiza desde GTT (ram del sistema) -> la UI se arrastra.
    # OLLAMA_GPU_OVERHEAD va en BYTES (envconfig/config.go): el valor previo de
    # 1024 era 1KiB, un no-op -> por eso el desktop seguía congelándose.
    # Medido en la máquina real: escritorio en reposo = 0.9 GiB de VRAM; con
    # overhead 1GiB ollama llega a 7.8 GiB totales -> headroom real 0.2 GiB ->
    # Hyprland cae a GTT -> micro-congelamientos. El overhead debe cubrir el uso
    # del escritorio (0.9 GiB) + margen: 2GiB = ~1.1 GiB libres de verdad.
    # 2147483648 = 2GiB. Coste: ~8 t/s (27 vs 35 medidos) - aceptado.
    OLLAMA_GPU_OVERHEAD = "2147483648";
    # Micro-congelamientos parte 2: saturación de CPU. Con 23 GB de modelo y
    # 8 GiB de VRAM, ollama corre ~73% del cómputo en CPU (medido: 73%/27%
    # CPU/GPU) y los 16 hilos se saturan -> Hyprland no tiene CPU. Limitar a 12
    # hilos deja 4 garantizados al escritorio; coste ~10% de t/s.
    # La combinación 2GiB overhead + 12 hilos es la que elimina AMBAS causas.
    OLLAMA_CPU_THREADS = "12";
  };

  environment.etc."xdg/menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/menu-1.0.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <DefaultMergeDirs/>
      <Layout>
        <Merge type="all"/>
      </Layout>
    </Menu>
  '';

  environment.systemPackages = with pkgs; [
      # Browsers
    tor-browser
    brave-origin

    # Office & Productivity
    libreoffice-fresh
    keepassxc

    # LaTeX completo (scheme-full: todas las colecciones, fuentes y utilidades)
    (texlive.withPackages (ps: [ ps.scheme-full ]))

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

    # Telecomunicaciones (universidad)
    # 4nec2 es Windows-only; xnec2c es su equivalente libre en Linux (mismo
    # motor NEC2, GUI con diagramas de radiacion y Smith). openems existe en
    # nixpkgs pero es FDTD por consola (sin GUI): exagerado para el curso.
    # geogebra6 ELIMINADO (2026-08-16): upstream borró la URL del tarball
    # 6-0-794 (404) y el humano no lo usa — YAGNI. Si vuelve a necesitarse,
    # verificar version actual en download.geogebra.org/installers/6.0/.
    xnec2c
    wireshark
    # GNU Radio + GRC (gnuradio-companion): radio definida por software/SDR
    gnuradio

    # Audio & Video Production
    audacity
    mixxx
    shotcut
    obs-studio
    vlc
    # ffmpeg-full: incluye libplacebo (tonemap HDR por GPU vía Vulkan) y
    # libzimg, necesarios para convertir clips HDR10+ a SDR sin lavarlos.
    ffmpeg-full

    # AI & Development
    octave
    ollama
    # whisper-cpp con GPU ya va DENTRO del wrapper de shotcut (mismo bin/).
    # Aquí NO se instala suelto para no duplicar el binario en el system path:
    # el wrapper de shotcut ya expone whisper-cli adyacente a shotcut, que es
    # donde Shotcut lo busca. `subtitular` (shell.nix) usa el mismo whisper-cli
    # del PATH, y el wrapper lo provee vía systemPackages.

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
    qalculate-gtk
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
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde kio kio-extras kio-fuse kded plasma-workspace ark okular ffmpegthumbs partitionmanager filelight ]);
}
