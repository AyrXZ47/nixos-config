# Producción multimedia para pc/laptop: imagen, video, audio y el stack de
# Mixxx. La VM no lo importa (no tiene GPU para Vulkan ni necesita las suites).
{ config, pkgs, lib, ... }:

let
  # ponytail: mixxx crashea en el file dialog (QGtk3Theme → g_settings_set_property abort).
  # Trigger: QT_QPA_PLATFORMTHEME=gtk3 global. Desactivamos el platform theme solo para
  # mixxx; su theming no depende de él (qt.style/kdeglobals lo cubren).
  #
  # Mixxx es Wayland puro (Qt Wayland). El único uso de X11 es
  # getCurrentXkbLayoutName() -> XkbOpenDisplay, para adivinar el layout del
  # teclado. Si DISPLAY existe (la sesión exporta :0) y Xwayland está roto,
  # ese connect se cuelga para siempre y Mixxx nunca abre. Sin DISPLAY el
  # probe devuelve vacío y cae a QLocale: Mixxx no necesita Xwayland.
  #
  # Mixxx 2.5.x tiene una fuga de memoria durante el análisis de librería (aquí
  # llegó a ~53 GB de RSS → OOM global y 30s de congelamiento por el thrash de
  # swap; en análisis normal con 6k canciones no pasa de unos GB). Se lanza
  # dentro de un cgroup con MemoryMax=8G: si vuelve a fugarse, el OOM del
  # cgroup lo mata limpio y rápido, sin tocar al resto del sistema. Subir el
  # límite en este archivo si un uso legítimo lo llegara a necesitar.
  #
  # El MPRIS falso (mixxx-mpris.service) ya no arranca solo: se levanta y se
  # para alrededor de Mixxx desde este envoltorio.
  mixxx = pkgs.symlinkJoin {
    name = "mixxx";
    paths = [ pkgs.mixxx ];
    postBuild = ''
mv $out/bin/mixxx $out/bin/.mixxx-wrapped
cat > $out/bin/mixxx <<'EOF'
#!/bin/sh
# MPRIS falso (mixxx-mpris.service): arranca con Mixxx y se para al salir.
${pkgs.systemd}/bin/systemctl --user start mixxx-mpris.service >/dev/null 2>&1 || true
trap '${pkgs.systemd}/bin/systemctl --user stop mixxx-mpris.service >/dev/null 2>&1 || true' EXIT
# Sin JACK: Mixxx usa ALSA/PipeWire. services.pipewire.jack se quito por
# el warning de LD_LIBRARY_PATH global y no hace falta pw-jack.
unset QT_QPA_PLATFORMTHEME DISPLAY
# El scope con MemoryMax=8G contiene la fuga de memoria del análisis.
self=$(${pkgs.coreutils}/bin/readlink -f "$0")
${pkgs.systemd}/bin/systemd-run --user --scope --quiet -p MemoryMax=8G \
  "$(${pkgs.coreutils}/bin/dirname "$self")/.mixxx-wrapped" "$@"
EOF
chmod +x $out/bin/mixxx
    '';
  };
  # GPU (RX 7600): whisper-cpp con soporte Vulkan. Va como paquete PROPIO en
  # systemPackages, NO como symlink dentro de shotcut.
  #
  # HISTORIA (por que ya no hay override de shotcut): antes se hacia
  # `shotcut.overrideAttrs` para plantar ffmpeg y whisper-cli junto a su
  # binario, porque Shotcut los busca en su applicationDirPath ("Import
  # Subtitles" en subtitlesdock.cpp:666 y Speech-to-Text en settings.cpp:2049).
  # El costo oculto: ese override le daba a shotcut un hash unico que NADIE mas
  # posee, asi que cache.nixos.org devolvia 404 y CADA `nix flake update`
  # recompilaba 207 archivos C++ (~10 min) en la laptop. Se elimino: shotcut
  # vuelve al binario de Hydra (cache instantaneo) y whisper-cli se expone en
  # el PATH del sistema, que es exactamente donde `subtitular` (shell.nix) ya
  # lo busca. Lo unico que se pierde son los dos menus internos de Shotcut; el
  # flujo real es generar el .srt con `subtitular` e importarlo como pista.
  whisperVulkan = pkgs.whisper-cpp.override { vulkanSupport = true; };
in
{
  # El MPRIS falso de Mixxx vive en Home Manager (servicio de usuario).
  home-manager.users.yovick.imports = [ ./mixxx-mpris.nix ];

  environment.systemPackages = with pkgs; [
    # Graphics & Design
    blender
    gimp
    krita
    inkscape
    # realesrgan-ncnn-vulkan: upscale x2/x3/x4 con Real-ESRGAN (red GAN) por
    # Vulkan en la GPU. Sirve para rescatar archivos que vienen chicos antes de
    # mandarlos a imprenta. Modelos: realesrgan-x4plus (foto/arte mixto),
    # realesrgan-x4plus-anime (arte plano duro), realesrnet-x4plus (mas fiel,
    # menos nitido).
    realesrgan-ncnn-vulkan

    # Audio & Video Production
    # audacity volvio a nixpkgs (2026-10-24): lo que compilaba en cada update era
    # el overlay unstableFixes (ya removido), no el paquete. 4.0.0 esta cacheado
    # en Hydra: 37 MB de descarga, cero compilacion. Flatpak se fue.
    audacity
    mixxx
    shotcut
    obs-studio
    vlc
    # whisper-cli en el PATH del sistema para `subtitular` (shell.nix), con
    # Vulkan para la RX 7600. Es el mismo binario GPU que usaba Shotcut, solo
    # que ahora vive donde el flujo de subtitulos ya lo busca.
    whisperVulkan
  ] ++ (with pkgs.kdePackages; [
    # Miniaturas de video en Dolphin (el thumbnailer de KDE).
    ffmpegthumbs
  ]);
}
