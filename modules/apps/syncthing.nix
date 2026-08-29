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
}