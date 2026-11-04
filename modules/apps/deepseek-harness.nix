{ pkgs, ... }:

# DeepSeek Harness (dsh), TUI-only. nixpkgs ya lo empaqueta
# (pkgs/by-name/de/deepseek-harness) y el pin actual tiene binario en
# cache.nixos.org: no hace falta overlay, buildNpmPackage ni `npx` en runtime.
# home/default.nix lo importa, asi que llega a los 4 hosts.
#
# Sin wrapper de navegador, Electron ni Brave: el unico front end que se
# instala es `dsh-tui`, que corre sobre el perfil `tui`
# (dsh-base + dsh-tui). El perfil se instala una vez por host:
#   dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui
# La config vive en ~/.dsh y no se siembra desde Nix.
let
  dshTui = pkgs.writeShellScriptBin "dsh-tui" ''
    exec ${pkgs.deepseek-harness}/bin/dsh --profile tui "$@"
  '';
in
{
  home.packages = [ pkgs.deepseek-harness dshTui ];
}
