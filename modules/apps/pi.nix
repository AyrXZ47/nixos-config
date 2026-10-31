{ config, pkgs, lib, ... }:

let
  # Pi queda como harness de respaldo, sin gentle-ai ni paquetes de Pi. El
  # paquete se resuelve por _module.args para que nix-on-droid inyecte su
  # propia derivacion (su pkgs no lleva el overlay de pi).
  piPackage = config._module.args.piPackage or pkgs.pi-coding-agent;

  # Lo unico que se conserva es el modelo por defecto: si algun dia se abre
  # pi, arranca en DeepSeek V4.1 Flash con thinking max. Nada de packages,
  # extensions, skills ni MCPs.
  settingsSeed = pkgs.writeText "pi-settings.json" (builtins.toJSON {
    defaultProvider = "opencode-go";
    defaultModel = "deepseek-v4.1-flash";
    defaultThinkingLevel = "max";
  });
in
{
  home.packages = [ piPackage ];

  # Limpieza de la etapa gentle-ai. Corre en cada switch para que un host que
  # ya tenia el stack viejo quede igual que uno nuevo. Solo toca rutas que
  # pertenecen a gentle/pi extras; auth.json, sessions y models-store se
  # conservan. Los archivos que home-manager gestiona (tema, keybindings,
  # goal.ts) se borran por archivo y despues se intenta rmdir: nunca se borra
  # el directorio entero antes de que home-manager lo limpie.
  home.activation.piRemoveGentle = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf \
      "$HOME/.pi/agent/agents" \
      "$HOME/.pi/agent/chains" \
      "$HOME/.pi/agent/gentle-agents" \
      "$HOME/.pi/agent/gentle-ai" \
      "$HOME/.pi/agent/npm" \
      "$HOME/.pi/agent/pi-pretty" \
      "$HOME/.pi/agent/pi-web-access" \
      "$HOME/.pi/agent/web-search-cache" \
      "$HOME/.pi/agent/git" \
      "$HOME/.pi/agent/mcp.json" \
      "$HOME/.pi/agent/subagents.json" \
      "$HOME/.pi/gentle-ai" \
      "$HOME/.local/state/gentle-ai"
    rm -f \
      "$HOME/.pi/agent/extensions/goal.ts" \
      "$HOME/.pi/agent/keybindings.json" \
      "$HOME/.pi/agent/themes/cyberpunk.json"
    rmdir "$HOME/.pi/agent/extensions" "$HOME/.pi/agent/themes" 2>/dev/null || true
  '';

  # Seed de settings: el modelo manda; packages/extensions/modelThinkingLevels
  # se borran a proposito para que pi quede pelado aunque el archivo viejo los
  # tenga. Es idempotente: solo reescribe si algo cambia.
  home.activation.piSeedSettings = lib.hm.dag.entryAfter [ "writeBoundary" "piRemoveGentle" ] ''
    settings="$HOME/.pi/agent/settings.json"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/agent"
    if [ ! -f "$settings" ]; then
      ${pkgs.coreutils}/bin/install -m 600 ${settingsSeed} "$settings"
    else
      ${pkgs.python3}/bin/python3 - "$settings" ${settingsSeed} <<'PY'
import json, sys
path, seedf = sys.argv[1], sys.argv[2]
seed = json.load(open(seedf))
try:
    cur = json.load(open(path))
except (OSError, ValueError):
    cur = {}
for key in ("packages", "extensions", "modelThinkingLevels", "npmCommand"):
    cur.pop(key, None)
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
}
