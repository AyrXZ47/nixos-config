{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/openrgb.nix
    ../../modules/hardware/mtp.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/flatpak.nix
    ../../modules/apps/gaming.nix
  ];

  modules.desktop.hyprland = {
    enable = true;
    screenshotKey = "SUPER SHIFT, P";
    screenshotWindowKey = "SUPER ALT, P";
    screenshotScreenKey = "SUPER, P";
  };

  modules.hardware.openrgb.enable = true;
  modules.hardware.mtp.enable = true;

  # openrgb: binario en el PATH para crear/editar los perfiles RGB (la GUI).
  environment.systemPackages = [ pkgs.openrgb ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # ddcci: expone el monitor externo (DDC/CI) como /sys/class/backlight/ddcci0.
  # Asi wayle (modulo brightness nativo: dropdown + OSD) y brightnessctl pueden
  # controlar el brillo, sin depender de ddcutil por cada cambio. Sin esto no hay
  # /sys/class/backlight en este PC (monitor externo) y el brillo solo va por DDC.
  boot.extraModulePackages = [ config.boot.kernelPackages.ddcci-driver ];
  boot.kernelModules = [ "ddcci" "ddcci-backlight" ];

  # ddcci: desde kernel 6.8 el auto-probe de displays esta roto (el driver no
  # instancia el dispositivo por si solo), y sin el, /sys/class/backlight queda
  # vacio -> wayle oculta el icono de brillo. Fix: instanciar manualmente el
  # dispositivo 0x37 (DDC/CI) en el bus i2c del conector conectado.
  systemd.services.ddcci-instantiate = {
    description = "Instancia el dispositivo ddcci del monitor DDC/CI";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for ddc in /sys/class/drm/card*-*-*/ddc; do
        [ -e "$ddc" ] || continue
        conn=$(dirname "$ddc")
        [ "$(cat "$conn/status" 2>/dev/null)" = "connected" ] || continue
        bus=$(basename "$(readlink -f "$ddc")")
        [ -w "/sys/bus/i2c/devices/$bus/new_device" ] || continue
        # Si ya esta instanciado (reload), no hacer nada
        ls /sys/bus/i2c/devices/$bus/0-0037 >/dev/null 2>&1 && continue
        echo ddcci 0x37 > "/sys/bus/i2c/devices/$bus/new_device"
      done
    '';
  };

  time.timeZone = "America/Mexico_City";

  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh.enable = true;

  # syncthing: arranca el daemon + Web UI en 127.0.0.1:8384.
  # Corre como yovick (el user por defecto "syncthing" no tiene permisos
  # sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };

  # kdeconnect: abre puertos 1714-1764 TCP/UDP que el firewall bloqueaba
  programs.kdeconnect.enable = true;

}
