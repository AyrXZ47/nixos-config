{ config, pkgs, lib, ... }:

# OpenCode es el harness por defecto de todos los hosts. La config se siembra
# con merge idempotente (no home.file) porque OpenCode reescribe sus archivos
# al vuelo. Las claves del flake mandan; el resto del archivo se conserva.
let
  # CLI de dotpm: habla con la API local del plugin (Obsidian desktop abierto)
  # y expone sus tools por stdio para OpenCode. PATH propio porque el server
  # MCP puede arrancar desde un lanzador sin el perfil de home-manager.
  # Sin pin: `dlx` resuelve la ultima release (con el retraso de 24 h de
  # minimumReleaseAge) para no arrastrar versiones viejas.
  dotpm = pkgs.writeShellScriptBin "dotpm" ''
    export PATH=${
      lib.makeBinPath [ pkgs.nodejs pkgs.coreutils pkgs.bash pkgs.findutils ]
    }:"$PATH"
    exec ${pkgs.pnpm}/bin/pnpm --reporter=append-only dlx "@dotpm/cli" "$@"
  '';

  opencodeSeed = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = {
      providerID = "opencode-go";
      model = "deepseek-v4.1-flash";
      variant = "max";
    };
    websearch = false;
    experimental = {
      todo = true;
    };
    mcp = {
      servers = {
        context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
        };
        gh_grep = {
          type = "remote";
          url = "https://mcp.grep.app";
        };
        duckduckgo = {
          type = "local";
          command = [ "${pkgs.uv}/bin/uvx" "duckduckgo-mcp-server" ];
          timeout = {
            startup = 120000;
          };
        };
        # Tablero de trabajo (proyectos/tareas del vault). Requiere Obsidian
        # abierto con el plugin project-manager y su Local API activa.
        dotpm = {
          type = "local";
          command = [
            "${dotpm}/bin/dotpm"
            "mcp"
            "--vault"
            "${config.home.homeDirectory}/Sync/Notes"
          ];
          timeout = {
            startup = 180000;
          };
        };
      };
    };
  });

  # Chime corto y deterministico para el evento "done" de OpenCode. No se
  # commitea un binario: se genera en build con la stdlib de Python. Evita
  # depender del sound pack built-in, que en algunas versiones no dispara
  # sonido al terminar la sesion.
  doneSound = pkgs.runCommand "opencode-done.wav" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 - "$out" <<'PY'
import math
import struct
import sys
import wave

path = sys.argv[1]
rate = 44100
duration = 0.28

with wave.open(path, "w") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(rate)
    for i in range(int(rate * duration)):
        t = i / rate
        attack = min(1.0, t / 0.02)
        release = max(0.0, 1.0 - max(0.0, t - 0.18) / 0.10)
        freq = 880.0 if t < 0.14 else 1320.0
        sample = 0.28 * attack * release * math.sin(2.0 * math.pi * freq * t)
        wav.writeframes(struct.pack("<h", int(sample * 32767)))
PY
  '';

  cliSeed = pkgs.writeText "opencode-cli.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/v2/cli.json";
    theme = {
      name = "system";
      mode = "system";
    };
    diffs = {
      wrap = "word";
    };
    session = {
      sidebar = "auto";
      scrollbar = true;
      thinking = "show";
      markdown = "rendered";
      image_preview = true;
      permissions = "autoaccept";
    };
    animations = true;
    tabs = {
      mode = "on";
      layout = "horizontal";
      indicators = "status";
    };
    scroll = {
      acceleration = true;
    };
    prompt = {
      paste = "compact";
      image_preview = true;
    };
    attention = {
      notifications = true;
      sound = true;
      volume = 1;
      sound_pack = "opencode.default";
      sounds = {
        default = "${config.home.homeDirectory}/.config/opencode/sounds/done.wav";
        done = "${config.home.homeDirectory}/.config/opencode/sounds/done.wav";
        subagent_done = "${config.home.homeDirectory}/.config/opencode/sounds/done.wav";
      };
    };
    highlights = true;
    terminal = {
      copy = "select";
    };
  });
in
{
  imports = [ ./opencode-skills.nix ];

  home.packages = [ pkgs.opencode pkgs.uv dotpm ];

  # Chime de fin de sesion. El archivo queda en una ruta estable para que la
  # config de OpenCode no dependa de un store path.
  home.file.".config/opencode/sounds/done.wav".source = doneSound;

  # Hindsight se retiro (2026-10-30): requeria Ollama para extraer hechos y no
  # sirve en laptop ni nix-on-droid. Se borra el runtime/config local y se
  # limpian las entradas viejas del opencode.json en ensureOpencodeConfig.
  home.activation.removeHindsight = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.hindsight"
  '';

  # Basic Memory se retiro (2026-11-04): rompia en cada release (0.18.5 cambio
  # el schema de config y greenlet necesita libstdc++) y nunca llego a guardar
  # nada. La memoria durable vive en el vault, que el agente lee con grep.
  home.activation.removeBasicMemory = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.basic-memory"
    rmdir "$HOME/Sync/Notes/PC & AI/Memory" 2>/dev/null || true
  '';

  home.activation.ensureOpencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"

    merge_json() {
      file="$1"
      seed="$2"
      if [ ! -f "$file" ]; then
        ${pkgs.coreutils}/bin/install -m 600 "$seed" "$file"
        return
      fi
      ${pkgs.python3}/bin/python3 - "$file" "$seed" <<'PY'
import json, sys

path, seedf = sys.argv[1], sys.argv[2]
seed = json.load(open(seedf))
try:
    cur = json.load(open(path))
except (OSError, ValueError):
    cur = {}

cur.pop("default_agent", None)
mcp = cur.get("mcp")
if isinstance(mcp, dict):
    mcp.pop("serena", None)
    mcp.pop("basic-memory", None)

# Migracion: Hindsight y el subagente review viejo ya no existen. Se limpian
# del archivo vivo aunque el merge no los vuelva a sembrar.
for key in ("plugin", "plugins"):
    value = cur.get(key)
    if isinstance(value, list):
        value = [item for item in value if "hindsight" not in str(item).lower()]
        if value:
            cur[key] = value
        else:
            cur.pop(key, None)
    elif isinstance(value, str) and "hindsight" in value.lower():
        cur.pop(key, None)

agents = cur.get("agents")
if isinstance(agents, dict):
    review = agents.get("review")
    if isinstance(review, dict) and review.get("description") == "Revisa cambios y riesgos sin editar archivos":
        agents.pop("review", None)
    if not agents:
        cur.pop("agents", None)

before = json.dumps(cur, sort_keys=True)

def merge(dst, src):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            merge(dst[key], value)
        else:
            dst[key] = value

merge(cur, seed)
if json.dumps(cur, sort_keys=True) != before:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cur, f, indent=2)
        f.write("\n")
    import os
    os.replace(tmp, path)
PY
    }

    merge_json "$HOME/.config/opencode/opencode.json" ${opencodeSeed}
    merge_json "$HOME/.config/opencode/cli.json" ${cliSeed}
  '';
}
