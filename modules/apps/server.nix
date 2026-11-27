# Perfil de servidor (sin GUI): common-cli ya aporta Syncthing, diagnóstico y
# ffmpeg-full; acá va lo específico del server, que es el runtime de
# contenedores rootless. No importar desktop/engineering/media/dev.
{ ... }:
{
  imports = [ ./podman.nix ];
}
