{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/user.nix
    ../../modules/core/networking.nix
    ../../modules/desktop/hyprland.nix
    ../../modules/theming/theme-base.nix
    ../../modules/theming/plymouth.nix
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/openrgb.nix
    ../../modules/hardware/mtp.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/flatpak.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/rust-dev.nix
  ];

  modules.desktop.hyprland = {
    enable = true;
  };

  modules.hardware.openrgb.enable = true;
  modules.hardware.mtp.enable = true;
  modules.hardware.fingerprint.enable = true;

  # openrgb: binario en el PATH para crear/editar los perfiles RGB (la GUI).
  environment.systemPackages = [ pkgs.openrgb ];

  # fwupd: servicio para actualizar firmware (BIOS/SSD). Uso: `fwupdmgr refresh && fwupdmgr update`.
  services.fwupd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";

  # MTU 1400 en el enlace ethernet: el camino hacia internet del PC no soporta
  # MTU 1500 (probado: ping -M do -s 1472 falla 100%, -s 1400 OK). Con 1500,
  # las descargas grandes (cache.nixos.org, >GBs) se cortan a mitad con
  # "Failure when receiving data from the peer" / SSL_ERROR_SYSCALL mientras
  # que ping y descargas pequeñas funcionan — paquetes grandes descartados en
  # silencio (ISP con PPPoE/túnel). 1400 es margen seguro sobre el máximo
  # estable medido (1460); no ir a 1500.
  networking.interfaces.enp5s0.mtu = 1400;

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
  # Ojo: en DP el DDC/CI viaja por el bus i2c AUXILIAR (drm_dp_auxN, nombre
  # "AMDGPU DM aux hw bus"), NO por el symlink ddc (que apunta a un i2c del
  # conector que no responde a 0x37 -> probe -19, backlight vacio). Se prueba el
  # aux primero y se cae al symlink ddc solo para conectores sin aux (HDMI/DVI).
  # El probe del core falla -19 si corre antes de que el display manager ponga
  # el monitor en marcha (en el boot el MSI G2412 todavia no responde a DDC/CI,
  # aunque luego si, verificado con ddcutil). Por eso el servicio se dispara con
  # graphical.target (despues de display-manager) y reintenta borrando el device
  # stale hasta que ddcci lo enlaza (driver presente).
  systemd.services.ddcci-instantiate = {
    description = "Instancia el dispositivo ddcci del monitor DDC/CI";
    wantedBy = [ "graphical.target" ];
    after = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for conn in /sys/class/drm/card*-*-*; do
        [ -d "$conn" ] || continue
        [ "$(cat "$conn/status" 2>/dev/null)" = "connected" ] || continue
        bus=""
        for i2c in "$conn"/i2c-*; do
          [ -r "$i2c/name" ] && grep -qi aux "$i2c/name" && bus=$(basename "$i2c") && break
        done
        [ -z "$bus" ] && [ -e "$conn/ddc" ] && bus=$(basename "$(readlink -f "$conn/ddc")")
        [ -z "$bus" ] && continue
        [ -w "/sys/bus/i2c/devices/$bus/new_device" ] || continue
        # dir del device: "<n>-0037" (bus i2c-n), no "$bus/0-0037".
        n="''${bus#i2c-}"
        dev="/sys/bus/i2c/devices/$n-0037"
        for i in $(seq 1 15); do
          [ -L "$dev/driver" ] && break
          # Ojo: el guard y los writes usan la MISMA ruta absoluta. Antes los
          # writes iban a "$bus/new_device" (relativo al cwd del servicio, /),
          # fallaban con ENOENT y ddcci nunca se instanciaba.
          [ -e "$dev" ] && echo 0x37 > "/sys/bus/i2c/devices/$bus/delete_device" 2>/dev/null || true
          echo ddcci 0x37 > "/sys/bus/i2c/devices/$bus/new_device" 2>/dev/null || true
          sleep 2
        done
      done
    '';
  };

  # NightCity (2TB, ext4): disco de datos interno, montado siempre en el boot.
  # nofail: si algun dia falta el disco el boot no se cuelga. Con fstab Dolphin
  # lo lista en Devices sin necesidad de click (udisks2 ya no lo toca).
  fileSystems."/mnt/nightcity" = {
    device = "/dev/disk/by-uuid/14c6cc67-3079-4434-b078-e29a7177dcf6";
    fsType = "ext4";
    options = [ "nofail" ];
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
