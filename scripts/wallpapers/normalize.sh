#!/usr/bin/env bash
# Normaliza un video de wallpaper al contrato de assets/wallpapers:
# 1920x1080, 24 fps, HEVC 8-bit bt709, sin audio, loop sin salto.
#
# Pipeline: ventana con el corte más parecido -> crossfade de 0.5 s en el
# empalme -> Real-ESRGAN x2 (2160p) -> Lanczos a 1080p -> x265 CRF 20.
# La IA limpia macrobloques y devuelve detalle; el downscale deja el archivo
# barato de decodificar (1080p) con la calidad percibida de un 4K.
#
# Uso: normalize.sh <entrada> <salida> [--start SEG] [--duration SEG]
set -euo pipefail

readonly FPS=24 WIDTH=1920 HEIGHT=1080 CRF=20
readonly MODEL=realesr-animevideov3 WINDOW=16 BLEND=0.5

usage() {
  echo "uso: $0 <entrada> <salida> [--start SEG] [--duration SEG]" >&2
  exit 2
}

[[ $# -ge 2 ]] || usage
in=$1 out=$2
shift 2
start="" duration=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --start) start=$2; shift 2 ;;
    --duration) duration=$2; shift 2 ;;
    *) usage ;;
  esac
done

for bin in ffmpeg ffprobe realesrgan-ncnn-vulkan python3; do
  command -v "$bin" >/dev/null || { echo "falta $bin" >&2; exit 1; }
done
[[ -f $in ]] || { echo "no existe: $in" >&2; exit 1; }
mkdir -p "$(dirname "$out")"

src_dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$in")
src_v=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 "$in")
read -r src_w src_h _ <<<"${src_v//,/ }"
echo "== $(basename "$in") -> $(basename "$out")  (${src_w}x${src_h}, ${src_dur}s)"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/wallpaper.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/frames" "$tmp/up"

# Elige el segundo de arranque con el corte más parecido (2 fps, 32x18 gris).
# No busca el loop perfecto: el crossfade tapa el empalme; esto solo evita
# arrancar en un fundido a negro o en un plano que no vuelve.
pick_start() {
  ffmpeg -v error -i "$in" -an -vf "fps=2,scale=32:18:flags=area,format=gray" \
    -f rawvideo -y "$tmp/thumbs.gray"
  python3 - "$tmp/thumbs.gray" "$1" <<'PY'
import sys
raw = open(sys.argv[1], "rb").read()
size, want = 32 * 18, int(round(float(sys.argv[2]) * 2))
frames = len(raw) // size
if frames <= want + 1:
    print("0 0")
else:
    def diff(i, j):
        a = raw[i * size:(i + 1) * size]
        b = raw[j * size:(j + 1) * size]
        return sum(abs(x - y) for x, y in zip(a, b)) / size
    best = min(((diff(i, i + want), i) for i in range(frames - want)))
    print(f"{best[1] / 2:.1f} {best[0]:.2f}")
PY
}

if [[ -z $duration ]]; then
  duration=$(awk -v d="$src_dur" -v w="$WINDOW" 'BEGIN{print (d < w + 1) ? d : w}')
fi
if [[ -z $start ]]; then
  read -r start _ <<<"$(pick_start "$duration")"
fi
# Clamp: la ventana no puede pasarse del final.
start=$(awk -v s="$start" -v d="$duration" -v t="$src_dur" \
  'BEGIN{print (s + d > t) ? (t - d > 0 ? t - d : 0) : s}')
offset=$(awk -v d="$duration" -v x="$BLEND" 'BEGIN{print d - 2 * x}')

echo "-- ventana ${start}s + ${duration}s, crossfade ${BLEND}s"

echo "-- frames (24 fps + loop)"
t0=$(date +%s)
ffmpeg -v error -ss "$start" -t "$duration" -i "$in" -filter_complex "
  [0:v]fps=$FPS,scale=$WIDTH:$HEIGHT:flags=lanczos,setsar=1,split=2[main][head];
  [main]trim=start=$BLEND,setpts=PTS-STARTPTS[a];
  [head]trim=start=0:end=$BLEND,setpts=PTS-STARTPTS[b];
  [a][b]xfade=transition=fade:duration=$BLEND:offset=${offset}[v]
" -map "[v]" -start_number 0 -y "$tmp/frames/%05d.png"
frames=$(find "$tmp/frames" -name '*.png' | wc -l)
echo "   $frames frames en $(( $(date +%s) - t0 ))s"

echo "-- Real-ESRGAN $MODEL x2 (2160p)"
t0=$(date +%s)
realesrgan-ncnn-vulkan -i "$tmp/frames" -o "$tmp/up" -n "$MODEL" -s 2 -j 4:6:4 >/dev/null 2>&1
echo "   listo en $(( $(date +%s) - t0 ))s"

echo "-- x265 CRF $CRF + Lanczos a ${WIDTH}x${HEIGHT}"
t0=$(date +%s)
# Se codifica a $tmp y se mueve al final: si el encode muere, el asset viejo
# queda intacto (ffmpeg con -y trunca el destino al arrancar).
ffmpeg -v error -framerate "$FPS" -i "$tmp/up/%05d.png" \
  -vf "scale=$WIDTH:$HEIGHT:flags=lanczos,format=yuv420p" \
  -c:v libx265 -preset slow -crf "$CRF" \
  -x265-params "log-level=error:colorprim=bt709:transfer=bt709:colormatrix=bt709" \
  -colorspace bt709 -color_primaries bt709 -color_trc bt709 \
  -an -map_metadata -1 -movflags +faststart -tag:v hvc1 -y "$tmp/final.mp4"
codec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$tmp/final.mp4")
[[ $codec == hevc ]] || { echo "la salida no es HEVC ($codec)" >&2; exit 1; }
mv -f "$tmp/final.mp4" "$out"
echo "   listo en $(( $(date +%s) - t0 ))s"

echo "== ok: $(du -h "$out" | cut -f1)  $(ffprobe -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,r_frame_rate -show_entries format=duration \
  -of csv=p=0 "$out" | tr '\n' ' ')"
