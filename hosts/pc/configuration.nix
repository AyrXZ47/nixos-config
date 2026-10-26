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
    ../../modules/hardware/amd-desktop.nix
    ../../modules/hardware/fingerprint.nix
    ../../modules/hardware/openrgb.nix
    ../../modules/hardware/mtp.nix
    ../../modules/hardware/sdr.nix
    ../../modules/apps/common-packages.nix
    ../../modules/apps/gaming.nix
    ../../modules/apps/rust-dev.nix
    ../../modules/apps/packettracer.nix
    ../../modules/apps/vivado.nix
    ../../modules/apps/syncthing.nix
    ../../modules/apps/docker.nix
  ];

  # Packet Tracer (universidad): con el .deb en el store el rebuild construye;
  # si algún día falta, se puede apagar con false y el host vuelve a construir.
  modules.apps.packetTracer.enable = true;

  # Vivado (FPGA/Arquitectura de computadoras): wrapper FHS en el PATH; la
  # instalación vive en ~/opt/Xilinx (hecha a mano con xsetup, cuenta AMD).
  modules.apps.vivado.enable = true;

  modules.desktop.hyprland = {
    enable = true;
  };
  modules.desktop.caelestia.enable = true;

  # KVM/QEMU + libvirt para virt-manager (el paquete ya viene de
  # common-packages.nix; esto habilita el daemon que el cliente necesita).
  modules.desktop.virtualisation.enable = true;

  modules.hardware.openrgb.enable = true;
  modules.hardware.mtp.enable = true;
  modules.hardware.fingerprint.enable = true;
  modules.hardware.sdr.enable = true;

  # openrgb: el binario ya lo trae modules/hardware/openrgb.nix.

  # fwupd: servicio para actualizar firmware (BIOS/SSD). Uso: `fwupdmgr refresh && fwupdmgr update`.
  # El `wantedBy = mkForce []` (no arrancar en boot) vive en nix-optimization.nix.
  services.fwupd.enable = true;

  # Loader, openssh, zona, locale e identidad de git: modules/core/common-host.nix.
  system.stateVersion = "26.05";

  networking.hostName = "nixos-pc";

  # MTU 1500 en ethernet: el "corte a mitad" (SSL_ERROR_SYSCALL, probado con
  # 1500 en su día) NO era la interfaz sino el camino PPPoE del ISP, limitado a
  # 1492 (el gateway responde "Frag needed (mtu = 1492)"). El RTL8168 no
  # absorbe el PMTUD, así que el fix real es el MSS clamping a 1452 que vive en
  # modules/core/networking.nix: los SYNs anuncian 1452, los datos del servidor
  # llegan de 1492 exactos y caben — sin PMTUD de por medio. 1500 queda para la
  # LAN local, que sí lo soporta. No volver a 1400: era un parche sintomático
  # que pagaba ~7% de overhead por paquete.
  networking.interfaces.enp5s0.mtu = 1500;

  # NM no refleja networking.interfaces.*.mtu en su profile regenerado (el
  # switch lo perde al reiniciar NM y la interfaz se queda con el MTU viejo).
  # Oneshot determinista post-NM: fuerza el 1500 del camino LAN (el limite
  # real del ISP es 1492 por PPPoE y lo cubre el MSS clamping del firewall).
  systemd.services.enp5s0-mtu = {
    description = "Fija el MTU de enp5s0 a 1500 (post-NetworkManager)";
    wantedBy = [ "network-online.target" ];
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.iproute2}/bin/ip link set enp5s0 mtu 1500
    '';
  };

  # ddcci: expone el monitor externo (DDC/CI) como /sys/class/backlight/ddcci0.
  # Asi Caelestia (OSD de brillo: osd.enableBrightness + scroll en la barra) y
  # brightnessctl pueden controlar el brillo, sin depender de ddcutil por cada
  # cambio. Sin esto no hay /sys/class/backlight en este PC (monitor externo) y
  # el brillo solo va por DDC.
  # ddcci: el paquete instala con `install` propio en vez de kbuild
  # `modules_install`, y ahi es donde nixpkgs corre cmd_sign=kmodigest. Sin
  # firma no queda el .ko.cer que el merge de lib/modules espera (desde 7.2.11
  # concatena un certificado por modulo) y el build muere con
  # "cat: extra/ddcci.ko.cer: No such file". kmodigest firma el .ko y deja el
  # .cer al lado; solo se recompila este modulo (segundos, no el kernel).
  # dontStrip: el strip de fixupPhase reescribe el .ko y tira la firma que
  # acaba de anexar kmodigest, dejando firma invalida (el kernel rechaza el
  # modulo). Con el .ko sin tocar, firma y certificado coinciden.
  # ponytail: techo conocido — borrar el override cuando nixpkgs empaquete
  # ddcci via modules_install (ya firmado) o suba un fix upstream.
  boot.extraModulePackages = [
    (config.boot.kernelPackages.ddcci-driver.overrideAttrs (old: {
      dontStrip = true;
      postInstall = (old.postInstall or "") + ''
        for ko in $out/lib/modules/*/extra/*.ko; do
          ${pkgs.binutils}/bin/strip -S -p "$ko"
          ${pkgs.kmodigest}/bin/kmodigest "$ko"
        done
      '';
    }))
  ];
  boot.kernelModules = [ "ddcci" "ddcci-backlight" ];

  # ddcci: desde kernel 6.8 el auto-probe de displays esta roto (el driver no
  # instancia el dispositivo por si solo), y sin el, /sys/class/backlight queda
  # vacio -> Caelestia no puede leer el brillo (icono/OSD vacios). Fix:
  # instanciar manualmente el
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

  # kdeconnect: abre puertos 1714-1764 TCP/UDP que el firewall bloqueaba
  programs.kdeconnect.enable = true;

  # Identidad de git: modules/core/common-host.nix (misma en los 4 hosts).

}
