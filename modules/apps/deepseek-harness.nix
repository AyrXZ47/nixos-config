{ pkgs, ... }:

# DeepSeek Harness (dsh), el harness de agentes de DeepSeek. nixpkgs ya lo
# empaqueta (pkgs/by-name/de/deepseek-harness) y el pin actual tiene binario en
# cache.nixos.org: no hace falta overlay, buildNpmPackage ni `npx` en runtime.
# home/default.nix lo importa, asi que llega a los 4 hosts.
#
# Arranca en limpio a proposito: sin skills, MCPs ni plugins externos, solo los
# plugins internos que trae el perfil `web`. La config vive en ~/.dsh (fuera
# del repo) y se administra desde la UI; no se siembra nada desde Nix.
{
  home.packages = [ pkgs.deepseek-harness ];
}
