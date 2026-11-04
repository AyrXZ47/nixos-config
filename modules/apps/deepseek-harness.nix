{ config, pkgs, lib, ... }:

# DeepSeek Harness (dsh), TUI-only. nixpkgs ya lo empaqueta
# (pkgs/by-name/de/deepseek-harness) y el pin actual tiene binario en
# cache.nixos.org: no hace falta overlay, buildNpmPackage ni `npx` en runtime.
# home/default.nix lo importa, asi que llega a los 4 hosts.
#
# Sin wrapper de navegador, Electron ni Brave: el unico front end que se
# instala es `dsh-tui`, que corre sobre el perfil `tui` (dsh-base + dsh-tui).
#
# Lo que siembra este modulo para que `dsh` arranque listo en cualquier host:
#   ~/.dsh/skills/*            skills compartidas con OpenCode (mismos sources)
#   ~/.dsh/AGENTS.md           reglas globales (mismo texto que OpenCode)
#   ~/.dsh/cordis.patch.yml    MCPs; capa de usuario, pisa el patch del perfil
#   ~/.dsh/.env                OPENCODE_GO_API_KEY copiada de la auth de OpenCode
#   ~/.dsh-tui/model.json      modelo por defecto: opencode-go/deepseek-v4.1-flash
#   ~/.dsh-tui/onboarding.json setup ya completado: no aparece el wizard
#   ~/.dsh/profiles/tui        se crea sola si falta (necesita red la primera vez)
#
# dsh descubre skills en ~/.dsh/skills sin config: skill-filesystem ya viene
# montado por el preset del agente y vigila el directorio en caliente.
let
  dshTui = pkgs.writeShellScriptBin "dsh-tui" ''
    exec ${pkgs.deepseek-harness}/bin/dsh --profile tui "$@"
  '';

  tuiProfile = ".dsh/profiles/tui";

  # Mismas skills que OpenCode: se reusa el source que ya declara
  # opencode-skills.nix en vez de duplicar los fetchFromGitHub.
  skillNames = [ "dotpm" "frontend-design" "ponytail" "security-audit" "vault" ];

  # MCPs migrados desde ~/.config/opencode/opencode.json. duckduckgo va aunque
  # dsh tenga web_fetch nativo: la busqueda nativa pide DEEPSEEK_API_KEY y con
  # opencode-go no hay. Queda fuera basic-memory: roto tambien en OpenCode
  # (0.18.5 pide projects.<name> como string, y greenlet necesita libstdc++).
  mcpPatch = [
    {
      insert = [
        {
          id = "mcp-context7";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "context7";
            transport = "streamable-http";
            url = "https://mcp.context7.com/mcp";
          };
        }
        {
          id = "mcp-gh-grep";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "gh_grep";
            transport = "streamable-http";
            url = "https://mcp.grep.app";
          };
        }
        {
          id = "mcp-duckduckgo";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "duckduckgo";
            transport = "stdio";
            command = "${pkgs.uv}/bin/uvx";
            args = [ "duckduckgo-mcp-server" ];
          };
        }
        {
          id = "mcp-dotpm";
          name = "@deepseek-ai/dsh-mcp-client";
          config = {
            serverName = "dotpm";
            transport = "stdio";
            command = "${config.home.profileDirectory}/bin/dotpm";
            args = [ "mcp" "--vault" "${config.home.homeDirectory}/Sync/Notes" ];
          };
        }
      ];
    }
  ];

  # Plugins del perfil. Los bundles oficiales se montan por nombre: resuelven
  # desde la instalacion, sin `dsh plugin add` ni red (el paquete de npm esta
  # en 0.2.1-alpha.2 y el runtime en 0.2.1-rc.3, asi que el CLI los rechaza).
  #   worktree        create_worktree: rama + checkout nuevos, y la sesion se
  #                   mueve ahi. Deja el checkout original intacto.
  #   dsh-chime       plugin local: sonido al terminar el turno.
  #   session-search no entra: no resuelve sus deps desde el perfil.
  bundlePatch = [
    {
      insert = [
        {
          id = "worktree";
          name = "@deepseek-ai/dsh-experimental-worktree";
        }
        {
          id = "tool-worktree";
          name = "@deepseek-ai/dsh-experimental-tool-worktree";
        }
        {
          id = "dsh-chime";
          name = chimePlugin;
        }
      ];
    }
  ];

  # Arranque de la TUI. Un patch reemplaza la config ENTERA de la fila, asi
  # que hay que repetir lo que pone el bundle (provider/fullscreen/effort) o se
  # pierde. Efecto: /settings ya no puede pisar estas claves (el patch de home
  # gana al del perfil); para cambiarlas se edita aca.
  #   launchpad false   entra directo al chat: la ballena del header se ve al
  #                     instante. El launchpad la descarta en terminales bajos
  #                     (la escalera de degradacion le saca las 13 filas del
  #                     arte) y por eso pedia un Enter para verla.
  #   turnUsageRow      ledger al cerrar cada turno: tokens, cache y span
  #   scrollGutter      barra de scroll a la derecha
  #   sidePanel         sin tocar: defaults del plugin (cerrado, todos los
  #                     paneles). Abrirlo achica el chat y esconde la ballena.
  tuiPatch = [
    {
      id = "dsh-tui";
      config = {
        provider = "opencode-go";
        fullscreen = true;
        terminalImages = true;
        effort = "max";
        launchpad = false;
        turnUsageRow = true;
        whale = true;
        whaleIdle = true;
        scrollGutter = "scrollbar";
        notificationMethod = "auto";
        thinkingFold = "preview";
      };
    }
    {
      id = "permission";
      config = {
        presets = {
          read-only = {
            sandbox = "read-only";
            approval = "ask";
          };
          workspace-write = {
            sandbox = "workspace-write";
            approval = "ask";
          };
          danger-full-access = {
            sandbox = "danger-full-access";
            approval = "never";
          };
        };
        defaultPreset = "danger-full-access";
      };
    }
  ];

  # Chime propio (descendente, distinto del de OpenCode) envuelto en un script:
  # el hook corre con el entorno limpiado y pw-play sin XDG_RUNTIME_DIR no
  # encuentra el socket de PipeWire ("Host is down"), asi que el wrapper lo
  # resuelve por uid.
  dshChime = pkgs.writeShellScriptBin "dsh-chime" ''
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
    exec ${pkgs.pipewire}/bin/pw-play ${(import ./chimes.nix { inherit pkgs; }).dsh}
  '';

  # Sonido al terminar el turno. Va como plugin propio y no con
  # hooks-claude-code: los hooks corren con un sandbox workspace-write fijo y
  # este host no tiene backend de sandbox, asi que el comando nunca ejecuta.
  # El plugin corre en proceso (sin sandbox) y spawnea el wrapper.
  chimePlugin = pkgs.writeText "dsh-chime.mjs" ''
    import { spawn } from 'node:child_process'

    // Un sonido por turno: los subagentes tambien emiten turn-stopping.
    const CHIME = '${dshChime}/bin/dsh-chime'
    let last = 0

    export const name = 'dsh-chime'

    export function apply(ctx) {
      ctx.on('agent/turn-stopping', () => {
        const now = Date.now()
        if (now - last < 3000) return
        last = now
        spawn(CHIME, [], { detached: true, stdio: 'ignore' }).unref()
      })
    }
  '';
in
{
  home.packages = [ pkgs.deepseek-harness dshTui ];

  home.file = builtins.listToAttrs (map
    (name: {
      name = ".dsh/skills/${name}";
      value.source = config.home.file.".config/opencode/skills/${name}".source;
    })
    skillNames) // {
    ".dsh/AGENTS.md".text = config.home.file.".config/opencode/AGENTS.md".text;
    ".dsh/cordis.patch.yml".text = builtins.toJSON (mcpPatch ++ bundlePatch ++ tuiPatch);
  };

  # El perfil no viaja en Nix (es un node_modules de pnpm). Se crea una vez por
  # host; sin red falla y queda el comando a mano.
  home.activation.ensureDshProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/${tuiProfile}/package.json" ]; then
      PATH=${lib.makeBinPath [ pkgs.pnpm pkgs.nodejs pkgs.coreutils ]}:"$PATH" \
        ${pkgs.deepseek-harness}/bin/dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui \
        || echo "dsh: no se pudo crear el perfil tui (¿sin red?); corré: dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui" >&2
    fi
  '';

  # Estado por-maquina que dsh no lee de cordis.yml: sin estos dos archivos el
  # TUI arranca en deepseek-official (sin credencial) y muestra el wizard de
  # setup en cada launch. Solo se escriben si faltan.
  home.activation.seedDshTuiState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.dsh-tui" "$HOME/.dsh"
    if [ ! -f "$HOME/.dsh-tui/model.json" ]; then
      printf '%s\n' '{"provider":"opencode-go","model":"deepseek-v4.1-flash"}' \
        > "$HOME/.dsh-tui/model.json"
    fi
    if [ ! -f "$HOME/.dsh-tui/onboarding.json" ]; then
      printf '%s\n' '{"completed":true,"version":1}' > "$HOME/.dsh-tui/onboarding.json"
    fi
  '';

  # La API key no se commitea: se copia de la auth de OpenCode (unica fuente)
  # a ~/.dsh/.env en cada switch. Otras variables del archivo se preservan.
  home.activation.seedDshApiKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.python3}/bin/python3 - "$HOME" <<'PY'
import json, os, sys

home = sys.argv[1]
try:
    with open(os.path.join(home, ".local/share/opencode/auth.json")) as f:
        key = json.load(f)["opencode-go"]["key"]
except (OSError, ValueError, KeyError, TypeError):
    raise SystemExit(0)
if not isinstance(key, str) or not key:
    raise SystemExit(0)

path = os.path.join(home, ".dsh/.env")
kept = []
if os.path.exists(path):
    with open(path) as f:
        kept = [l for l in f.read().splitlines() if not l.startswith("OPENCODE_GO_API_KEY=")]
kept.append("OPENCODE_GO_API_KEY=" + key)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as f:
    f.write("\n".join(kept) + "\n")
os.chmod(path, 0o600)
PY
    ${pkgs.coreutils}/bin/grep -q '^OPENCODE_GO_API_KEY=.' "$HOME/.dsh/.env" \
      || echo "dsh: ~/.dsh/.env sin API key (¿OpenCode sin login?)" >&2
  '';
}
