# Dos chimes distintos para identificar de que harness viene la notificacion.
# Uno por harness, generados con la stdlib de Python (no se commitean binarios):
#   opencode  ascendente, brillante  (C6 -> G6)
#   dsh       descendente, mas suave (E6 -> A5 -> E5)
{ pkgs }:
let
  render = name: notes: pkgs.runCommand "chime-${name}.wav" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 - "$out" ${builtins.toString notes} <<'PY'
import math, struct, sys, wave

path = sys.argv[1]
notes = [tuple(float(x) for x in part.split(",")) for part in sys.argv[2:]]
rate = 44100
total = max(start + dur for _, start, dur in notes) + 0.05
samples = [0.0] * int(rate * total)

for freq, start, dur in notes:
    first = int(rate * start)
    for i in range(int(rate * dur)):
        t = i / rate
        attack = min(1.0, t / 0.006)
        decay = math.exp(-t * 6.0 / dur)
        tone = (
            math.sin(2.0 * math.pi * freq * t)
            + 0.35 * math.sin(2.0 * math.pi * freq * 2.0 * t)
            + 0.12 * math.sin(2.0 * math.pi * freq * 3.0 * t)
        )
        samples[first + i] += 0.30 * tone * attack * decay

with wave.open(path, "w") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(rate)
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        wav.writeframes(struct.pack("<h", int(clipped * 32767)))
PY
  '';
in
{
  opencode = render "opencode" [ "1046.5,0,0.18" "1568.0,0.10,0.22" ];
  dsh = render "dsh" [ "1318.5,0,0.16" "880.0,0.10,0.18" "659.25,0.20,0.26" ];
}
