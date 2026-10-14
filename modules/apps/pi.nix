{ config, pkgs, lib, ... }:

let
  # Defaults de arranque de pi: modelo barato (flash) en thinking `low` para
  # no quemar tokens, y el tema cyberpunk (el default `system` hereda el verde
  # de la terminal). Solo se siembra si el archivo NO existe: pi y gentle-ai lo
  # reescriben (packages, etc.) y no se debe pisar.
  settingsSeed = pkgs.writeText "pi-settings.json" (builtins.toJSON {
    defaultProvider = "deepseek";
    defaultModel = "deepseek-flash";
    defaultThinkingLevel = "low";
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
}
