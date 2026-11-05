# Dos chimes distintos para identificar de que harness viene la notificacion.
# Uno por harness, generados con la stdlib de Python (no se commitean binarios).
# Timbre de marimba (fundamental + 4o parcial, decay rapido) y pico normalizado
# al 100%: se escucha parejo aunque el sink del sistema este bajo.
#   opencode  C6 -> G6, quinta ascendente brillante
#   dsh       E5 -> B5, quinta ascendente mas calida y grave
{ pkgs }:
let
  render = name: notes: pkgs.runCommand "chime-${name}.wav" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 - "$out" ${builtins.toString notes} <<'PY'
import math, struct, sys, wave

path = sys.argv[1]
notes = [tuple(float(x) for x in part.split(",")) for part in sys.argv[2:]]
rate = 44100
peak = 0.99
total = max(start + dur for _, start, dur in notes) + 0.06
samples = [0.0] * int(rate * total)

for freq, start, dur in notes:
    first = int(rate * start)
    for i in range(int(rate * dur)):
        t = i / rate
        attack = min(1.0, t / 0.004)
        decay = math.exp(-t * 7.0 / dur)
        # marimba: el 4o parcial entra fuerte y muere antes que la fundamental
        tone = (
            math.sin(2.0 * math.pi * freq * t)
            + 0.30 * math.sin(2.0 * math.pi * freq * 2.0 * t) * math.exp(-t * 9.0 / dur)
            + 0.22 * math.sin(2.0 * math.pi * freq * 4.0 * t) * math.exp(-t * 14.0 / dur)
        )
        samples[first + i] += tone * attack * decay

# Normaliza al pico pedido: sin esto el volumen depende de cuantas notas se sumen.
loudest = max(abs(value) for value in samples) or 1.0
gain = peak / loudest

with wave.open(path, "w") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(rate)
    for value in samples:
        clipped = max(-1.0, min(1.0, value * gain))
        wav.writeframes(struct.pack("<h", int(clipped * 32767)))
PY
  '';
in
{
  opencode = render "opencode" [ "1046.5,0,0.16" "1568.0,0.09,0.24" ];
  dsh = render "dsh" [ "659.25,0,0.20" "987.77,0.11,0.30" ];
}
