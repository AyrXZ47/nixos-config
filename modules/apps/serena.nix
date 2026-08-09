{ config, pkgs, lib, ... }:

let
  # Config conocida-buena de opencode (MCP de serena; el provider opencode-go es
  # nativo y su key vive en ~/.local/share/opencode/auth.json). Se copia a un
  # archivo normal (no symlink) para que serena/opencode puedan escribirlo.
  opencodeSeed = pkgs.writeText "opencode.json" ''
    {
      "$schema": "https://opencode.ai/config.json",
      "mcp": {
        "serena": {
          "type": "local",
          "command": [
            "uvx",
            "--no-python-downloads",
            "--python",
            "${pkgs.python313}/bin/python3.13",
            "--from",
            "git+https://github.com/oraios/serena",
            "serena",
            "start-mcp-server",
            "--project-from-cwd",
            "--context",
            "agent",
            "--open-web-dashboard",
            "False"
          ],
          "enabled": true
        }
      }
    }
  '';

  # Semilla minima de serena: serena la expande/reescribe al primer arranque
  # (migra a la plantilla completa y registra los proyectos). Solo importa que
  # exista la clave `projects`, sin ella el MCP muere con "Connection closed".
  serenaSeed = pkgs.writeText "serena_config.yml" ''
    web_dashboard_open_on_launch: false
    projects: []
  '';
in
{
  # uvx es el lanzador del MCP de serena (comando abajo); headroom lo instalaba
  # antes, ahora es dependencia directa del propio modulo de serena.
  home.packages = [ pkgs.uv ];

  # Serena (MCP server) y opencode.json no se gestionan con home.file: serena
  # escribe su config global (registra proyectos) y opencode puede reescribir
  # su json, asi que un symlink al store los romperia. En su lugar se siembra
  # una copia escribible solo cuando falta, o se repara la clave `projects`.
  # opencode.json se re-siembra si aun conserva headroom (semilla vieja) o la
  # invocacion vieja de uvx sin el python de nix (uv descargaba su propio
  # python 3.14 que no corre en NixOS y el MCP moria con "Connection closed").
  home.activation.ensureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.serena"
    if [ ! -f "$HOME/.serena/serena_config.yml" ]; then
      cp ${serenaSeed} "$HOME/.serena/serena_config.yml"
    elif ! ${pkgs.gnugrep}/bin/grep -q '^projects:' "$HOME/.serena/serena_config.yml"; then
      printf '\nprojects: []\n' >> "$HOME/.serena/serena_config.yml"
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
    if [ ! -f "$HOME/.config/opencode/opencode.json" ] || \
       ${pkgs.gnugrep}/bin/grep -q 'headroom' "$HOME/.config/opencode/opencode.json" || \
       ! ${pkgs.gnugrep}/bin/grep -q 'no-python-downloads' "$HOME/.config/opencode/opencode.json"; then
      cp ${opencodeSeed} "$HOME/.config/opencode/opencode.json"
    fi

    # Limpieza de la integracion vieja: headroom ya no esta en el config, se
    # eliminan el binario de uv tool install y su backup si quedaron de antes.
    ${pkgs.coreutils}/bin/rm -f "$HOME/.local/bin/headroom"
    ${pkgs.coreutils}/bin/rm -rf "$HOME/.local/share/uv/tools/headroom-ai"
    ${pkgs.coreutils}/bin/rm -f "$HOME/.config/opencode/opencode.json.headroom-backup"
    # Pythons que uv se descargo (3.14) y que no corren en NixOS; ya no se usan
    # porque el MCP fija el python de nix con --no-python-downloads.
    ${pkgs.coreutils}/bin/rm -rf "$HOME/.local/share/uv/python"
  '';
}
