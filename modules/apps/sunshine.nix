{ pkgs, lib, ... }:

{
  # Sunshine: host de streaming para Moonlight (el cliente vive en la Google TV
  # / Android TV / iOS / lo que sea). Es la alternativa real a Miracast cuando
  # el receptor es un Chromecast/Google TV, que rechaza el LOAD de
  # gnome-network-displays (ver odd/tasks/miracast-pantallas-tema.md).
  # Captura por screen-copy de Wayland y encodea en la GPU (VAAPI en amdgpu),
  # asi que el costo en CPU es bajo.
  # El servicio NO va aca: se lanza como unidad de USUARIO en la sesion grafica
  # (modules/desktop/hyprland-home.nix), porque un servicio de sistema no tiene
  # acceso a la sesion Wayland y la captura falla.
  environment.systemPackages = [ pkgs.sunshine ];

  # Puertos de Sunshine (los oficiales del proyecto). Sin esto el host se ve en
  # Moonlight pero la sesion no arranca.
  networking.firewall.allowedTCPPorts = [ 47984 47989 47990 48010 ];
  networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
}
