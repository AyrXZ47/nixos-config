{ config, pkgs, lib, ... }:

{
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
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde ]);
}
