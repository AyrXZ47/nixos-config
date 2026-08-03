{ config, pkgs, lib, ... }:

let
  cfg = config.modules.hardware.fingerprint;
in
{
  options.modules.hardware.fingerprint.enable = lib.mkEnableOption "sensor de huella dactilar (fprintd + PAM)";

  config = lib.mkIf cfg.enable {
    # fprintd: daemon D-Bus + libfprint. El sensor del laptop (Synaptics 06cb:00bd)
    # lo cubre libfprint base; solo algunos Goodix/Validity necesitan driver TOD.
    services.fprintd.enable = true;

    # Huella como factor de autenticación en: login (tty), SDDM (sesión gráfica),
    # sudo (auth con permiso) y swaylock (desbloqueo).
    security.pam.services.login.fprintAuth = true;
    security.pam.services.sddm.fprintAuth = true;
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.swaylock.fprintAuth = true;
  };
}
