# Mide la zona muerta del panel (barra negra inferior + líneas) desde una captura PPM.
# Uso: registro.py captura.ppm  →  imprime "barra_px;barra_pct;oscura_px;oscura_pct"
import sys

data = open(sys.argv[1], "rb").read()

# Cabecera P6: "P6 <ancho> <alto> <maxval>" + RGB crudo
tokens, i = [], 0
while len(tokens) < 4:
    c = data[i:i + 1]
    if c.isspace():
        i += 1
    elif c == b"#":
        while data[i:i + 1] != b"\n":
            i += 1
    else:
        j = i
        while not data[j:j + 1].isspace():
            j += 1
        tokens.append(data[i:j])
        i = j
w, h = int(tokens[1]), int(tokens[2])
px = data[i + 1:]  # saltar el ÚNICO whitespace tras maxval

stride = w * 3
# ponytail: umbrales fijos calibrados a ojo (negro real + líneas tenues); si la
# medición deja de cuadrar con lo visible, subir BARRA_MAX o bajar OSCURA_MEDIA.
BARRA_MAX = 32      # fila muerta: ni un solo pixel por encima
OSCURA_MEDIA = 40   # fila oscura: media baja (negro + líneas verdes tenues)


def filas_desde_abajo(pred):
    n = 0
    for r in range(h - 1, -1, -1):
        fila = px[r * stride:(r + 1) * stride]
        if not pred(fila):
            break
        n += 1
    return n


barra = filas_desde_abajo(lambda f: max(f) <= BARRA_MAX)
oscura = filas_desde_abajo(lambda f: sum(f) / len(f) <= OSCURA_MEDIA)
print(f"{barra};{100 * barra / h:.1f};{oscura};{100 * oscura / h:.1f}")
