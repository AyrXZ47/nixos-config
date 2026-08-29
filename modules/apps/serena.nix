{ config, pkgs, lib, ... }:

let
  # Config conocida-buena de opencode (MCP de serena; el provider opencode-go es
  # nativo y su key vive en ~/.local/share/opencode/auth.json). Se copia a un
  # archivo normal (no symlink) para que serena/opencode puedan escribirlo.
  # Los roles nativos de opencode (build/plan/general/explore) se mantienen
  # ACTIVOS junto a los agentes propios del flujo (planner/executor/integrator/
  # auditor de modules/apps/opencode.nix).
  opencodeSeed = pkgs.writeText "opencode.json" ''
    {
      "$schema": "https://opencode.ai/config.json",
      "default_agent": "planner",
      "model": "opencode-go/glm-5.3-flash",
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
  # opencode.json se re-siembra si aun conserva headroom (semilla vieja), la
  # invocacion vieja de uvx sin el python de nix (uv descargaba su propio
  # python 3.14 que no corre en NixOS y el MCP moria con "Connection closed"),
  # o si el modelo default diverge del del repo (el default lo dicta ESTE
  # archivo para todas las maquinas; si el json local lo cambia a mano o una
  # version vieja lo dejo sin clave, el switch lo repara — para cambiar el
  # default global, cambia el seed aqui, no el archivo local).
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

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
    if [ ! -f "$HOME/.config/opencode/opencode.json" ] || \
       ${pkgs.gnugrep}/bin/grep -q 'headroom' "$HOME/.config/opencode/opencode.json" || \
       ${pkgs.gnugrep}/bin/grep -q '"disable"' "$HOME/.config/opencode/opencode.json" || \
       ! ${pkgs.gnugrep}/bin/grep -q 'no-python-downloads' "$HOME/.config/opencode/opencode.json" || \
       ! ${pkgs.gnugrep}/bin/grep -q '"default_agent"' "$HOME/.config/opencode/opencode.json" || \
       ! ${pkgs.gnugrep}/bin/grep -q '"model": "opencode-go/glm-5.3-flash"' "$HOME/.config/opencode/opencode.json"; then
      # Mismo motivo que arriba: cp dejaria 400 y romperia el re-seed.
      ${pkgs.coreutils}/bin/install -m 600 ${opencodeSeed} "$HOME/.config/opencode/opencode.json"
    fi
    # El CLI de uvx exige un python del store: el seed lleva el path cocido en
    # build-time y un rebuild+GC lo invalida (serena moría con "MCP error
    # -32000: Connection closed" / "No interpreter found at path ..."). En cada
    # activacion se re-apunta el interpretes al path ACTUAL (heredado del build
    # de este switch): sed reemplaza cualquier /nix/store/xxx-python3.*/bin/
    # python3.13 del json por el de este sistema.
    CUR_PY=$(${pkgs.coreutils}/bin/readlink -f ${pkgs.python313}/bin/python3.13)
    if ! ${pkgs.gnugrep}/bin/grep -q "$CUR_PY" "$HOME/.config/opencode/opencode.json"; then
      ${pkgs.gnused}/bin/sed -i \
        "s#/nix/store/[a-z0-9]*-python3[^/]*/bin/python3.13#$CUR_PY#" \
        "$HOME/.config/opencode/opencode.json"
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
