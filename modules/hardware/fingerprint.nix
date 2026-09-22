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

    # Al volver de S3 (el idle de Caelestia suspende) el xHCI Renesas resetea el
    # bus y el sensor reenumera reportando firmware 0.00: libfprint lo ignora
    # ("unsupported firmware version") o da "USB error ... Entity not found" si
    # fprintd lo abre antes de que el bus asiente (el lock arranca fprintd por
    # D-Bus apenas despierta, antes que este hook). Un rebind del USB fuerza una
    # reenumeracion limpia, pero un solo intento + restart dejaba la carrera
    # abierta y fprintd quedaba corriendo SIN device hasta el proximo restart
    # (visto 2026-09-21: "Ignoring device due to initialization error"). Ahora
    # soltamos fprintd primero y reintentamos rebind+restart hasta que el
    # Manager reporte el sensor, con techo de ~20s. En hosts sin el sensor el
    # loop no encuentra nada y sale enseguida.
    powerManagement.resumeCommands = ''
      # El sensor solo existe en el laptop; en el resto esto es no-op.
      sensor=
      for d in /sys/bus/usb/devices/*/; do
        [ -f "$d/idVendor" ] || continue
        [ "$(cat "$d/idVendor" 2>/dev/null)" = "06cb" ] || continue
        [ "$(cat "$d/idProduct" 2>/dev/null)" = "00bd" ] || continue
        sensor=1
      done
      if [ -n "$sensor" ]; then
        systemctl stop fprintd.service 2>/dev/null || true
        for _ in 1 2 3 4; do
          for d in /sys/bus/usb/devices/*/; do
            [ -f "$d/idVendor" ] || continue
            [ "$(cat "$d/idVendor" 2>/dev/null)" = "06cb" ] || continue
            [ "$(cat "$d/idProduct" 2>/dev/null)" = "00bd" ] || continue
            dev="$(basename "$d")"
            echo "$dev" > /sys/bus/usb/drivers/usb/unbind 2>/dev/null || true
            sleep 1
            echo "$dev" > /sys/bus/usb/drivers/usb/bind 2>/dev/null || true
          done
          sleep 2
          systemctl restart fprintd.service 2>/dev/null || true
          sleep 3
          if timeout 5 busctl --system call net.reactivated.Fprint \
            /net/reactivated/Fprint/Manager net.reactivated.Fprint.Manager \
            GetDevices 2>/dev/null | grep -q 'Fprint/Device'; then
            break
          fi
        done
      fi
    '';
  };
}
