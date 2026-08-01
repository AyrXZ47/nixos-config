{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hardware.mtp;
in
{
  options.modules.hardware.mtp.enable = lib.mkEnableOption "MTP: acceso a Android/tablas en Dolphin";

  config = lib.mkIf cfg.enable {
    # Reglas udev de libmtp: marcan los dispositivos MTP (ID_MTP_DEVICE / ID_MEDIA_PLAYER);
    # sin ellas Solid no los clasifica como reproductor y no aparecen en Dolphin.
    # libmtp tiene outputs bin/out y NixOS referencia el primero (sin reglas); por eso
    # se envuelve para exponer solo lib/udev/rules.d del output `out`.
    services.udev.packages = [ (pkgs.runCommand "libmtp-udev-rules" { } ''
      mkdir -p $out/lib/udev/rules.d
      cp ${pkgs.libmtp.out}/lib/udev/rules.d/*.rules $out/lib/udev/rules.d/
    '') ];

    # El nodo /dev/bus/usb queda root:root 0664 (el usuario no puede escribir) y
    # libmtp necesita abrirlo rw. La regla corre en 99-local.rules (después de
    # 69-libmtp.rules), ve el ID_MTP_DEVICE ya marcado y cubre cualquier MTP,
    # no solo el VID/PID de la tablet.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_MTP_DEVICE}=="1", MODE="0664", GROUP="plugdev"
    '';
    users.groups.plugdev = { };
    users.users.yovick.extraGroups = [ "plugdev" ];
  };
}
