{ pkgs, ... }:

# DeepSeek Harness (dsh), el harness de agentes de DeepSeek. nixpkgs ya lo
# empaqueta (pkgs/by-name/de/deepseek-harness) y el pin actual tiene binario en
# cache.nixos.org: no hace falta overlay, buildNpmPackage ni `npx` en runtime.
# home/default.nix lo importa, asi que llega a los 4 hosts.
#
# Arranca en limpio a proposito: sin skills, MCPs ni plugins externos, solo los
# plugins internos que trae el perfil `web`. La config vive en ~/.dsh (fuera
# del repo) y se administra desde la UI; no se siembra nada desde Nix.
let
  # DeepSeek solo publica el desktop para macOS/Windows. En Linux el core es
  # este mismo `dsh`, asi que `dsh-desktop` levanta el perfil web en un puerto
  # libre y lo abre en una ventana de Brave en modo app: sin pestañas ni barra
  # de URL, pero sin compilar el Electron oficial (ese build pesa ~6 GB y
  # ~1.255 derivaciones). El server se apaga al cerrar la ventana.
  dshDesktop = pkgs.writeShellApplication {
    name = "dsh-desktop";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep ];
    text = ''
      set -euo pipefail

      state="''${XDG_STATE_HOME:-$HOME/.local/state}/dsh-desktop"
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/dsh-desktop"
      mkdir -p "$state" "$cache"

      pidfile="$state/server.pid"
      if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        exit 0
      fi

      log="$cache/server.log"
      : > "$log"
      ${pkgs.deepseek-harness}/bin/dsh web --no-open --port 0 >"$log" 2>&1 &
      server=$!
      echo "$server" > "$pidfile"

      cleanup() {
        kill "$server" 2>/dev/null || true
        rm -f "$pidfile"
      }
      trap cleanup EXIT INT TERM

      url=""
      for _ in $(seq 1 60); do
        url=$(grep -oE 'http://127\.0\.0\.1:[0-9]+/\?token=[^[:space:]]+' "$log" | head -1 || true)
        [ -n "$url" ] && break
        if ! kill -0 "$server" 2>/dev/null; then
          cat "$log" >&2
          exit 1
        fi
        sleep 1
      done
      if [ -z "$url" ]; then
        echo "dsh web no imprimio la URL en 60 s" >&2
        cat "$log" >&2
        exit 1
      fi

      ${pkgs.brave-origin}/bin/brave-origin \
        --app="$url" \
        --class=DeepSeekHarness \
        --user-data-dir="$state/brave" \
        --no-first-run \
        --no-default-browser-check \
        --disable-features=Translate \
        >/dev/null 2>&1 &
      browser=$!

      trap 'kill "$browser" "$server" 2>/dev/null || true; rm -f "$pidfile"' EXIT INT TERM
      wait "$browser"
    '';
  };

  # El TUI no viene de fabrica (upstream lo retiro en 2026-08). El plugin
  # comunitario dsh-TUI se instala en un perfil aparte:
  #   dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui
  # Este wrapper solo evita recordar el --profile; el perfil `web` queda limpio.
  dshTui = pkgs.writeShellScriptBin "dsh-tui" ''
    exec ${pkgs.deepseek-harness}/bin/dsh --profile tui "$@"
  '';

  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/deepseek-ai/deepseek-harness/dsh-v0.2.1-rc.3/apps/desktop/resources/icon.png";
    hash = "sha256-mCwoWVaNg9JXYRClJ8VF8EZB9ACL2yz+tnWPMzwPsHo=";
  };
in
{
  home.packages = [ pkgs.deepseek-harness dshDesktop dshTui ];

  home.file.".local/share/icons/hicolor/1024x1024/apps/deepseek-harness.png".source = icon;

  xdg.desktopEntries.dsh-desktop = {
    name = "DeepSeek Harness";
    genericName = "AI agent harness";
    comment = "DeepSeek Harness en una ventana dedicada (Brave app mode)";
    exec = "${dshDesktop}/bin/dsh-desktop";
    icon = "deepseek-harness";
    categories = [ "Development" "Utility" ];
    startupNotify = true;
    terminal = false;
    settings.StartupWMClass = "DeepSeekHarness";
  };
}
