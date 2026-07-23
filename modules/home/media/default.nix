{ pkgs, ... }:

{
  # Herramientas del ecosistema
  home.packages = with pkgs; [
    mpc-cli
    ncmpcpp
    yt-dlp
    python3 # Necesario para ejecutar tu script sync_likes.py
  ];

  # Demonio MPD gestionado por systemd
  services.mpd = {
    enable = true;
    musicDirectory = "~/Music"; # Apuntará a la carpeta sincronizada en el futuro
    extraConfig = ''
      audio_output {
        type "pulse"
        name "PulseAudio/PipeWire Output"
      }
      # Configuración de crossfade de 4 segundos
      auto_crossfade "yes"
    '';
  };

  # Control MPRIS para manejar MPD desde las teclas multimedia del teclado/panel GNOME
  services.mpdris2.enable = true;

  # Si tienes tus archivos de configuración nativos en tu repo, puedes enlazarlos así:
  # xdg.configFile."ncmpcpp/config".source = ../../../../src/linux-tweaks/ncmpcpp/config;
}
