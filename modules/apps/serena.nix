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
  # Serena (MCP server) y opencode.json no se gestionan con home.file: serena
  # escribe su config global (registra proyectos) y opencode puede reescribir
  # su json, asi que un symlink al store los romperia. En su lugar se siembra
  # una copia escribible solo cuando falta, o se repara la clave `projects`.
  home.activation.ensureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.serena"
    if [ ! -f "$HOME/.serena/serena_config.yml" ]; then
      cp ${serenaSeed} "$HOME/.serena/serena_config.yml"
    elif ! ${pkgs.gnugrep}/bin/grep -q '^projects:' "$HOME/.serena/serena_config.yml"; then
      printf '\nprojects: []\n' >> "$HOME/.serena/serena_config.yml"
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
    if [ ! -f "$HOME/.config/opencode/opencode.json" ]; then
      cp ${opencodeSeed} "$HOME/.config/opencode/opencode.json"
    fi
  '';
}
