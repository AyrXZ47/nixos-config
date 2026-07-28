{ config, pkgs, lib, ... }:

{
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
