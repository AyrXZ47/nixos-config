{ config, pkgs, lib, ... }:

let
  # Config conocida-buena de opencode (MCP de headroom + serena + provider).
  # Se copia a un archivo normal (no symlink): headroom hace backup/reescribe
  # opencode.json en su lugar (`.headroom-backup`).
  opencodeSeed = pkgs.writeText "opencode.json" ''
    {
      "$schema": "https://opencode.ai/config.json",
      "mcp": {
        "headroom": {
          "type": "local",
          "command": [
            "/home/yovick/.local/bin/headroom",
            "mcp",
            "serve"
          ],
          "enabled": true
        },
        "serena": {
          "type": "local",
          "command": [
            "uvx",
            "--from",
            "git+https://github.com/oraios/serena",
            "serena",
            "start-mcp-server",
            "--project-from-cwd",
            "--context",
            "agent",
            "--open-web-dashboard",
            "False"
          ],
          "enabled": true
        }
      },
      "provider": {
        "headroom": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "Headroom Proxy",
          "options": {
            "baseURL": "http://127.0.0.1:8787/v1"
          },
          "models": {
            "claude-sonnet-4-6": {
              "name": "Claude Sonnet 4.6",
              "limit": {
                "context": 200000,
                "output": 16384
              }
            },
            "claude-opus-4-6": {
              "name": "Claude Opus 4.6",
              "limit": {
                "context": 200000,
                "output": 16384
              }
            },
            "claude-haiku-4-5-20251001": {
              "name": "Claude Haiku 4.5",
              "limit": {
                "context": 200000,
                "output": 8192
              }
            },
            "gpt-4o": {
              "name": "GPT-4o",
              "limit": {
                "context": 128000,
                "output": 16384
              }
            },
            "gpt-4.1": {
              "name": "GPT-4.1",
              "limit": {
                "context": 1048576,
                "output": 32768
              }
            }
          }
        }
      }
    }
  '';

  # Semilla minima de serena: serena la expande/reescribe al primer arranque
  # (migra a la plantilla completa y registra los proyectos). Solo importa que
  # exista la clave `projects`, sin ella el MCP muere con "Connection closed".
  serenaSeed = pkgs.writeText "serena_config.yml" ''
    web_dashboard_open_on_launch: false
    projects: []
  '';
in
{
  # Serena (MCP server) y opencode.json no se gestionan con home.file: serena
  # escribe su config global (registra proyectos) y headroom reescribe
  # opencode.json, asi que un symlink al store los romperia. En su lugar se
  # siembra una copia escribible solo cuando falta, o se repara la clave
  # `projects` — el mismo patron de guardia que el modulo de headroom.
  home.activation.ensureSerena = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.serena"
    if [ ! -f "$HOME/.serena/serena_config.yml" ]; then
      cp ${serenaSeed} "$HOME/.serena/serena_config.yml"
    elif ! ${pkgs.gnugrep}/bin/grep -q '^projects:' "$HOME/.serena/serena_config.yml"; then
      printf '\nprojects: []\n' >> "$HOME/.serena/serena_config.yml"
    fi

    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
    if [ ! -f "$HOME/.config/opencode/opencode.json" ]; then
      cp ${opencodeSeed} "$HOME/.config/opencode/opencode.json"
    fi
  '';
}
