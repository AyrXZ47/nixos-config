{ config, pkgs, lib, ... }:

let
  # Los paquetes de pi/gentle-ai se resuelven por _module.args para que un
  # consumidor (nix-on-droid, donde el pkgs del home no lleva los overlays)
  # pueda inyectar sus propias derivaciones sin duplicar el modulo. El default
  # NO puede ir en la firma como `piPackage ? pkgs.pi`: nix trata entonces el
  # argumento como externo requerido y falla con "attribute 'piPackage'
  # missing" en los hosts que no lo pasan. Con `or` sobre _module.args el
  # default aplica y un consumidor lo puede sobreescribir.
  piPackage = config._module.args.piPackage or pkgs.pi;
  gentleAiPackage = config._module.args.gentleAiPackage or pkgs.gentle-ai;
  # Defaults de arranque de pi: modelo barato (flash) con thinking OFF (sin
  # reasoning, no quemar tokens) y el tema cyberpunk (el default `system`
  # hereda el verde de la terminal). Solo se siembra si el archivo NO existe:
  # pi y gentle-ai lo reescriben (packages, etc.) y no se debe pisar.
  settingsSeed = pkgs.writeText "pi-settings.json" (builtins.toJSON {
    defaultProvider = "deepseek";
    defaultModel = "deepseek-flash";
    defaultThinkingLevel = "off";
    theme = "cyberpunk";
  });

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
    if [ ! -f "$HOME/.pi/agent/settings.json" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/agent"
      ${pkgs.coreutils}/bin/install -m 600 ${settingsSeed} "$HOME/.pi/agent/settings.json"
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

  # Bootstrap del stack gentle-ai en maquinas nuevas: gentle-ai provisiona sus
  # paquetes de Pi (gentle-pi/engram/gga...) y luego se agregan las skills
  # globales. Corre UNA vez por maquina (marcador), best-effort: si no hay red
  # el rebuild no falla y se reintenta en el proximo switch. Log junto al
  # marcador. Lo unico manual queda `pi` -> /login (la API key es un secreto).
  home.activation.gentleAiBootstrap = lib.hm.dag.entryAfter [ "writeBoundary" "piSeedSettings" ] ''
    mark="$HOME/.local/state/gentle-ai/bootstrap.done"
    if [ ! -f "$mark" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$mark")"
      echo "gentle-ai: bootstrap inicial (requiere red; log en ~/.local/state/gentle-ai/bootstrap.log)"
      if (
        export GENTLE_AI_YES=1
        export PATH="${piPackage}/bin:${gentleAiPackage}/bin:$HOME/.local/bin:$PATH"
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
