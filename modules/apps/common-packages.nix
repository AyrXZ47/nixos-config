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
  services.ollama.enable = true;

  environment.systemPackages = with pkgs; [
      # Browsers
    tor-browser

    # Office & Productivity
    libreoffice-fresh
    keepassxc

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

    # Hardware Control
    openrgb

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
    scrcpy
    syncthing
    cmatrix
    nvtopPackages.amd
    amdgpu_top
  # Dolphin standalone (sin Plasma) necesita el stack KIO completo para
  # desbloquear/montar discos (kded, kio-extras: prompts de passphrase, kioslaves).
  # plasma-workspace aporta el modulo kded "soliduiserver" que muestra el dialogo
  # de passphrase al hacer click en un disco LUKS (Solid depende de el: llama a
  # org.kde.kded6 /modules/soliduiserver; sin el, el click se cuelga).
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde kio kio-extras kio-fuse kded plasma-workspace ]);
}
