{ config, pkgs, lib, ... }:

# OpenCode es el harness por defecto de todos los hosts. La config se siembra
# con merge idempotente (no home.file) porque OpenCode reescribe sus archivos
# al vuelo. Las claves del flake mandan; el resto del archivo se conserva.
let
  opencodeSeed = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = {
      providerID = "opencode-go";
      model = "deepseek-v4.1-flash";
      variant = "max";
    };
    websearch = {
      provider = "tavily";
    };
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
      };
    };
  });

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
    };
    highlights = true;
    terminal = {
      copy = "select";
    };
  });
in
{
  imports = [ ./opencode-skills.nix ];

  home.packages = [ pkgs.opencode ];

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
