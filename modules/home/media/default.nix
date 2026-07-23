{config, pkgs, ... }:

{
  home.packages = with pkgs; [
    mpc
    ncmpcpp
    yt-dlp
  ];

  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Music";
    extraConfig = ''
      audio_output {
        type "pulse"
        name "PulseAudio/PipeWire Output"
      }
      auto_crossfade "yes"
    '';
  };

  services.mpdris2.enable = true;
}
