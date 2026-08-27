{ config, pkgs, lib, ... }:

{
  # Tailscale: malla WireGuard privada (~gratis, NAT traversal automatico).
  # Resuelve el bloqueo de la red de la universidad: el FortiGate no puede
  # inspeccionar el tunel e2e, asi que syncthing, ssh, y lo que sea, pasan
  # como si estuvieran en la misma LAN. Arranca tailscaled; autorizar cada
  # maquina una vez con `sudo tailscale up`.
  services.tailscale.enable = true;

  # El trafico que entra por tailscale0 solo puede venir de dispositivos ya
  # autenticados en tu tailnet (WireGuard valida cada peer). Confiar en la
  # interfaz deja pasar a los peers (syncthing 22000, ssh, etc.) sin abrir
  # puertos en el firewall global.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}