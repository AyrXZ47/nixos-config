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

    # Huella como factor de autenticación en sudo (terminal). El desbloqueo
    # gráfico NO va por PAM: hyprlock integra fprintd de forma nativa
    # (auth fingerprint:enabled).
    #
    # OJO con el default: `security.pam.services.<name>.fprintAuth` defaulta a
    # `services.fprintd.enable` (true), así que TODOS los servicios PAM heredan
    # pam_fprintd. Hay que apagarla explícitamente donde estorba:
    #  - login: SDDM hace `auth substack login` (sddm.nix) y sin UI de huella el
    #    pam_fprintd bloqueaba el login esperando el dedo (~30s, "10 enters y
    #    nada").
    #  - sddm: explícito por claridad (efectivo vía el substack de login).
    #  - hyprlock: la desactiva hyprland.nix (usa fprintd nativo).
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.login.fprintAuth = false;
    security.pam.services.sddm.fprintAuth = false;
  };
}
