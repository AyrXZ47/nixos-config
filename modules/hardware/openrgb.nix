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
      # el perfil de arranque. Los eventos (lock/sleep/unlock) solo conectan como
      # cliente (--nodetect): sin re-escanear el SMBus no hay riesgo de colgar el
      # equipo (antes cada apertura re-escaneaba todos los buses y podía colgarse).
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

      # Al suspender/hibernar: perfil "apagado".
      systemd.user.services."openrgb-sleep" = {
        Unit = {
          Description = "OpenRGB: perfil de suspensión";
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${openrgb} --client --nodetect -p ${profileOff}";
        };
        Install = {
          WantedBy = [ "sleep.target" ];
        };
      };

      # Hooks que consume hypr/scripts/lock.sh (ver hyprland-home.nix): perfil
      # "apagado" al bloquear, normal al desbloquear.
      home.file."hypr/scripts/openrgb-lock-before" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${openrgb} --client --nodetect -p ${profileOff}
        '';
      };
      home.file."hypr/scripts/openrgb-lock-after" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${openrgb} --client --nodetect -p ${profileBoot}
        '';
      };
    };

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
