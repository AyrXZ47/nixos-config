{ config, pkgs, lib, ... }:

let
  # MCP de serena para pi: se registra en ~/.pi/agent/mcp.json (pi lo carga al
  # inicio). El json lo comparten gentle-ai (context7) y nosotros (serena), asi
  # que NO se reescribe entero: solo se agrega la entrada `serena` si falta.
  serenaMcp = pkgs.writeText "serena-mcp.json" (builtins.toJSON {
    command = "uvx";
    args = [
      "--no-python-downloads"
      "--python"
      "${pkgs.python313}/bin/python3.13"
      "--from"
      "git+https://github.com/oraios/serena"
      "serena"
      "start-mcp-server"
      "--project-from-cwd"
      "--context"
      "agent"
      "--open-web-dashboard"
      "False"
    ];
  });

  # Semilla minima de serena: serena la expande/reescribe al primer arranque
  # (migra a la plantilla completa y registra los proyectos). Solo importa que
  # exista la clave `projects`, sin ella el MCP muere con "Connection closed".
  serenaSeed = pkgs.writeText "serena_config.yml" ''
    web_dashboard_open_on_launch: false
    projects: []
  '';
in
{
  # uvx es el lanzador del MCP de serena (comando arriba).
  home.packages = [ pkgs.uv ];

  # Serena (MCP server) y mcp.json no se gestionan con home.file: serena
  # escribe su config global (registra proyectos) y pi/gentle-ai reescriben
  # mcp.json, asi que un symlink al store los romperia. La entrada `serena` se
  # agrega solo si falta (jq), sin tocar las otras entradas (context7).
  home.activation.ensureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.serena"
    if [ ! -f "$HOME/.serena/serena_config.yml" ]; then
      # install -m 600 (no cp): cp copia el modo 444 del store y con umask 077
      # el archivo queda 400, sin escritura; el re-seed siguiente muere con
      # "Permission denied" al abrir el archivo existente.
      ${pkgs.coreutils}/bin/install -m 600 ${serenaSeed} "$HOME/.serena/serena_config.yml"
    elif ! ${pkgs.gnugrep}/bin/grep -q '^projects:' "$HOME/.serena/serena_config.yml"; then
      printf '\nprojects: []\n' >> "$HOME/.serena/serena_config.yml"
    fi

    MCP="$HOME/.pi/agent/mcp.json"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/agent"
    if [ ! -f "$MCP" ]; then
      printf '{"mcpServers":{}}\n' > "$MCP"
      ${pkgs.coreutils}/bin/chmod 600 "$MCP"
    fi
    if ! ${pkgs.gnugrep}/bin/grep -q '"serena"' "$MCP"; then
      if ${pkgs.jq}/bin/jq --slurpfile s ${serenaMcp} \
           '.mcpServers.serena = $s[0]' "$MCP" > "$MCP.tmp"; then
        ${pkgs.coreutils}/bin/chmod 600 "$MCP.tmp"
        ${pkgs.coreutils}/bin/mv "$MCP.tmp" "$MCP"
      else
        ${pkgs.coreutils}/bin/rm -f "$MCP.tmp"
      fi
    fi
    # El CLI de uvx exige un python del store: el seed lleva el path cocido en
    # build-time y un rebuild+GC lo invalida (serena moria con "MCP error
    # -32000: Connection closed" / "No interpreter found at path ..."). En cada
    # activacion se re-apunta el interprete al path ACTUAL de este switch:
    # sed reemplaza cualquier /nix/store/xxx-python3.*/bin/python3.13 del json.
    CUR_PY=$(${pkgs.coreutils}/bin/readlink -f ${pkgs.python313}/bin/python3.13)
    if ! ${pkgs.gnugrep}/bin/grep -q "$CUR_PY" "$MCP"; then
      ${pkgs.gnused}/bin/sed -i \
        "s#/nix/store/[a-z0-9]*-python3[^/]*/bin/python3.13#$CUR_PY#" \
        "$MCP"
    fi
  '';
}
