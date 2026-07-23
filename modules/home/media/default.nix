{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mpc
    ncmpcpp
    yt-dlp
    python3
  ];

  services.mpd = {
    enable = true;
    musicDirectory = "~/Music";
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
