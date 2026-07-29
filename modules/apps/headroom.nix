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
    ${pkgs.uv}/bin/uv tool install \
      --no-python-downloads \
      --python ${pkgs.python313}/bin/python3.13 \
      ${headroomPkg}
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
      ExecCondition = "${pkgs.coreutils}/bin/test -x %h/.local/bin/headroom";
      ExecStart = "%h/.local/bin/headroom proxy --port 8787";
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
