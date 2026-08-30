{ config, pkgs, lib, ... }:

{
  # Tailscale: malla WireGuard privada (~gratis, NAT traversal automatico).
  # Resuelve el bloqueo de la red de la universidad: el FortiGate no puede
  # inspeccionar el tunel e2e, asi que syncthing, ssh, y lo que sea, pasan
  # como si estuvieran en la misma LAN. Arranca tailscaled; autorizar cada
  # maquina una vez con `sudo tailscale up`.
  #
  # TRAMPA UAZ (2026-08): el FortiGate veto SOLO controlplane.tailscale.com
  # (cert Fortinet / RST); login y derp*.tailscale.com siguen con cert real.
  # Efecto: `tailscale up` se cuelga en la uni (necesita la control key de ese
  # dominio), pero un cliente YA logueado sigue sincronizando ahi via DERP
  # (los moviles lo prueban). Reglas: loguear solo desde red limpia (casa /
  # hotspot) y NUNCA correr `tailscale logout` a la ligera — borra el perfil
  # local y solo se recupera desde red limpia.
  services.tailscale.enable = true;

  # El trafico que entra por tailscale0 solo puede venir de dispositivos ya
  # autenticados en tu tailnet (WireGuard valida cada peer). Confiar en la
  # interfaz deja pasar a los peers (syncthing 22000, ssh, etc.) sin abrir
  # puertos en el firewall global.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}