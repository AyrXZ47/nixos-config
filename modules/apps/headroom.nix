{ config, pkgs, lib, ... }:

let
  headroomPkg = "headroom-ai[all]";
  pythonVersion = "3.13";
in
{
  home.packages = with pkgs; [ uv python313 ];

  home.activation.installHeadroom = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [[ "''${VERBOSE:-}" != "true" ]]; then
      export UV_QUIET=1
      export UV_NO_PROGRESS=1
    fi
    export UV_TOOL_DIR="$HOME/.local/share/uv/tools"
    # Solo instala si falta: uv tarda ~6s en resolver aunque ya esté instalado
    # y esto corre en cada boot (en el path crítico del display-manager).
    if [ ! -x "$HOME/.local/bin/headroom" ]; then
      ${pkgs.uv}/bin/uv tool install \
        --no-python-downloads \
        --python ${pkgs.python313}/bin/python3.13 \
        ${headroomPkg}
    fi
    ${pkgs.systemd}/bin/systemctl --user restart headroom-proxy 2>/dev/null || true
  '';

  systemd.user.services.headroom-proxy = {
    Unit = {
      Description = "Headroom Proxy Service (User Level)";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      Environment = "HEADROOM_OUTPUT_SHAPER=1";
      # Sin ExecCondition: en el primer arranque el tool aún no está instalado
      # (uv tool install corre en home.activation) y saltar el servicio era terminal
      # → opencode veía "connection closed". Restart+RestartSec reintenta hasta que exista.
      ExecStart = "%h/.local/bin/headroom proxy --port 8787";
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
