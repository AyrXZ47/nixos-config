{ config, pkgs, lib, ... }:

let
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
        export PATH="${pkgs.pi}/bin:${pkgs.gentle-ai}/bin:$HOME/.local/bin:$PATH"
        ${pkgs.gentle-ai}/bin/gentle-ai install --agent pi \
          && ${pkgs.pi}/bin/pi install git:github.com/cloudflare/security-audit-skill \
          && ${pkgs.pi}/bin/pi install git:github.com/DietrichGebert/ponytail
      ) > "$HOME/.local/state/gentle-ai/bootstrap.log" 2>&1; then
        ${pkgs.coreutils}/bin/touch "$mark"
      else
        echo "gentle-ai: bootstrap fallo (offline?); se reintenta en el proximo rebuild"
      fi
    fi
  '';
}
