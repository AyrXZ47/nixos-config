{ config, pkgs, lib, ... }:

# opencode queda instalado como herramienta suelta (sin el flujo de olas
# retirado ni los agentes planner/executor/integrator/auditor). La auth del
# provider es estado del usuario (~/.local/share/opencode/auth.json).
#
# La config en ~/.config/opencode/opencode.json la reescribe opencode, asi que
# NO se gestiona con home.file: se siembra si falta, y si existe se limpian
# solo las claves muertas del flujo viejo (`default_agent: planner` y el MCP de
# serena, retirado) conservando el resto con jq.
let
  opencodeSeed = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "opencode-go/deepseek-v4.1-flash";
  });
in
{
  home.packages = [ pkgs.opencode ];

  home.activation.ensureOpencodeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
    f="$HOME/.config/opencode/opencode.json"
    if [ ! -f "$f" ]; then
      # install -m 600 (no cp): cp copiaria el modo 444 del store.
      ${pkgs.coreutils}/bin/install -m 600 ${opencodeSeed} "$f"
    else
      tmp="$(mktemp)"
      if ${pkgs.jq}/bin/jq 'del(.default_agent) | del(.mcp.serena)' "$f" > "$tmp" 2>/dev/null; then
        if ! ${pkgs.diffutils}/bin/cmp -s "$f" "$tmp"; then
          ${pkgs.coreutils}/bin/chmod 600 "$tmp"
          ${pkgs.coreutils}/bin/mv "$tmp" "$f"
        else
          ${pkgs.coreutils}/bin/rm -f "$tmp"
        fi
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
      fi
    fi
  '';
}
