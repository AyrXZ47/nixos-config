{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hardware.sdr;
in
{
  options.modules.hardware.sdr.enable = lib.mkEnableOption "SDR: dongle RTL-SDR por USB (recibir señales)";

  config = lib.mkIf cfg.enable {
    # hardware.rtl-sdr: reglas udev + grupo plugdev + blacklist de los módulos DVB
    # (dvb_usb_rtl28xxu reclama el dongle — se ve en dmesg y en /dev/dvb — y
    # librtlsdr ya no lo encuentra) + CLI rtl_test/rtl_fm/rtl_power/rtl_sdr.
    # La parte Python (pyrtlsdr) vive en modules/apps/python.nix.
    hardware.rtl-sdr.enable = true;

    # Las reglas udev del paquete dejan el dongle GROUP=plugdev, MODE=0660
    # (0bda:2838/2832): sin este grupo, abrir la radio necesita root.
    users.users.yovick.extraGroups = [ "plugdev" ];
  };
}
