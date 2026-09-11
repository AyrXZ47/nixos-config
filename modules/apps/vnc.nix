{ pkgs, lib, ... }:

{
  # Cast de laptop -> tablet sin HDMI ni Miracast: wayvnc escucha SOLO en la
  # IP de tailscale0 (el firewall ya la declara trusted, sin abrir puertos);
  # la tablet entra con cualquier cliente VNC (AVNC en Android) via Tailscale.
  # Ejecutar/soltar con SUPER+ALT+D. No pide contraseña: la autenticacion la
  # hace WireGuard (solo peers del tailnet llegan).
  # Dos modos:
  #   cast-tablet mirror  (default) = espejo: replica la pantalla activa.
  #   cast-tablet extend               = modo extendido: la tablet ve la
  #     salida headless HEADLESS-TABLET (otro escritorio con sus workspaces),
  #     que es lo que pide "use this tablet as an additional display", sin
  #     depender de Miracast/Second screen. Esta salida se elimina al soltar
  #     (hyprctl output remove); el config de monitores del archivo no se
  #     toca: hyprctl keyword/output solo afecta la sesion actual.
  # Ceiling: si hypridle apaga/blanquea la pantalla la sesion cast se congela
  # hasta que vuelva el input; para presentaciones largas, mantener la
  # pantalla despierta (wayle idle toggle) durante el cast.
  home.packages = with pkgs; [
    wayvnc
    (pkgs.writeShellScriptBin "cast-tablet" ''
      export PATH=${lib.makeBinPath [ pkgs.wayvnc pkgs.tailscale pkgs.hyprland pkgs.coreutils pkgs.util-linux ]}:$PATH
      mode="''${1:-mirror}"
      headless="HEADLESS-TABLET"

      if pgrep -x wayvnc >/dev/null 2>&1; then
        pkill -x wayvnc
        # Limpieza del modo anterior si era extend (no-op en mirror)
        hyprctl output remove "$headless" >/dev/null 2>&1 || true
        notify-send "Cast: desconectado"
        exit 0
      fi

      ip=$(tailscale ip -4)
      out_args=()
      if [ "$mode" = "extend" ]; then
        # ponytail: resolucion fija 1920x1200 (16:10, tipico de tab S);
        # si la tablet es 16:9 la letra se ve con letterbox: ajustable.
        hyprctl output create headless "$headless" >/dev/null
        hyprctl keyword monitor "$headless,1920x1200,auto,1" >/dev/null
        out_args=(--output "$headless")
      fi
      # wayvnc 0.10 no tiene modo daemon: nohup + & y listo. Si falla al
      # arrancar, limpiamos la salida headless y salimos con error.
      nohup wayvnc "''${out_args[@]}" "$ip" 5900 >/tmp/wayvnc-cast.log 2>&1 &
      sleep 0.3
      if pgrep -x wayvnc >/dev/null 2>&1; then
        notify-send "Cast ($mode): $ip:5900 (tailscale)"
      else
        hyprctl output remove "$headless" >/dev/null 2>&1 || true
        notify-send "Cast: wayvnc no arrancó" "ver /tmp/wayvnc-cast.log"
        exit 1
      fi
    '')
  ];
}
