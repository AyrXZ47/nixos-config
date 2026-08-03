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

    # Huella como factor de autenticación en: login (tty) y sudo (auth con
    # permiso). El desbloqueo gráfico NO va por PAM: hyprlock integra fprintd de
    # forma nativa (auth fingerprint:enabled). SDDM no se toca: sin UI de huella,
    # el pam_fprintd bloqueaba el login esperando el dedo.
    security.pam.services.login.fprintAuth = true;
    security.pam.services.sudo.fprintAuth = true;
  };
}
