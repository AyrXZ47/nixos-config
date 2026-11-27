{ config, pkgs, lib, ... }:

# OpenCode es el harness por defecto de todos los hosts. La config se siembra
# con merge idempotente (no home.file) porque OpenCode reescribe sus archivos
# al vuelo. Las claves del flake mandan; el resto del archivo se conserva.
let
  # CLI de dotpm: habla con la API local del plugin (Obsidian desktop abierto)
  # y expone sus tools por stdio para OpenCode. El paquete 0.2.0 es un bundle
  # ESM autocontenido (sin dependencias npm), así que se empaqueta directo y
  # no hay `pnpm dlx` ni red en runtime.
  dotpm = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "dotpm";
    version = "0.2.0";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@dotpm/cli/-/cli-${version}.tgz";
      hash = "sha256-KEe1CzN5HFHWJ/NKgUf0iUgQ14OBcwu9e7tGCuWzlDU=";
    };

    sourceRoot = "package";
    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/dotpm $out/bin
      cp -r build package.json $out/lib/dotpm/
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/dotpm \
        --add-flags "$out/lib/dotpm/build/dotpm.js"
      runHook postInstall
    '';

    meta = {
      description = "CLI for the dotpm project-manager board";
      homepage = "https://github.com/dotpm";
      license = lib.licenses.mit;
      mainProgram = "dotpm";
    };
  };

  # DuckDuckGo MCP: paquete Python real (0.1.2) en vez de `uvx` contra PyPI.
  # Dependencias en nixpkgs: beautifulsoup4, httpx y mcp[cli].
  duckduckgo-mcp = pkgs.python3Packages.buildPythonApplication rec {
    pname = "duckduckgo-mcp-server";
    version = "0.1.2";
    pyproject = true;

    src = pkgs.fetchurl {
      # PyPI sirve el sdist con guion bajo; `fetchPypi` arma guiones y da 404.
      url = "https://files.pythonhosted.org/packages/cf/23/d176f8910d55d270c1ceb9035e2c63e06df99237376e46444819acf78ae0/duckduckgo_mcp_server-0.1.2.tar.gz";
      hash = "sha256-mq8YiIii2M8utJAgXR7CFZUkKHeq0HDxrddQeVv+3S4=";
    };

    build-system = [ pkgs.python3Packages.hatchling ];
    dependencies = with pkgs.python3Packages; [
      beautifulsoup4
      httpx
      # 0.1.2 importa `mcp.server.fastmcp` (API v1); `mcp` 2.x lo renombró.
      mcp_1
      typer
      rich
      click
      python-dotenv
    ];

    doCheck = false;
    meta.mainProgram = "duckduckgo-mcp-server";
  };

  # OpenCode Browse: MCP server + extensión de Chromium. Upstream publica un
  # standalone de Bun por plataforma en npm; se parchea el intérprete para
  # NixOS y se apaga el auto-update (el store es de solo lectura). La extensión
  # se instala por política de Brave en desktop.nix; el pairing sigue
  # siendo manual (`browse pair`) porque es un consentimiento del navegador.
  browseUnwrapped = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "opencode-browse";
    version = "0.0.16";

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@opencode/browse-linux-x64/-/browse-linux-x64-${version}.tgz";
      hash = "sha256-SloA6xXp2LEmvtUPBJnKtR6cUBvJZThms9AC01IxBRw=";
    };

    sourceRoot = "package";
    nativeBuildInputs = [ pkgs.patchelf ];

    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/browse $out/bin/browse
      patchelf --set-interpreter ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 $out/bin/browse
      runHook postInstall
    '';

    meta = with pkgs.lib; {
      description = "MCP server and CLI for OpenCode Browse";
      homepage = "https://opencode.ai/product/browse";
      license = licenses.mit;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
    };
  };

  browse = pkgs.writeShellScriptBin "browse" ''
    export OPENCODE_BROWSER_AUTO_UPDATE=off
    export OPENCODE_BROWSER_UPDATE_CHECK=0
    exec ${browseUnwrapped}/bin/browse "$@"
  '';

  opencodeSeed = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = {
      providerID = "opencode-go";
      model = "deepseek-v4.1-flash";
      variant = "high";
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
          command = [ "${duckduckgo-mcp}/bin/duckduckgo-mcp-server" ];
          timeout = {
            startup = 120000;
          };
        };
        # Navegador real (Brave) con las sesiones del usuario. La extensión
        # se instala por política en desktop.nix; el pairing es
        # manual la primera vez (`browse pair`).
        browse = {
          type = "local";
          command = [ "${browse}/bin/browse" "mcp" ];
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

  # Chime del evento "done". DSH se retiró; queda el generador de OpenCode.
  chimes = import ./chimes.nix { inherit pkgs; };

  cliSeed = pkgs.writeText "opencode-cli.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/v2/cli.json";
    theme = {
      name = "system";
      mode = "system";
    };
    diffs = {
      wrap = "word";
    };
    # Timeline de la sesion: marca la hora de cada prompt/salida y los spans.
    keybinds = {
      "session.timeline" = "ctrl+t";
    };
    session = {
      sidebar = "auto";
      scrollbar = true;
      thinking = "hide";
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

  home.packages = [ pkgs.opencode dotpm duckduckgo-mcp browse ];

  # Chime de fin de sesion. El archivo queda en una ruta estable para que la
  # config de OpenCode no dependa de un store path.
  home.file.".config/opencode/sounds/done.wav".source = chimes.opencode;

  # Hindsight se retiro (2026-10-30): requeria Ollama para extraer hechos y no
  # sirve en laptop ni nix-on-droid. Se borra el runtime/config local y se
  # limpian las entradas viejas del opencode.json en ensureOpencodeConfig.
  home.activation.removeHindsight = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.hindsight"
  '';

  # DSH se retiró (2026-11-27): no se usa. Se limpia el estado/config local.
  home.activation.removeDsh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.dsh" "$HOME/.dsh-tui"
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
    # La config real vive en mcp.servers.<nombre>; el nivel mcp.* directo
    # (formato viejo) se limpia igual por si quedo de una migracion.
    mcp.pop("serena", None)
    mcp.pop("basic-memory", None)
    servers = mcp.get("servers")
    if isinstance(servers, dict):
        servers.pop("serena", None)
        servers.pop("basic-memory", None)

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
