#!/usr/bin/env python3
"""PDF -> Markdown para meter en contexto (LLM / RAG / lectura).

Lee la capa de texto con pymupdf (CPU, sin modelos ni OCR) y reconstruye la
estructura desde la geometria: tamano de fuente, negrita, posicion vertical.
Eso es lo que un extractor de texto plano no da y lo que hace falta para unir
las frases que el PDF corta en cada renglon.

No usa pymupdf4llm: su deteccion de listas inventa viñetas sobre renglones que
solo empiezan con "o " (y se come la letra), y fusiona un item con el parrafo
siguiente. Verificado sobre PIGNUS.pdf (3 "o" perdidos, 3 viñetas falsas).

Avisa por stderr las paginas sin texto extraible, y no escribe nada si la
mayoria estan asi (escaneo sin OCR): un markdown incompleto como contexto es
peor que ninguno.
"""
import argparse
import collections
import pathlib
import re
import sys

import pymupdf

END = re.compile(r"[.:;!?]$")            # cierra frase
LIST = re.compile(r"^([a-z]\)|[IVXLC]+\.|\d+[.)])\s")
BULLET = re.compile(r"^[•·]\s*$")
MAX_BLANK = 0.5                          # mas que esto = escaneo, no se escribe nada


def lines_of(page):
    """Renglones de la pagina, ordenados, con tamano y negrita."""
    out = []
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            spans = [s for s in line["spans"] if s["text"].strip()]
            if spans:
                out.append({
                    "y": line["bbox"][1],
                    "txt": "".join(s["text"] for s in spans).strip(),
                    "size": max(round(s["size"], 1) for s in spans),
                    "bold": all(s["flags"] & 16 for s in spans),
                })
    return sorted(out, key=lambda i: i["y"])


def page_pitch(its):
    """Paso de linea dominante: el gap mas comun entre renglones seguidos."""
    gaps = collections.Counter()
    for a, b in zip(its, its[1:]):
        gap = round(b["y"] - a["y"], 1)
        if 0 < gap < 100:
            gaps[gap] += 1
    return gaps.most_common(1)[0][0] if gaps else 0.0


def convert(doc):
    """Devuelve (markdown, paginas_sin_texto)."""
    pages = []
    blanks, sizes = [], collections.Counter()
    for n, page in enumerate(doc):
        its = [i for i in lines_of(page) if not BULLET.match(i["txt"])]
        # Sin NADA de texto extraible no hay capa de texto. No se usa un minimo
        # de caracteres: una portada o un separador de capitulo son cortos y
        # legitimos, y marcarlos como "escaneo" seria mentir.
        if not its:
            blanks.append(n + 1)
        for i in its:
            sizes[i["size"]] += len(i["txt"])
        pages.append(its)
    body = sizes.most_common(1)[0][0] if sizes else 12.0

    blocks = []  # (kind, texto); kind es "head" o "body"
    prev = None
    for its in pages:
        pitch = page_pitch(its)
        for n, it in enumerate(its):
            txt = it["txt"]
            gap = it["y"] - its[n - 1]["y"] if n else 999.0
            head = it["size"] > body + 0.5 or (
                it["bold"]
                and not END.search(txt)
                and (prev is None or END.search(prev) or blocks[-1][0] == "head")
            )
            join = (
                not head
                and prev is not None
                and not END.search(prev)
                and 0 < gap < pitch * 1.25
                and not LIST.match(txt)
                and blocks
                and blocks[-1][0] == "body"
            )
            if head:
                blocks.append(("head", txt))
            elif join:
                blocks[-1] = ("body", blocks[-1][1] + " " + txt)
            else:
                blocks.append(("body", txt))
            prev = txt
    md = "".join(f"\n## {t}\n" if k == "head" else f"\n{t}\n" for k, t in blocks)
    return re.sub(r"\n{3,}", "\n\n", md).strip() + "\n", blanks


def main():
    ap = argparse.ArgumentParser(
        prog="pdf2md",
        description="Convierte PDF a Markdown (capa de texto, sin OCR) para dar contexto a un LLM.",
        epilog="Sin -o escribe <archivo>.md al lado de cada PDF. Con -o acepta un solo PDF; "
        "-o - escribe a stdout.",
    )
    ap.add_argument("pdfs", nargs="+", metavar="PDF")
    ap.add_argument("-o", "--output", help="archivo de salida (o - para stdout)")
    args = ap.parse_args()

    if args.output and len(args.pdfs) > 1:
        ap.error("-o acepta un solo PDF; con varios se escribe <archivo>.md al lado de cada uno")

    failed = 0
    for name in args.pdfs:
        src = pathlib.Path(name)
        if not src.is_file():
            ap.error(f"no existe: {src}")
        with pymupdf.open(src) as doc:
            total = doc.page_count
            md, blanks = convert(doc)
        if blanks and len(blanks) / total > MAX_BLANK:
            print(
                f"pdf2md: {src.name}: {len(blanks)} de {total} paginas sin texto "
                f"extraible. Parece un escaneo y hace falta OCR; no escribo nada "
                f"(un markdown incompleto como contexto es peor que ninguno).",
                file=sys.stderr,
            )
            failed += 1
            continue
        if blanks:
            shown = ", ".join(map(str, blanks[:8])) + ("..." if len(blanks) > 8 else "")
            print(
                f"pdf2md: aviso: {len(blanks)} de {total} pagina(s) sin texto "
                f"extraible en {src.name} ({shown}); quedan fuera del markdown.",
                file=sys.stderr,
            )
        if args.output == "-":
            sys.stdout.write(md)
            continue
        dest = pathlib.Path(args.output) if args.output else src.with_suffix(".md")
        dest.write_text(md, encoding="utf-8")
        print(f"{src} -> {dest} ({len(md)} chars)", file=sys.stderr)

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
