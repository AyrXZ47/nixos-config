{ config, pkgs, lib, ... }:

{
  # syncthing por defecto en todos los hosts: arranca el daemon + Web UI en
  # 127.0.0.1:8384. Corre como yovick (el user por defecto "syncthing" no tiene
  # permisos sobre /home/yovick) con config en /home/yovick/.config/syncthing.
  services.syncthing = {
    enable = true;
    user = "yovick";
    dataDir = "/home/yovick";
  };

  # LAN directa: sin estos puertos, syncthing solo conecta via tailscale0
  # (trusted en tailscale.nix) o via relays. En redes ajenas (UAZ: el FortiGate
  # hace MITM de TLS y mata relays + global discovery + el propio tailscale)
  # el host quedaba incomunicado aunque hubiera pares en la misma LAN.
  # 22000 tcp/udp = sync directo, 21027/udp = local discovery (broadcast LAN).
  networking.firewall.allowedTCPPorts = [ 22000 ];
  networking.firewall.allowedUDPPorts = [ 22000 21027 ];

  # OJO (2026-09): discovery solo no alcanza. Diagnostico: al cambiar de red
  # fallaba porque los PEERS no estaban alcanzables — tailscale offline en
  # telefono/tablet/PC (Android lo mata por optimizacion de bateria) y todos
  # los peers con address 'dynamic' (dependencia total de discovery). Fix:
  # IP de tailnet fija como primera address de cada peer via API REST
  # (persiste en ~/.config/syncthing/config.xml, no declarativo):
  #   IASQHNB s25-fe  tcp://100.104.197.93:22000
  #   YQGR3CM pc      tcp://100.104.25.127:22000
  #   6TM2XVT tab     tcp://100.120.221.90:22000
  # (este host = 100.83.13.15; fijarla tambien en la GUI de los otros 3).
  # Mitad que no se puede arreglar desde NixOS: eximir Tailscale de la
  # optimizacion de bateria en Android, o esas IPs apuntan a nada.

}