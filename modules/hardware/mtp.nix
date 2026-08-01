{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hardware.mtp;
in
{
  options.modules.hardware.mtp.enable = lib.mkEnableOption "MTP: acceso a Android/tablas en Dolphin";

  config = lib.mkIf cfg.enable {
    # Reglas udev de libmtp: marcan los dispositivos MTP (ID_MTP_DEVICE / ID_MEDIA_PLAYER);
    # sin ellas Solid no los clasifica como reproductor y no aparecen en Dolphin.
    services.udev.packages = [ pkgs.libmtp ];

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
