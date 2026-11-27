{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/btrfs.nix
    ../../modules/core/networking.nix
    ../../modules/core/tailscale.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/desktop/caelestia.nix
    ../../modules/desktop/virtualisation.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/hardware/nvme-dramless.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/mtp.nix
    ../../modules/hardware/sdr.nix
    ../../modules/apps/common-cli.nix
    ../../modules/apps/desktop.nix
    ../../modules/apps/engineering.nix
    ../../modules/apps/media.nix
    ../../modules/apps/dev.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/docker.nix
  ];

  modules.desktop.hyprland.enable = true;
  modules.desktop.caelestia.enable = true;

  # KVM/QEMU + libvirt para virt-manager (el paquete ya viene de
  # modules/apps/desktop.nix; esto habilita el daemon que el cliente necesita).
  modules.desktop.virtualisation.enable = true;

  modules.hardware.fingerprint.enable = true;

  # MTP: acceso a Android/tabletas en Dolphin (mismo módulo que la pc).
  modules.hardware.mtp.enable = true;

  # Dongle RTL-SDR (Realtek RTL2838 DVB-T): blacklist de los módulos DVB,
  # grupo plugdev y CLI rtl_*; pyrtlsdr va en el python global.
  modules.hardware.sdr.enable = true;

  environment.systemPackages = [
    # openrgb: por si esta laptop llega a tener luces que controlar (perfiles a mano).
    pkgs.openrgb
    # Cliente de la pc sin monitor: Sunshine corre alla (hosts/pc) y esta
    # laptop decodifica por VAAPI. Solo el cliente; el host no va en la laptop.
    pkgs.moonlight-qt
  ];

  # fwupd: servicio para actualizar firmware. El `wantedBy = mkForce []` (no
  # arrancar en boot) vive en nix-optimization.nix.
  services.fwupd.enable = true;

  # Loader, openssh, zona, locale e identidad de git: modules/core/common-host.nix.
  system.stateVersion = "26.05";

  networking.hostName = "nixos-laptop";

  # kdeconnect: los puertos 1714-1764 viven en modules/core/networking.nix
  # (compartido por los 4 hosts).

  # Miracast (gnome-network-displays -> Smart View de TVs Samsung): el paquete
  # y el dnsmasq del DHCP-P2P viven en modules/apps/desktop.nix (home,
  # pc/laptop/vm) y los puertos 67/123/7236 en modules/core/networking.nix. No
  # se duplican aca: tenerlos solo en este host era justamente el bug que
  # dejaba al pc con GND roto.
  # ponytail: GND 0.99 tiene SIGABRTs conocidos (gitlab #466, flathub #89);
  # si vuelve a tirar, correr con debug y comparar con los issues de upstream:
  #   G_MESSAGES_DEBUG=all gnome-network-displays > gnd.log 2>&1

  # Identidad de git: modules/core/common-host.nix (misma en los 4 hosts).

}
