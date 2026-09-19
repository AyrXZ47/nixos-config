{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/caelestia.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/hardware/nvme-dramless.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/flatpak.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/rust-dev.nix
    ../../modules/apps/packettracer.nix
    ../../modules/apps/vivado.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/docker.nix
  ];

  # Packet Tracer (universidad): el .deb se baja solo (Archive.org) en el rebuild.
  modules.apps.packetTracer.enable = true;

  # Vivado (FPGA/Arquitectura de computadoras): wrapper FHS en el PATH; la
  # instalación vive en ~/opt/Xilinx (hecha a mano con xsetup, cuenta AMD).
  modules.apps.vivado.enable = true;

  modules.desktop.hyprland.enable = true;
  modules.desktop.caelestia.enable = true;

  modules.hardware.fingerprint.enable = true;

  # openrgb: por si esta laptop llega a tener luces que controlar (perfiles a mano).
  environment.systemPackages = [ pkgs.openrgb pkgs.dnsmasq ];

  # fwupd: servicio para actualizar firmware (BIOS/SSD). Uso: `fwupdmgr refresh && fwupdmgr update`.
  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-laptop";

  # kdeconnect: abre puertos 1714-1764 TCP/UDP que el firewall bloqueaba
  # (sin esto el daemon corre pero no descubre/conecta dispositivos).
  programs.kdeconnect.enable = true;

  # Miracast (gnome-network-displays -> Smart View de TVs Samsung). La fase 2
  # de la conexion P2P hace que NM monte una red compartida con dnsmasq
  # (servidor DHCP en la interfaz p2p-dev-wlp3s0) y luego corre RTSP de WFD
  # en el puerto 7236. Sin dnsmasq en PATH ni estos puertos el link se arma
  # pero la TV nunca recibe IP / nunca conecta la sesion de video, y GND
  # aborta con "connection established .. connection lost".
  # ponytail: GND 0.99 tiene SIGABRTs conocidos (gitlab #466, flathub #89);
  # si vuelve a tirar, correr
  #   flatpak run --env=G_MESSAGES_DEBUG=all org.gnome.NetworkDisplays > gnd.log 2>&1
  # y comparar con los issues de upstream.
  networking.firewall.allowedTCPPorts = [ 7236 ];
  networking.firewall.allowedUDPPorts = [ 67 123 7236 ];

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  # Identidad de git por host (NO en modules/apps/git.nix) para no filtrar
  # identidad a quien clone el repo. Default null -> home-manager omite la clave.
  home-manager.users.yovick.modules.apps.git = {
    name = "Yovick RZ";
    email = "66042604+AyrXZ47@users.noreply.github.com";
  };

}
