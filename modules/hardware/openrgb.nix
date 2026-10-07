{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hardware.openrgb;
  openrgb = "${pkgs.openrgb}/bin/openrgb";
  profileBoot = "RGBRules1"; # perfil de sesión activa (al arranque)
  profileOff = "RGBRules2"; # perfil al bloquear / suspender / apagar
in
{
  options.modules.hardware.openrgb.enable = lib.mkEnableOption "OpenRGB: control RGB con perfiles por evento";

  config = lib.mkIf cfg.enable {
    # 60-openrgb.rules (las trae el paquete): permisos para tocar los dispositivos RGB.
    services.udev.packages = [ pkgs.openrgb ];

    # SMBus de las RAM (AMD FCH, driver i2c-piix4): ACPI reclama el rango 0xB00
    # (OpRegion \GSA1.SMBI) y sp5100_tco (watchdog) también se lo queda; `lax` +
    # blacklist dejan el bus libre para que OpenRGB vea las RAM.
    boot.kernelParams = [ "acpi_enforce_resources=lax" ];
    boot.blacklistedKernelModules = [ "sp5100_tco" ];

    home-manager.users.yovick = {
      # Un servidor headless detecta el hardware UNA vez al iniciar sesión y aplica
      # el perfil de arranque. Los eventos (lock/unlock) solo conectan como
      # cliente (--nodetect): sin re-escanear el SMBus no hay riesgo de colgar el
      # equipo (antes cada apertura re-escaneaba todos los buses y podía colgarse).
      # La única excepción es el resume (ver resumeCommands): el reset USB del
      # despertar deja el handle muerto y toca reiniciar el servidor.
      systemd.user.services.openrgb = {
        Unit = {
          Description = "OpenRGB: servidor RGB + perfil de arranque";
        };
        Service = {
          Type = "simple";
          ExecStart = "${openrgb} --server -p ${profileBoot}";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };

      # Los hooks de lock/unlock (openrgb-lock-before/after) viven en
      # hyprland-home.nix, en scope de Home Manager: aqui `home.file` quedaba
      # anidado junto a opciones NixOS del usuario HM y HM lo descartaba en
      # silencio.
      #
      # No hay hook de suspensión en scope de usuario: `sleep.target` no existe
      # en el gestor de usuario (systemd 261), así que un `WantedBy=sleep.target`
      # aquí nunca corría. El resume se maneja con `resumeCommands` (abajo).
    };

    # Al volver de S3 el xHCI resetea el bus USB y el controlador HID de los
    # ventiladores (CoolerMaster) reenumera: pierde el efecto aplicado (queda en
    # el arcoíris de fábrica) y el servidor OpenRGB conserva un handle muerto,
    # así que el hook de unlock tampoco puede repintarlo. Reiniciar el servidor
    # fuerza una re-detección. En este equipo el único suspend lo dispara el
    # watchdog del lock, siempre con la sesión bloqueada, así que re-aplicamos el
    # perfil de bloqueo; el unlock ya restaura el de arranque.
    powerManagement.resumeCommands = ''
      if [ -S /run/user/1000/systemd/private ]; then
        runuser -u yovick -- env XDG_RUNTIME_DIR=/run/user/1000 \
          systemctl --user restart openrgb.service || true
        for _ in $(seq 20); do
          sleep 1
          ${openrgb} --client --nodetect -p ${profileOff} 2>/dev/null && break
        done
      fi
    '';

    # Al apagar: perfil "apagado". La sesión (y su servidor) ya se está cerrando, así
    # que toca detectar de nuevo (un escaneo más, ~14s). ExecStop corre en shutdown.
    # ponytail: si el GUI siguiera vivo, dos instancias escanean el SMBus a la vez;
    # a la fecha la sesión muere antes y no hay solapamiento.
    systemd.services.openrgb-shutdown = {
      description = "OpenRGB: perfil al apagar el equipo";
      wantedBy = [ "multi-user.target" ];
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "yovick";
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${openrgb} -p ${profileOff}";
        TimeoutStopSec = 60;
      };
    };
  };
}
