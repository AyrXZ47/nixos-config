{ config, pkgs, lib, ... }:

{
  # Podman rootless: sin daemon root, sin grupo `docker` (root-equivalente).
  # `dockerCompat` deja el alias `docker -> podman` para las herramientas que
  # esperan el CLI de Docker. No se habilita `dockerSocket` (sería rootful).
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
}
