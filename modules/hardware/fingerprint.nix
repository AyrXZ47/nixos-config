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
    # gráfico del lock de Caelestia NO va por /etc/pam.d: usa sus propias
    # unidades PAM dentro del paquete (assets/pam.d/fprint → pam_fprintd.so),
    # así que no depende de las opciones de abajo.
    #
    # OJO con el default: `security.pam.services.<name>.fprintAuth` defaulta a
    # `services.fprintd.enable` (true), así que TODOS los servicios PAM heredan
    # pam_fprintd. Hay que apagarla explícitamente donde estorba:
    #  - login: SDDM hace `auth substack login` (sddm.nix) y sin UI de huella el
    #    pam_fprintd bloqueaba el login esperando el dedo (~30s, "10 enters y
    #    nada").
    #  - sddm: explícito por claridad (efectivo vía el substack de login).
    security.pam.services.sudo.fprintAuth = true;
    security.pam.services.login.fprintAuth = false;
    security.pam.services.sddm.fprintAuth = false;

    # El Synaptics no despierta limpio del autosuspend USB: queda suspendido
    # (`power/control = auto`) y cada ~15 min xhci lo resetea por timeout
    # ("usb 3-3: reset full-speed USB device"), dejando la huella colgada
    # esperando dedo. Sin autosuspend el sensor queda estable; el costo en
    # bateria de UN device full-speed es despreciable.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="06cb", ATTR{idProduct}=="00bd", ATTR{power/control}="on"
    '';

    # Al volver de S3 (el idle de Caelestia ahora suspende) el controlador xHCI
    # Renesas resetea el bus y el sensor reenumera reportando firmware 0.00:
    # libfprint lo ignora ("unsupported firmware version") y fprintd deja la
    # reserva colgada -> sudo deja de pedir la huella (visto 2026-09-19). Un
    # rebind del USB fuerza una reenumeracion limpia y reiniciar fprintd limpia
    # la reserva. En hosts sin este sensor el loop no encuentra nada.
    powerManagement.resumeCommands = ''
      for d in /sys/bus/usb/devices/*/; do
        [ -f "$d/idVendor" ] || continue
        [ "$(cat "$d/idVendor")" = "06cb" ] || continue
        [ "$(cat "$d/idProduct")" = "00bd" ] || continue
        dev="$(basename "$d")"
        echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true
        sleep 1
        echo "$dev" > /sys/bus/usb/drivers/usb/bind 2>/dev/null || true
      done
      systemctl restart fprintd.service 2>/dev/null || true
    '';
  };
}
