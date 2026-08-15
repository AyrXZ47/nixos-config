{ pkgs, ... }:
# Dolphin: service menu "Ver metadatos" (equivalente a la pestana Audio/Video
# de Nautilus). Dolphin solo muestra metadatos de video en GUI cuando Baloo
# esta indexando (KF6 elimino baloo_filemetadata_temp_extractor, el extractor
# on-demand que usaba baloo-widgets, asi que sin indice no hay Details tab).
# Este menu contextual corre ffprobe y muestra el resultado en kdialog.
{
  home.packages = with pkgs; [
    kdePackages.kdialog
    (writeShellScriptBin "ver-metadatos" ''
      set -u
      file="$1"
      [ -f "$file" ] || exit 1
      out=$(${pkgs.coreutils}/bin/mktemp --suffix=.txt)
      trap '${pkgs.coreutils}/bin/rm -f "$out"' EXIT
      {
        echo "Archivo: $(${pkgs.coreutils}/bin/basename "$file")"
        echo
        ${pkgs.ffmpeg}/bin/ffprobe -v error \
          -show_entries format=duration,size,bit_rate,format_name \
          -show_entries stream=codec_type,codec_name,width,height,avg_frame_rate,bit_rate,sample_rate,channels \
          -of default=noprint_wrappers=1 "$file" \
          | ${pkgs.gawk}/bin/awk -F= '
            /^\[/ { next }
            {
              k = $1; v = $2
              if (k == "codec_name") { codec = v; next }
              if (k == "codec_type") {
                sec = (v == "video") ? "Video" : (v == "audio") ? "Audio" : v
                print "\n== " sec " =="
                if (codec != "") print "Codec:        " codec
                codec = ""
                next
              }
              if (k == "width") printf "Resolucion:   %s x ", v
              else if (k == "height") print v
              else if (k == "avg_frame_rate") {
                split(v, fr, "/")
                if (fr[2] > 0 && fr[1] > 0) printf "FPS:          %.3f\n", fr[1] / fr[2]
              }
              else if (k == "bit_rate") printf "Bitrate:      %.0f kbps\n", v / 1000
              else if (k == "duration") { d = v + 0; printf "Duracion:     %d:%02d\n", int(d / 60), int(d % 60) }
              else if (k == "size") printf "Tamano:       %.1f MB\n", v / 1048576
              else if (k == "format_name") print "Contenedor:   " v
              else if (k == "sample_rate") print "Sample rate:  " v " Hz"
              else if (k == "channels") print "Canales:      " v
            }'
      } > "$out"
      ${pkgs.kdePackages.kdialog}/bin/kdialog --title "Metadatos del archivo" --geometry 720x520 --textbox "$out"
    '')
  ];

  # Click derecho en Dolphin -> "Ver metadatos (fps, bitrate, codec)".
  xdg.dataFile."kio/servicemenus/ver-metadatos.desktop".text = ''
    [Desktop Entry]
    Type=Service
    ServiceTypes=KonqPopupMenu/Plugin
    MimeType=video/*;audio/*;image/*;
    Actions=VerMetadatos

    [Desktop Action VerMetadatos]
    Name=Ver metadatos (fps, bitrate, codec)
    Icon=document-properties
    Exec=ver-metadatos %f
  '';
}
