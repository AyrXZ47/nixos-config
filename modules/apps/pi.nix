{ config, pkgs, lib, ... }:

let
  # Los paquetes de pi/gentle-ai se resuelven por _module.args para que un
  # consumidor (nix-on-droid, donde el pkgs del home no lleva los overlays)
  # pueda inyectar sus propias derivaciones sin duplicar el modulo. El default
  # NO puede ir en la firma como `piPackage ? pkgs.pi-coding-agent`: nix trata
  # entonces el argumento como externo requerido y falla con "attribute
  # 'piPackage' missing" en los hosts que no lo pasan. Con `or` sobre
  # _module.args el default aplica y un consumidor lo puede sobreescribir.
  # pi-coding-agent es el paquete de nixpkgs (binario cacheado, version del
  # canal); el binario que instala es `pi`.
  piPackage = config._module.args.piPackage or pkgs.pi-coding-agent;
  gentleAiPackage = config._module.args.gentleAiPackage or pkgs.gentle-ai;
  # Node para el bootstrap de gentle-ai (ver abajo). En nix-on-droid se inyecta
  # el node envuelto con --single-threaded (el V8 de node 22 corrompe el heap
  # bajo proot); en los hosts de escritorio cae al pkgs.nodejs normal.
  nodePackage = config._module.args.nodePackage or pkgs.nodejs;
  # Defaults de arranque de pi: el modelo de opencode-go (DeepSeek V4.1 Flash),
  # thinking MAX (decision del dueno 2026-10-25: lo ponia a mano en cada host
  # asi que se fija en el flake; se paga en tokens de reasoning a cambio de
  # mejor criterio), el tema cyberpunk (el
  # default `system` hereda el verde de la terminal), el cursor REAL del
  # terminal (showHardwareCursor: kitty dibuja `cursor_trail` sobre el cursor
  # de hardware, y con el cursor falso que pi pinta por defecto no hay estela)
  # y `tuiMode = "fullscreen"` con rueda de 1 linea.
  #
  # POR QUE fullscreen (se probo regular y se volvio): en `regular` pi usa
  # TuiMainScreen, NO entra al alternate screen y deja el texto en el
  # scrollback de kitty, que scrollea por pixeles con inercia (suave de
  # verdad). El motivo REAL de volver no es el TODO: en regular el input es la
  # ultima linea del stream (no hay composer fijo), asi que al empezar a
  # escribir kitty salta al final y uno se pierde entre los outputs, avisos y
  # pensamiento acumulados. Eso es inherente a ceder la pantalla, no una
  # opcion. En fullscreen pi tiene layout propio: transcript arriba y
  # composer clavado abajo. Secundario: el sidebar de gentle-shell (con el
  # panel de TODO) tambien es solo de fullscreen.
  # `fullscreenWheelScrollLines = 1` es la granularidad mas fina posible en
  # fullscreen: un evento de rueda = una linea (en `auto`, un giro rapido
  # avanza hasta 6 lineas por evento). No hay easing: pi mueve lineas enteras,
  # y una TUI no puede recibir scroll sub-linea (eso es del scrollback de
  # kitty, no de una app con mouse propio).
  # Va en 3 para ir a la par de neovim (`mousescroll = ver:3`): 1 linea por
  # evento se sentia absurdamente lento en las dos herramientas.
  # REGLA: estos 7 campos son PROPIEDAD DEL FLAKE — cualquier host que haga
  # rebuild abre pi con deepseek-v4.1-flash sin tocar nada, aunque su
  # settings.json previo dijera otro modelo (pasaba: un host quedaba clavado en
  # deepseek/deepseek-v4-pro porque el seed solo aplicaba con `! -f`). Las
  # demas claves (packages, lastChangelogVersion, las que escriben pi y
  # gentle-ai) se PRESERVAN: el seed fusiona, no pisa el archivo completo.
  settingsSeed = pkgs.writeText "pi-settings.json" (builtins.toJSON {
    defaultProvider = "opencode-go";
    defaultModel = "deepseek-v4.1-flash";
    defaultThinkingLevel = "max";
    theme = "cyberpunk";
    showHardwareCursor = true;
    tuiMode = "fullscreen";
    fullscreenWheelScrollLines = 3;
  });

  # Routing de modelos de gentle-ai: TODOS los roles de agente usan
  # opencode-go/deepseek-v4.1-flash. Va en el flake para no reconfigurarlo a
  # mano en cada host ni despues de cada limpieza. El prefijo del proveedor es
  # obligatorio (`opencode-go/...`): un id pelado se resuelve por el registro
  # solo si UN proveedor lo tiene.
  # Roles: las 4 lentes de review + el refuter (que el proveedor lanza cuando
  # un revisor reporta un hallazgo severo para descartar falsos positivos).
  modelRouting = {
    review-reliability.model = "opencode-go/deepseek-v4.1-flash";
    review-risk.model = "opencode-go/deepseek-v4.1-flash";
    review-resilience.model = "opencode-go/deepseek-v4.1-flash";
    review-readability.model = "opencode-go/deepseek-v4.1-flash";
    review-refuter.model = "opencode-go/deepseek-v4.1-flash";
  };
  modelsSeed = pkgs.writeText "gentle-models.json" (builtins.toJSON modelRouting);

  # Persona de el Gentleman: `neutral` (espanol neutro, sin voseo ni
  # regionalismos). Config global de gentle-ai; el modo se resuelve
  # proyecto > global > default `gentleman` (ver readPersonaMode en
  # gentle-ai.ts), asi que esto fija el default de TODOS los repos que no
  # traigan su propio .pi/gentle-ai/persona.json. Cambiar de modo en
  # caliente: /gentle:persona (escribe este mismo archivo).
  # Solo se siembra si el archivo NO existe, igual que settingsSeed: un
  # rebuild no debe pisar la eleccion hecha con /gentle:persona.
  personaSeed = pkgs.writeText "gentle-persona.json" (builtins.toJSON {
    mode = "neutral";
  });
in
{
  # Tema cyberpunk de pi (paleta del repo). Se enlaza al agent-dir; pi lo
  # hot-recarga por nombre (`theme: cyberpunk` en settings.json).
  home.file.".pi/agent/themes/cyberpunk.json".source = ../../assets/pi/cyberpunk.json;

  home.activation.piSeedSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.pi/agent/settings.json"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/agent"
    if [ ! -f "$settings" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${settingsSeed} "$settings"
    else
      # Merge: los 4 campos del flake mandan, el resto del archivo se queda.
      # Se reescribe SOLO si alguno difiere (idempotente: un rebuild sin cambios
      # no toca el archivo ni su mtime).
      ${pkgs.python3}/bin/python3 - "$settings" ${settingsSeed} <<'PY'
import json, sys
path, seedf = sys.argv[1], sys.argv[2]
seed = json.load(open(seedf))
try:
    cur = json.load(open(path))
except (OSError, ValueError):
    cur = {}
merged = {**cur, **seed}
if merged != cur:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(merged, f, indent=2)
        f.write("\n")
    import os
    os.replace(tmp, path)
PY
    fi
  '';

  # El config-home de gentle-ai es ~/.pi/gentle-ai (lib/agent-home.ts:
  # GENTLE_PI_CONFIG_HOME || $HOME/.pi/gentle-ai). Se siembra con el mismo
  # guard que settings.json para no revertir un /gentle:persona posterior.
  home.activation.gentlePersonaSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.pi/gentle-ai/persona.json" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/gentle-ai"
      ${pkgs.coreutils}/bin/install -m 600 ${personaSeed} "$HOME/.pi/gentle-ai/persona.json"
    fi
  '';

  # Routing de modelos de gentle-ai. A diferencia de los seeds de arriba, aqui
  # NO basta `! -f`: el archivo ya existe (lo escribio /gentle:models o yo a
  # mano) y hay que asegurar que apunte al modelo del flake. Se compara el
  # CONTENIDO y solo se reescribe si difiere, asi el rebuild es idempotente y
  # no toca el archivo cuando ya esta correcto. Si cambias el modelo a mano con
  # /gentle:models, el proximo rebuild lo vuelve al del flake: eso es lo pedido
  # (una sola fuente de verdad), no un efecto colateral.
  home.activation.gentleModelsSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/gentle-ai"
    if ! ${pkgs.diffutils}/bin/cmp -s ${modelsSeed} "$HOME/.pi/gentle-ai/models.json" 2>/dev/null; then
      ${pkgs.coreutils}/bin/install -m 600 ${modelsSeed} "$HOME/.pi/gentle-ai/models.json"
    fi
  '';

  # Bootstrap del stack gentle-ai en maquinas nuevas: gentle-ai provisiona sus
  # paquetes de Pi (gentle-pi/engram/gga.../gentle-shell) y luego se agregan
  # las skills globales. Corre UNA vez por maquina (marcador), best-effort: si
  # no hay red el rebuild no falla y se reintenta en el proximo switch. Log
  # junto al marcador. Lo unico manual queda `pi` -> /login (la API key es un
  # secreto).
  #
  # El PATH base de la activacion de home-manager es minimo y NO trae
  # git/curl/node/npm: en NixOS salen del perfil del sistema, pero en
  # nix-on-droid no (ahi la activacion no ve ~/.nix-profile/bin) y el preflight
  # de gentle-ai aborta con "missing dependencies: git, curl, node, npm" sin
  # instalar NADA (sintoma: pi sin gentle-shell/gentle-pi ni skills). Por eso se
  # agregan explicitos: git (pi install git:...), curl (descargas) y nodePackage
  # (preflight de node/npm).
  # gzip: el postinstall de gentle-pi extrae su tarball con el /bin/tar del shim
  # FHS (common-packages.nix), y gnutar no trae gzip embebido: hace execvp("gzip")
  # contra el PATH. Sin gzip aqui falla con "tar (child): gzip: Cannot exec: No
  # such file or directory" y el bootstrap NUNCA marca bootstrap.done (sintoma:
  # reintenta en cada switch y pi queda sin gentle-pi/skills para siempre).
  home.activation.gentleAiBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" "piSeedSettings" ] ''
    mark="$HOME/.local/state/gentle-ai/bootstrap.done"
    if [ ! -f "$mark" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$mark")"
      echo "gentle-ai: bootstrap inicial (requiere red; log en ~/.local/state/gentle-ai/bootstrap.log)"
      if (
        export GENTLE_AI_YES=1
        export PATH="${piPackage}/bin:${gentleAiPackage}/bin:${pkgs.git}/bin:${pkgs.curl}/bin:${pkgs.gzip}/bin:${nodePackage}/bin:$HOME/.local/bin:$PATH"
        ${gentleAiPackage}/bin/gentle-ai install --agent pi \
          && ${piPackage}/bin/pi install git:github.com/cloudflare/security-audit-skill \
          && ${piPackage}/bin/pi install git:github.com/DietrichGebert/ponytail
      ) > "$HOME/.local/state/gentle-ai/bootstrap.log" 2>&1; then
        ${pkgs.coreutils}/bin/touch "$mark"
      else
        echo "gentle-ai: bootstrap fallo (offline?); se reintenta en el proximo rebuild"
      fi
    fi
  '';
}
