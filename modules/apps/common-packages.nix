{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    # Browsers
    firefox
    tor-browser-bundle-bin

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

    # AI & Development
    octave
    ollama
    aider-chat

    # Virtualization
    gnome-boxes

    # Networking & VPN
    proton-vpn

    # Hardware Control
    openrgb

    # Audio Routing
    qpwgraph
    pwvucontrol

    # Utility
    scrcpy
    syncthing
  ] ++ (with pkgs.kdePackages; [ dolphin kdeconnect-kde ]);
}
