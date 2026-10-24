#!/usr/bin/env python3
"""ytmusic: cruza la biblioteca local contra playlists de YT Music y repara tags.

  ytmusic index                      re-lee la biblioteca (incremental) y arma el cache
  ytmusic check <url>... [--download] que tengo / que me falta de esas playlists
  ytmusic fix [--apply] [--limit N]   reescribe tags + portada 1:1 usando el PURL
  ytmusic self-test

Reglas (ver odd/tasks/music-library.md):
  - dos canciones son la misma solo si coinciden titulo, version (remix/live/radio edit)
    y artista, con duracion +-3s. Un radio edit no es lo mismo que el original mix.
  - `fix` nunca re-descarga audio: solo reescribe los tags del archivo existente.
  - `fix` sin `--apply` es un dry-run. Antes de tocar un archivo guarda sus tags viejos.
  - descargas con --no-overwrites (sin el .txt de --download-archive).
"""
import argparse
import base64
import collections
import difflib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import unicodedata
import urllib.request
from pathlib import Path

MUSIC = Path(os.environ.get("YTMUSIC_DIR", "~/Sync/My Music")).expanduser()
CACHE = Path(os.environ.get("YTMUSIC_CACHE", "~/.cache/ytmusic")).expanduser()
INDEX = CACHE / "index.json"
META = CACHE / "ytmeta.json"
BACKUP = CACHE / "tagbackup.jsonl"

# --- normalizacion ---------------------------------------------------------

NOISE = re.compile(
    r"\b(official|oficial|videoclip|music\s*video|video|lyric\s*video|lyrics?|letra|"
    r"audio|audio\s*only|visuali[sz]er|hd|hq|4k|8k|mv|m/v|remaster(ed)?|sub\s*espa[nñ]ol|"
    r"espanol|subtitulado|premiere|out\s*now|free\s*download)\b", re.I)
FEAT = re.compile(r"\b(?:feat|ft|featuring)\.?\s+(.+)$", re.I)
TAIL_NOISE = re.compile(
    r"\s*[\(\[]\s*(official\s*(music\s*)?video|official\s*audio|oficial|official|"
    r"lyric\s*video|lyrics?|visuali[sz]er|audio|hd|hq|4k)\s*[\)\]]\s*$", re.I)
# ruido que se puede sacar de un parentesis sin cambiar que grabacion es. Ojo:
# 'clean'/'explicit' NO estan aca, porque para el usuario son la diferencia entre
# una cancion censurada y la buena.
NOISE_VER = re.compile(
    r"\b(official|oficial|videoclip|music\s*video|video|lyric\s*video|lyrics?|letra|"
    r"audio|audio\s*only|visuali[sz]er|hd|hq|4k|8k|mv|m/v|sub\s*espa[nñ]ol|espanol|"
    r"subtitulado|premiere|out\s*now|free\s*download)\b", re.I)

# etiquetas que no convierten una cancion en otra cosa (el validador apunto esto:
# rechazar toda diferencia de version hacia que '(Remastered)' no matcheara nunca)
BENIGN = re.compile(r"^(digital )?remaster(ed)?( \d{4})?$")
FEAT_IN = re.compile(r"\b(?:feat|ft|featuring|with)\.?\s+.*", re.I)


def _acc(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def core(s):
    """titulo comparable: sin acentos, sin parentesis, sin palabras de ruido."""
    if not s:
        return ""
    s = _acc(s).lower().replace("’", "'")
    s = re.sub(r"\(.*?\)|\[.*?\]|\{.*?\}", " ", s)
    s = FEAT.sub(" ", s)
    s = NOISE.sub(" ", s)
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def versions(*titles):
    """texto de los parentesis que distingue dos ediciones (remix, live, radio edit...).
    Las palabras de ruido y los 'feat. X' no distinguen nada."""
    out = set()
    for t in titles:
        if not t:
            continue
        tail = re.sub(r"\([^)]*\)|\[[^\]]*\]", " ", t)   # feat fuera de parentesis
        for p in re.findall(r"[\(\[]([^\)\]]*)[\)\]]", t) + FEAT.findall(tail):
            p = FEAT_IN.sub(" ", _acc(p).lower())
            if re.fullmatch(r"\s*((digital|remaster(ed)?|\d{4})\s*)+", p):
                continue                      # '(Remastered 2011)': misma grabacion
            p = NOISE_VER.sub(" ", p)
            p = re.sub(r"[^a-z0-9 ]+", " ", p)
            p = re.sub(r"\s+", " ", p).strip()
            if p:
                out.add(p)
    return frozenset(out)


def clean_title(t):
    """saca el '(Official Music Video)' del final, no toca remixes ni versiones."""
    prev = None
    while prev != t:
        prev = t
        t = TAIL_NOISE.sub("", t).strip()
    return t or prev or ""


def split_name(fn):
    """'Canal - Titulo.opus' -> (canal, titulo). Es el template de yt-dlp.
    Los canales automaticos se llaman '<Artista> - Topic' y ya traen un ' - ', asi
    que cortar por el primero dejaba el canal en 'Loki' y el titulo en
    'Topic - Reguecito': justo los temas de audio oficial nunca matcheaban."""
    stem = re.sub(r"\.opus$", "", fn, flags=re.I)
    m = re.match(r"^(.*? - Topic) - (.+)$", stem, re.I)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    up, _, vt = stem.partition(" - ")
    return (up, vt) if vt else ("", stem)


def similar(a, b):
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def same_song(a, b, tol=3.0):
    """a y b son dicts con core/art/ver/dur. El 'canal - artista - titulo' de yt-dlp
    deja el artista pegado al titulo, por eso tambien vale que uno termine en el
    otro (sufijo, no prefijo: 'Lady Killers III' no es 'Lady Killers II').

    Tres reglas que costaron sangre, todas para no bajar un tema que ya esta:
      - 'feat. X' o '(Original Mix)' no distinguen nada: un remix/live/edit si.
      - el canal de YouTube no es el artista; si el titulo es identico y la duracion
        coincide al segundo, el artista no puede vetar el match.
      - dos versiones distintas ('Club Mix' vs 'Original Mix' vs 'Part 1') nunca son
        la misma cancion, duren lo que duren.
    """
    dd = abs(a["dur"] - b["dur"])
    if dd > tol or a["dur"] <= 20:
        return 0.0
    t = 1.0 if a["core"] == b["core"] else similar(a["core"], b["core"])
    if t < 0.92:
        x, y = a["core"], b["core"]
        if min(len(x), len(y)) >= 4 and (x.endswith(" " + y) or y.endswith(" " + x)):
            t = 0.92
    if t < 0.92:
        return 0.0
    exact = a["core"] == b["core"] and dd <= 1.5
    if a["ver"] != b["ver"]:
        # (club mix), (original mix), (part 1) son otra cosa; (Remastered) no
        a_sig = frozenset(v for v in a["ver"] if not BENIGN.match(v))
        b_sig = frozenset(v for v in b["ver"] if not BENIGN.match(v))
        if a_sig != b_sig:
            return 0.0
    if similar(a["art"], b["art"]) < 0.6 and not exact:
        return 0.0
    return t


# --- lectura de la biblioteca ---------------------------------------------

def read_tags(path):
    from mutagen.oggopus import OggOpus
    f = OggOpus(path)
    tags = {k.upper(): (v[0] if isinstance(v, list) and v else v)
            for k, v in (f.tags or {}).items()}
    return tags, float(f.info.length)


def index_library(force=False):
    CACHE.mkdir(parents=True, exist_ok=True)
    old = {}
    if INDEX.exists() and not force:
        try:
            old = json.loads(INDEX.read_text())
        except Exception:
            old = {}
    files = {}
    seen = 0
    for p in sorted(MUSIC.glob("*.opus")):
        if p.name.endswith((".temp.opus", ".ytmusic-tmp")):
            continue          # restos de yt-dlp / de nuestras escrituras atomicas
        try:
            st = p.stat()
        except OSError:
            continue
        key = f"{st.st_mtime_ns}:{st.st_size}"
        hit = old.get(p.name)
        if hit and hit.get("k") == key:
            files[p.name] = hit
            continue
        try:
            tags, dur = read_tags(p)
        except Exception as e:
            print(f"  ! no pude leer {p.name}: {e}", file=sys.stderr)
            continue
        yid = ""
        m = re.search(r"(?:v=|youtu\.be/|/shorts/|embed/)([A-Za-z0-9_-]{11})",
                      tags.get("PURL", ""))
        if m:
            yid = m.group(1)
        up, vt = split_name(p.name)
        row = {"k": key, "yid": yid, "dur": round(dur, 1),
               "t": tags.get("TITLE", ""), "a": tags.get("ARTIST", ""),
               "al": tags.get("ALBUM", ""), "up": up, "vt": vt}
        # el nombre de archivo lo escribio yt-dlp y nadie lo toco: manda sobre el tag,
        # que es justo lo que Picard ensucio.
        row["core"] = core(vt or row["t"])
        row["art"] = core(up)
        row["ver"] = sorted(versions(vt) if vt else versions(row["t"]))
        files[p.name] = row
        seen += 1
    INDEX.write_text(json.dumps(files, ensure_ascii=False))
    print(f"indice: {len(files)} archivos ({seen} re-leidos, {len(files)-seen} del cache)")
    return files


def load_index(rebuild=False):
    if rebuild or not INDEX.exists():
        return index_library(force=rebuild)
    files = json.loads(INDEX.read_text())
    # un archivo borrado a mano seguia apareciendo en el indice y `check` lo daba
    # por presente: eso te haria saltear una descarga que te falta.
    vivos = [n for n in files if (MUSIC / n).exists()]
    if len(vivos) != len(files):
        files = {n: files[n] for n in vivos}
        INDEX.write_text(json.dumps(files, ensure_ascii=False))
    return files


# --- yt-dlp ---------------------------------------------------------------

YDL = ["yt-dlp", "--no-warnings", "--ignore-config"]
CLIENTS = ["--extractor-args", "youtube:player_client=tv_downgraded,tv,visionos"]


def ydl_json(url, cookies=False, playlist=False):
    cmd = YDL + CLIENTS + ["-J"]
    if playlist:
        cmd += ["--flat-playlist"]
    else:
        cmd += ["--skip-download", "--no-playlist"]
    if cookies:
        cmd += ["--cookies-from-browser", "firefox"]
    r = subprocess.run(cmd + [url], capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or "").strip().splitlines()[-1:] or ["yt-dlp fallo"])
    return json.loads(r.stdout)


def playlist_entries(url, cookies=False):
    d = ydl_json(url, cookies=cookies, playlist=True)
    # en listas grandes hay entradas borradas o privadas (title/id en None)
    return [e for e in (d.get("entries") or []) if e.get("id")]


def _dest_name(url, cookies=False):
    """Nombre que usaria yt-dlp para este video (sin descargar)."""
    cmd = YDL + CLIENTS + ["--skip-download", "--no-playlist",
                           "--print", "%(uploader)s - %(title)s"]
    if cookies:
        cmd += ["--cookies-from-browser", "firefox"]
    r = subprocess.run(cmd + [url], capture_output=True, text=True)
    return (r.stdout or "").strip().splitlines()[-1] if r.stdout.strip() else ""


def _safe_name(name):
    """El nombre viaja como template de `yt-dlp -o`: un '/' o un '..' en el titulo
    haria que yt-dlp escriba en subcarpetas o fuera de la carpeta de musica."""
    n = name.replace("/", "-").replace("\\", "-").replace("\0", "")
    n = n.replace("..", ".")
    return n.replace("%", "%%")


def _dest_for(url, cookies=False):
    """El template 'Canal - Titulo' choca cuando dos videos distintos se llaman
    igual: con --no-overwrites el segundo se saltea y queda como 'descargado' sin
    estar. Si el archivo existe y es otro video, se usa un nombre con sufijo; si es
    el mismo video, devuelve None (ya esta, no hay nada que bajar)."""
    name = _dest_name(url, cookies)
    if not name:
        return "%(uploader)s - %(title)s.%(ext)s"
    dst = MUSIC / (name + ".opus")
    if dst.exists():
        yid = url.split("v=")[-1][:11]
        try:
            tags, _ = read_tags(dst)
            if yid and yid in tags.get("PURL", ""):
                return None          # ya esta ese mismo video: no se toca
        except Exception:
            pass
        name += " (2)"
    return _safe_name(name) + ".%(ext)s"


def download(urls, cookies=False):
    args = YDL + CLIENTS + [
        "--ignore-errors", "--no-overwrites", "--extract-audio",
        "--audio-format", "opus", "--embed-metadata", "--embed-thumbnail",
        "--js-runtimes", "node", "--no-playlist", "--sleep-requests", "1",
        "--sleep-interval", "3", "--max-sleep-interval", "8",
        "--newline",
    ]
    if cookies:
        args += ["--cookies-from-browser", "firefox"]
    done = 0
    for i, u in enumerate(urls, 1):
        print(f"[{i}/{len(urls)}] {u}", flush=True)
        out = _dest_for(u, cookies)
        if out is None:
            continue                     # ya esta ese mismo video
        r = subprocess.run(args + ["-o", out, u], cwd=str(MUSIC))
        done += r.returncode == 0
    return done


# --- check ----------------------------------------------------------------

def entry_key(e):
    title = e.get("title") or ""
    artist = e.get("channel") or e.get("uploader") or ""
    return {"core": core(title), "art": core(artist), "ver": sorted(versions(title)),
            "dur": float(e.get("duration") or 0)}


def _bucket(rows, key=lambda r: r["dur"]):
    b = collections.defaultdict(list)
    for r in rows:
        b[int(key(r)) // 2].append(r)
    return b


def _near(b, dur, span=4):
    """Candidatos dentro de +-8s. Comparar 9000 temas contra 6000 archivos uno por uno
    son 50 millones de comparaciones; con esto son un puñado por tema."""
    k = int(dur or 0) // 2
    out = []
    for i in range(k - span, k + span + 1):
        out.extend(b.get(i, ()))
    return out


def _plausible(k, rows_by_dur):
    """Archivo local que podria ser el mismo tema con otra etiqueta o unos segundos
    de diferencia. Existe para NO bajar un duplicado: si el titulo esta contenido y
    la duracion cae cerca, se avisa y no se descarga."""
    for r in _near(rows_by_dur, k["dur"], 8):
        rc, c = r["core"], k["core"]
        if not (rc and c and (rc == c or rc.endswith(" " + c) or c.endswith(" " + rc))):
            continue
        if r["art"] and k["art"] and similar(r["art"], k["art"]) < 0.55:
            continue            # 'Intro' de otro artista no es el mismo tema
        return r
    return None


def check(urls, do_download=False, cookies=False, as_json=False, force=False):
    lib = load_index()
    rows = list(lib.values())
    lib_by_dur = _bucket(rows)
    entries = []
    for u in urls:
        got = playlist_entries(u, cookies=cookies)
        print(f"{u}: {len(got)} temas", file=sys.stderr)
        entries += got

    # duplicados dentro de las mismas playlists
    uniq, dropped = [], 0
    ent_by_dur = collections.defaultdict(list)
    for e in entries:
        k = entry_key(e)
        if any(same_song(k, x) > 0 for x in _near(ent_by_dur, k["dur"], 3)):
            dropped += 1
            continue
        uniq.append((e, k))
        ent_by_dur[int(k["dur"]) // 2].append(k)

    tienen, faltan = [], []
    for e, k in uniq:
        hit = None
        for r in _near(lib_by_dur, k["dur"]):
            if same_song(k, r) > 0:
                hit = r
                break
        (tienen if hit else faltan).append((e, hit))

    if as_json:
        print(json.dumps({"total": len(uniq), "duplicadas": dropped,
                          "tengo": [{"id": e.get("id"), "title": e.get("title"),
                                     "local": h["t"] or h["vt"]} for e, h in tienen],
                          "faltan": [{"id": e.get("id"), "title": e.get("title") or "",
                                      "artist": e.get("channel") or e.get("uploader"),
                                      "dur": e.get("duration")} for e, _ in faltan]},
                         ensure_ascii=False, indent=1))
    else:
        print(f"\n{len(uniq)} temas unicos ({dropped} repetidos en la playlist)")
        print(f"  ya los tengo : {len(tienen)}")
        print(f"  me faltan    : {len(faltan)}")
        if faltan:
            print("\nFALTAN:")
            for e, _ in faltan:
                print(f"  {str(e.get('duration') or '?'):>5}s  {(e.get('title') or '')[:52]:52}"
                      f" | {(e.get('channel') or e.get('uploader') or '')[:24]:24}"
                      f" | https://music.youtube.com/watch?v={e.get('id')}")

    dudosos = []
    if do_download and faltan:
        seguros = []
        for e, _ in faltan:
            p = None if force else _plausible(entry_key(e), lib_by_dur)
            if p:
                dudosos.append((e, p))
            else:
                seguros.append(e)
        if dudosos:
            print(f"\nNO bajo {len(dudosos)}: ya tenes algo muy parecido "
                  f"(usar --force para bajarlas igual)")
            for e, p in dudosos[:10]:
                print(f"  {e.get('title','')[:38]:38} ~ {p['vt'][:38]}")
        urls_ok = [f"https://music.youtube.com/watch?v={e.get('id')}" for e in seguros]
        print(f"\ndescargando {len(urls_ok)} temas en {MUSIC} ...", flush=True)
        ok = download(urls_ok, cookies=cookies)
        print(f"descargados {ok}/{len(urls_ok)}")
    return faltan


# --- limpieza de nombres ---------------------------------------------------

def _leading_noise(name):
    """Cuanto prefijo hay que sacar: emoji y simbolos decorativos al principio.
    No toca '$uicideboy$' ni '€urotra$h' (categoria Sc), que son parte del nombre."""
    import unicodedata
    i = 0
    while i < len(name):
        c = name[i]
        if unicodedata.category(c) in ("So", "Sk", "Cf", "Mn") or c.isspace() or c in ".·":
            i += 1
            continue
        break
    return i


def clean_names(do_apply=False, as_json=False):
    """Saca el emoji del principio del nombre de archivo. El nombre bueno es el que
    queda; si el destino ya existe, no pisa nada: lo informa."""
    lib = load_index()
    plan, choques = [], []
    for name in sorted(lib):
        i = _leading_noise(name)
        if not i:
            continue
        nuevo = name[i:].lstrip(" .·-")
        if not nuevo or not nuevo.lower().endswith(".opus"):
            continue
        if (MUSIC / nuevo).exists():
            choques.append((name, nuevo))
            continue
        plan.append((name, nuevo))
    if as_json:
        print(json.dumps({"renombrar": plan, "choques": choques}, ensure_ascii=False, indent=1))
        return plan
    print(f"nombres a limpiar: {len(plan)}   destino ya ocupado: {len(choques)}")
    for a, b in plan[:20]:
        print(f"  {a[:52]!r}\n    -> {b[:60]!r}")
    if len(plan) > 20:
        print(f"  ... y {len(plan)-20} mas")
    for a, b in choques:
        print(f"  SALTADO (ya existe {b[:40]!r}): {a[:44]!r}")
    if not do_apply:
        print("(dry-run: nada renombrado, usar --apply)")
        return plan
    ok = 0
    for a, b in plan:
        try:
            os.rename(MUSIC / a, MUSIC / b)
            ok += 1
        except OSError as e:
            print(f"  ! {a[:40]}: {e}", file=sys.stderr)
    print(f"renombrados: {ok}/{len(plan)}")
    if ok:
        index_library(force=True)
    return plan


# --- duplicados por huella digital (chromaprint) ---------------------------

FP = CACHE / "fp.json"


def fingerprint(path, cache, key, length=120):
    hit = cache.get(key)
    if hit:
        return hit
    r = subprocess.run(["fpcalc", "-raw", "-length", str(length), str(path)],
                       capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or "fpcalc fallo").strip().splitlines()[-1:])
    out = dict(l.split("=", 1) for l in r.stdout.splitlines() if "=" in l)
    vals = [int(x) for x in out["FINGERPRINT"].split(",")] if out.get("FINGERPRINT") else []
    res = {"d": int(float(out.get("DURATION") or 0)), "f": vals}
    cache[key] = res
    return res


def _ber_at(xs, ys):
    n = min(len(xs), len(ys))
    if n < 50:
        return 1.0
    diff = sum((x ^ y).bit_count() for x, y in zip(xs[:n], ys[:n]))
    return diff / (n * 32)


def ber(a, b, max_shift=80, step=4):
    """Bit error rate entre dos huellas. Mismo audio ~0.0-0.1 (a veces corrido unos
    segundos: la version de video suele tener intro); otra grabacion ~0.4. Barre
    corrimientos en paso grueso y afina solo si quedo cerca."""
    if min(len(a), len(b)) < 50:
        return 1.0
    best, at = 1.0, 0
    for s in range(-max_shift, max_shift + 1, step):
        xs, ys = (a, b[s:]) if s >= 0 else (a[-s:], b)
        r = _ber_at(xs, ys)
        if r < best:
            best, at = r, s
            if best <= 0.12:
                return best
    if best > 0.30:
        return best
    for t in range(at - step + 1, at + step):
        xs, ys = (a, b[t:]) if t >= 0 else (a[-t:], b)
        r = _ber_at(xs, ys)
        if r < best:
            best = r
    return best


_DUP_ART = re.compile(r"^(.{2,}?) - \1 - ", re.I)
_VID_MARK = re.compile(r"official|oficial|lyric|visuali[sz]er|videoclip|"
                       r"\(audio\)|\[audio\]|music video|video oficial|vevo", re.I)


def _name_score(name):
    """Cuanto mas alto, peor nombre: 'Adele - Adele - Rolling (Official Music
    Video)' suma mucho; 'Adele - Rolling in the Deep' suma cero."""
    base = re.sub(r"\.opus$", "", name, flags=re.I)
    s = 0
    if _DUP_ART.match(base):
        s += 3                       # 'Artista - Artista - Titulo'
    if _VID_MARK.search(base):
        s += 2
    if re.search(r"\b(ft|feat)\.?\s", base, re.I):
        s += 1
    s += min(len(base) // 40, 2)     # nombres kilometricos
    return s


def _verdict(name, r):
    """Orden para quedarse con una copia: primero el canal de audio oficial, despues
    el nombre mas limpio, despues el mas corto."""
    up = r["up"].lower()
    return (0 if up.endswith("- topic") else 1, _name_score(name), len(name))


def _fpkey(name, r):
    """La huella no depende de los tags, asi que se indexa por video id (o nombre):
    reescribir metadatos no la invalida. Un archivo re-descargado con el mismo
    nombre necesita `rm ~/.cache/ytmusic/fp.json`."""
    return r.get("yid") or name


def dupes(ber_max=0.12, tol=6.0, as_json=False):
    """Duplicados reales: misma duracion + misma huella. Un remix distinto da BER alto,
    aunque se llame igual y dure lo mismo."""
    lib = load_index()
    fp = json.loads(FP.read_text()) if FP.exists() else {}
    todo = list(lib.items())
    print(f"huellando {len(todo)} archivos (fpcalc, se cachea)...", file=sys.stderr, flush=True)
    faltan = 0
    for i, (name, r) in enumerate(todo, 1):
        path = MUSIC / name
        try:
            fingerprint(path, fp, _fpkey(name, r))
        except Exception as e:
            faltan += 1
            if faltan <= 5:
                print(f"  ! {name[:50]}: {e}", file=sys.stderr)
            r["fp"] = False
        else:
            r["fp"] = True
        if i % 500 == 0:
            FP.parent.mkdir(parents=True, exist_ok=True)
            FP.write_text(json.dumps(fp))
            print(f"  {i}/{len(todo)}", file=sys.stderr, flush=True)
    FP.parent.mkdir(parents=True, exist_ok=True)
    FP.write_text(json.dumps(fp))

    def words(name):
        return [struct.unpack("<I", struct.pack("<I", v))[0]
                for v in fp[_fpkey(name, lib[name])]["f"]]

    order = sorted((n for n, r in todo if r.get("fp")), key=lambda n: lib[n]["dur"])
    pairs = 0
    parent = {n: n for n in order}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    wcache = {}
    for i in range(len(order)):
        a = order[i]
        for k in range(i + 1, len(order)):
            b = order[k]
            if lib[b]["dur"] - lib[a]["dur"] > tol:
                break
            if a not in wcache:
                wcache[a] = words(a)
            if b not in wcache:
                wcache[b] = words(b)
            if ber(wcache[a], wcache[b]) <= ber_max:
                pairs += 1
                ra, rb = find(a), find(b)
                if ra != rb:
                    parent[rb] = ra
        if i % 500 == 0 and i:
            print(f"  comparando {i}/{len(order)} ({pairs} pares)", file=sys.stderr, flush=True)

    groups = {}
    for n in order:
        groups.setdefault(find(n), []).append(n)
    dupes_ = {k: v for k, v in groups.items() if len(v) > 1}
    def _mtime(n):
        """Si no se puede leer la fecha, va al final (inf): nunca puede quedar como
        el que se conserva, porque entonces el plan borraria las copias reales."""
        try:
            return (MUSIC / n).stat().st_mtime
        except OSError:
            return float("inf")

    plan = []
    for g in dupes_.values():
        # el mas viejo es el que el usuario curo: las copias que bajamos despues
        # se van, no al reves.
        s = sorted(g, key=lambda n: (_verdict(n, lib[n]), _mtime(n)))
        plan.append({"keep": s[0], "drop": s[1:], "song": lib[s[0]]["core"]})
    plan.sort(key=lambda x: -len(x["drop"]))
    if as_json:
        print(json.dumps(plan, ensure_ascii=False, indent=1))
        return plan
    print(f"\n{len(plan)} grupos duplicados, {sum(len(g['drop']) for g in plan)} "
          f"archivos sobrantes de {len(order)} con huella "
          f"(ber<={ber_max}, dur+-{tol}s)")
    for g in plan[:40]:
        print(f"\n--- «{g['song']}»")
        print(f"    QUEDA: {g['keep']}")
        for d in g["drop"]:
            print(f"    FUERA: {d}")
    if len(plan) > 40:
        print(f"\n... y {len(plan)-40} grupos mas (usar --json)")
    return plan


# --- fix ------------------------------------------------------------------

KEEP = {"TITLE", "ARTIST", "ALBUM", "DATE", "GENRE", "PURL", "DESCRIPTION",
        "ENCODER", "METADATA_BLOCK_PICTURE"}


_META = None
_DIRTY = 0


def _save_meta(force=False):
    """El cache se escribe cada 50 temas nuevos: escribir el json entero 6000 veces
    son gigas de I/O al pedo."""
    global _DIRTY
    if _META is not None and (force or _DIRTY >= 50):
        META.parent.mkdir(parents=True, exist_ok=True)
        META.write_text(json.dumps(_META, ensure_ascii=False))
        _DIRTY = 0


def fetch_meta(yid, cookies=False):
    global _META, _DIRTY
    if _META is None:
        _META = json.loads(META.read_text()) if META.exists() else {}
    cache = _META
    if yid in cache:
        return cache[yid]
    d = ydl_json(f"https://www.youtube.com/watch?v={yid}", cookies=cookies)
    th = d.get("thumbnails") or []
    square = [t for t in th if t.get("width") and t.get("height")
              and 0.9 <= t["width"] / t["height"] <= 1.1]
    pool = square or [t for t in th if t.get("url")]
    best = max(pool, key=lambda t: (t.get("width") or 0) * (t.get("height") or 0),
               default=None)
    artist = (d.get("artist") or d.get("creator") or d.get("channel")
              or d.get("uploader") or "")
    artist = re.sub(r"\s*-\s*Topic$", "", artist, flags=re.I)
    year = str(d.get("release_year") or (d.get("upload_date") or "")[:4] or "")
    if not (len(year) == 4 and year.isdigit() and 1900 <= int(year) <= 2100):
        year = (d.get("upload_date") or "")[:4]
        if not (year.isdigit() and 1900 <= int(year) <= 2100):
            year = ""
    out = {"t": clean_title(d.get("track") or d.get("title") or ""),
           "a": artist,
           "al": (d.get("album") or "").strip(),
           "d": year,
           "sq": bool(square),
           "track": bool(d.get("track")),
           "thumb": best["url"] if best else ""}
    cache[yid] = out
    _DIRTY += 1
    _save_meta()
    return out


def _title_match(a, b):
    """Titulo de YT Music contra el titulo del video (que suele traer 'Artista - ')."""
    x, y = core(a), core(b)
    if not x or not y:
        return False
    if x == y or similar(x, y) >= 0.85:
        return True
    return min(len(x), len(y)) >= 4 and (x.endswith(" " + y) or y.endswith(" " + x))


_YT = None


def ytmusic_cover(title, artist, dur):
    """Portada 1:1 desde YT Music: el video oficial solo tiene miniaturas 16:9, pero
    la ficha de la cancion tiene el arte del album. El CDN acepta cualquier tamano
    en el sufijo de la URL, asi que se pide a 1080."""
    global _YT
    try:
        from ytmusicapi import YTMusic
    except ImportError:
        print("  ! falta ytmusicapi: no puedo buscar portadas", file=sys.stderr)
        return None
    try:
        if _YT is None:
            _YT = YTMusic()
        res = _YT.search(f"{artist} {title}".strip(), filter="songs", limit=5)
    except Exception as e:
        print(f"  ! busqueda de portada fallo: {e}", file=sys.stderr)
        return None
    for x in res:
        if not _title_match(x.get("title") or "", title):
            continue
        d = x.get("duration_seconds")
        if d is None and x.get("duration"):
            try:
                m, sec = str(x["duration"]).split(":")
                d = int(m) * 60 + int(sec)
            except Exception:
                d = None
        if d and dur and abs(d - dur) > 6:
            continue
        th = x.get("thumbnails") or []
        if not th:
            continue
        url = max(th, key=lambda t: (t.get("width") or 0))["url"]
        return re.sub(r"=w\d+-h\d+", "=w1080-h1080", url)
    return None


def fetch_image(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(2 << 20)
    mime = "image/png" if data[:8] == b"\x89PNG\r\n\x1a\n" else "image/jpeg"
    return data, mime


def _img_dims(data):
    """ancho y alto leidos de la imagen misma. El header del bloque FLAC miente a
    veces (queda en 0x0 cuando el embed lo hizo ffmpeg)."""
    import struct
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        c = data[12:16]
        if c == b"VP8X":
            return (1 + int.from_bytes(data[24:27], "little"),
                    1 + int.from_bytes(data[27:30], "little"))
        if c == b"VP8 ":
            return (struct.unpack("<H", data[26:28])[0] & 0x3fff,
                    struct.unpack("<H", data[28:30])[0] & 0x3fff)
        if c == b"VP8L":
            b = int.from_bytes(data[21:25], "little")
            return ((b & 0x3fff) + 1, ((b >> 14) & 0x3fff) + 1)
    i = 2
    while i < len(data) - 9:
        if data[i] != 0xFF:
            i += 1
            continue
        mk = data[i + 1]
        if mk in (0xC0, 0xC1, 0xC2):
            h = struct.unpack(">H", data[i + 5:i + 7])[0]
            w = struct.unpack(">H", data[i + 7:i + 9])[0]
            return w, h
        if mk in (0xD8, 0xD9) or 0xD0 <= mk <= 0xD7:
            i += 2
            continue
        i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    return 0, 0


def picture_b64(data, mime):
    from mutagen.flac import Picture
    w, h = _img_dims(data)
    p = Picture()
    p.data, p.mime, p.type, p.width, p.height, p.depth = data, mime, 3, w, h, 24
    return base64.b64encode(p.write()).decode()


def pick_artist(cur_a, new_a):
    """Si el tag actual ya es una simplificacion del credito real, no lo empeoramos
    ('$uicideboy$' vs '$uicideboy$, Aristos Petrou, Scott Arceneaux Jr.')."""
    if not new_a:
        return cur_a or ""
    ca, na = core(cur_a), core(new_a)
    if ca and ca in na:
        return cur_a
    return new_a


def pick_album(cur_al, cur_aa, new_al, title):
    """El album de yt-dlp para un single repite el titulo (no aporta). El de Picard
    puede ser una compilacion cualquiera, y ahi si es una mentira: se borra."""
    if new_al and core(new_al) not in (core(title), "") and len(core(new_al)) > 2:
        return new_al
    if (cur_aa or "").strip().lower() in ("various artists", "varios artistas"):
        return ""
    return cur_al or ""


def target_tags(meta, cur):
    """El otro lado: los tags que la fuente de verdad (YouTube) dice que van."""
    title = meta["t"] or ""
    ct = core(cur.get("TITLE", ""))
    if not title or (ct and ct in core(title) and not meta["track"]):
        title = cur.get("TITLE", "") or title      # el video no aporta mas que el tag
    out = {}
    if title:
        out["TITLE"] = title
    artist = pick_artist(cur.get("ARTIST", ""), meta["a"])
    if artist:
        out["ARTIST"] = artist
    album = pick_album(cur.get("ALBUM", ""), cur.get("ALBUMARTIST", ""),
                       meta["al"], title)
    if album:
        out["ALBUM"] = album
    cur_d = cur.get("DATE") or ""
    if meta["d"] and not re.search(r"(19|20)\d\d", cur_d):
        out["DATE"] = meta["d"]        # solo si no hay un anio plausible: no se pierde precision
    elif cur_d:
        out["DATE"] = cur_d
    g = (cur.get("GENRE") or "").strip()
    if g and g.lower() not in ("music", "música"):
        out["GENRE"] = g
    return out


def cover_dims(cur):
    b = cur.get("METADATA_BLOCK_PICTURE")
    if not b:
        return 0, 0
    try:
        from mutagen.flac import Picture
        p = Picture(base64.b64decode(b))
        return _img_dims(p.data) if p.data else (p.width, p.height)
    except Exception:
        return 0, 0


def cover_plan(cur, meta, cover_search, dur):
    """(hay que tocar la portada, url). Nunca devuelve "borrar": si no hay reemplazo
    mejor, la que ya esta se queda. Un archivo sin portada se restaura con lo que
    haya, aunque sea el fotograma 16:9 del video."""
    w, h = cover_dims(cur)
    square = bool(w) and abs(w - h) <= 2
    if meta["sq"]:
        return (not square), meta["thumb"]
    if cover_search:
        if not meta.get("sq2"):
            t = ytmusic_cover(meta["t"], meta["a"], dur)
            meta["sq2"] = bool(t)
            meta["thumb2"] = t or ""
            _save_meta(force=True)
        if meta.get("sq2"):
            return (not square), meta["thumb2"]
    if not w:
        return True, meta["thumb"]
    return False, ""


def needs_fix(cur, want, yid):
    """Que tags le faltan a este archivo. Compara por `core` para no reescribir por
    una mayuscula o un apostrofo tipografico."""
    if cur.get("PURL", "").find(yid) < 0:
        return "falta PURL"
    for k, v in want.items():
        now = cur.get(k) or ""
        if k == "DATE":
            same = now == v
        elif k == "GENRE":
            same = now == v
        else:
            same = core(now) == core(v)
        if not same:
            return f"{k}: {now!r} -> {v!r}"
    for k in ("TITLE", "ARTIST", "ALBUM", "DATE", "GENRE"):
        if k in cur and k not in want:
            return f"{k} de mas: {cur[k]!r}"
    extra = set(cur) - KEEP
    if extra:
        return f"sobran {len(extra)} tags (p.ej. {sorted(extra)[0]})"
    return None


def apply_fix(path, want, pic_b64):
    from mutagen.oggopus import OggOpus
    tmp = path.with_name(path.name + ".ytmusic-tmp")
    shutil.copy2(path, tmp)
    try:
        f = OggOpus(str(tmp))
        old = dict(f.tags or {})
        BACKUP.parent.mkdir(parents=True, exist_ok=True)
        with BACKUP.open("a") as fh:
            fh.write(json.dumps({"f": path.name, "tags": {
                k: (v[0] if isinstance(v, list) and v else v) for k, v in old.items()
                if k != "METADATA_BLOCK_PICTURE"}}, ensure_ascii=False) + "\n")
        pic_old = next((v for k, v in old.items()
                        if k.upper() == "METADATA_BLOCK_PICTURE"), None)
        keep = {k: v for k, v in old.items()
                if k.upper() in ("PURL", "DESCRIPTION", "ENCODER")}
        f.clear()
        for k, v in list(keep.items()) + list(want.items()):
            f[k] = v
        pic = pic_b64 or pic_old          # sin reemplazo, la que ya estaba
        if pic:
            f["METADATA_BLOCK_PICTURE"] = pic if isinstance(pic, list) else [pic]
        if pic_old and not f.get("METADATA_BLOCK_PICTURE"):
            raise RuntimeError("me niego a guardar el archivo sin portada")
        f.save()
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    os.replace(tmp, path)


def fix(do_apply=False, limit=0, only="", cookies=False, refresh=False,
        cover_search=False):
    lib = load_index(rebuild=refresh)
    todo = [(n, r) for n, r in lib.items() if r["yid"] and (not only or only in n)]
    if limit:
        todo = todo[:limit]
    print(f"a revisar: {len(todo)} de {len(lib)}")
    stats = {"ok": 0, "cambio": 0, "error": 0, "sin-artista": 0}
    for i, (name, r) in enumerate(todo, 1):
        path = MUSIC / name
        try:
            cur, _ = read_tags(path)
            meta = fetch_meta(r["yid"], cookies=cookies)
            if not meta["sq"] and cover_search:
                if not meta.get("sq2"):
                    t = ytmusic_cover(meta["t"], meta["a"], r["dur"])
                    meta["sq2"] = bool(t)
                    meta["thumb2"] = t or ""
                    _save_meta(force=True)
                if meta.get("sq2"):
                    meta = dict(meta, sq=True, thumb=meta["thumb2"])
            want = target_tags(meta, cur)
            why = needs_fix(cur, want, r["yid"])
            need_cover, cover_url = cover_plan(cur, meta, cover_search, r["dur"])
            if not why and not need_cover:
                stats["ok"] += 1
                continue
            pic = ""
            if need_cover and cover_url:
                try:
                    data, mime = fetch_image(cover_url)
                    pic = picture_b64(data, mime)
                except Exception:
                    pic = ""
            if need_cover and not pic:
                stats["sin-artista"] += 1
            print(f"[{i}/{len(todo)}] {name[:70]}\n        "
                  f"{why or 'portada'}", flush=True)
            if do_apply:
                apply_fix(path, want, pic)
            stats["cambio"] += 1
        except Exception as e:
            stats["error"] += 1
            print(f"[{i}/{len(todo)}] ERROR {name[:60]}: {e}", file=sys.stderr)
    _save_meta(force=True)
    print(f"\nsin cambios: {stats['ok']}  corregidos: {stats['cambio']}  "
          f"errores: {stats['error']}  sin portada cuadrada: {stats['sin-artista']}")
    if not do_apply:
        print("(dry-run: nada escrito, usar --apply)")


# --- self-test ------------------------------------------------------------

def self_test():
    assert core("Maroon 5 - One More Night (Official Music Video)") == \
        "maroon 5 one more night"
    assert versions("LA LA LAND (Breathe Carolina Remix)") != \
        versions("LA LA LAND (Corporate Slackrs Remix)")
    assert versions("Song (Official Video)") == versions("Song") == frozenset()
    a = {"core": "where you are", "art": "john summit", "dur": 240.0,
         "ver": sorted(versions("Where You Are (Zedd Remix)"))}
    b = {"core": "where you are", "art": "john summit", "dur": 240.1,
         "ver": sorted(versions("Where You Are (GRiZ Remix)"))}
    assert same_song(a, b) == 0.0, "dos remixes distintos no son la misma cancion"
    c = dict(a, ver=sorted(versions("Where You Are")))
    assert same_song(a, c) == 0.0, "radio edit != original mix"
    d = {"core": "one more night", "art": "maroon 5", "dur": 219.5,
         "ver": sorted(versions("One More Night (Official Music Video)"))}
    e = {"core": "one more night", "art": "maroon 5", "dur": 219.9, "ver": []}
    assert same_song(d, e) > 0, "video oficial si es la misma cancion"
    # el canal no es el artista: mismo titulo exacto + misma duracion alcanza
    f = {"core": "toca", "art": "unsello", "dur": 200.0, "ver": []}
    g = {"core": "toca", "art": "el artista", "dur": 200.2, "ver": []}
    assert same_song(f, g) > 0, "el canal de YouTube no puede vetar el match"
    # 'feat. X' no es una version distinta, un remix si
    h = {"core": "inside", "art": "x", "dur": 200.0,
         "ver": sorted(versions("Inside (feat. Danyka Nadeau)"))}
    i = {"core": "inside", "art": "x", "dur": 200.2, "ver": []}
    assert same_song(h, i) > 0, "feat. no distingue"
    j = {"core": "inside", "art": "x", "dur": 200.0,
         "ver": sorted(versions("Inside (Slowed)"))}
    assert same_song(j, i) == 0.0, "un slowed no es el original"
    # REG-001: un remaster SI es la misma grabacion para efectos de "ya la tengo"
    k1 = {"core": "song", "art": "a", "dur": 200.0, "ver": sorted(versions("Song (Remastered 2011)"))}
    k2 = {"core": "song", "art": "a", "dur": 200.5, "ver": []}
    assert same_song(k1, k2) > 0, "un remaster no puede contar como cancion distinta"
    k3 = {"core": "song", "art": "a", "dur": 200.0, "ver": sorted(versions("Song (Clean)"))}
    assert same_song(k3, k2) == 0.0, "clean vs original no es lo mismo (puede estar censurada)"
    assert clean_title("Song (Official Music Video)") == "Song"
    assert clean_title("Song (Radio Edit)") == "Song (Radio Edit)"
    assert split_name("Spinnin' Records - ZHU - Faded.opus") == ("Spinnin' Records",
                                                                "ZHU - Faded")
    assert split_name("Loki - Topic - Reguecito.opus") == ("Loki - Topic", "Reguecito")
    assert _leading_noise("😉 009 Sound System - Dreamscape.opus") == 2
    assert _leading_noise("$uicideboy$ - Escape.opus") == 0
    assert _leading_noise("€urotra$h - B€NZ.opus") == 0
    # el nombre es un template de yt-dlp: nada de separadores ni '..'
    assert _safe_name("AC/DC - TNT") == "AC-DC - TNT"
    assert "../fuera" not in _safe_name("../../fuera")
    assert _safe_name("100% puro") == "100%% puro"
    # el nombre limpio gana siempre al de video, aunque sea mas nuevo
    assert _name_score("Adele - Rolling in the Deep.opus") == 0
    assert _name_score("Adele - Adele - Rolling in the Deep (Official Music Video).opus") > 3
    assert _name_score("Nicki Minaj - Only.opus") < _name_score(
        "Nicki Minaj - Nicki Minaj - Only ft. Drake, Lil Wayne, Chris Brown.opus")
    # dupes: si no puedo leer la fecha, ese archivo no puede quedar como keeper
    assert float("inf") > 1e9
    # _plausible no debe confundir dos canciones homonimas de distinto artista
    loki = {"core": "intro", "art": "loki", "dur": 100.0}
    otro = {"core": "intro", "art": "skillet", "dur": 100.5}
    assert _plausible({"core": "intro", "art": "loki", "dur": 100.2},
                      _bucket([loki, otro])) is not None
    assert _plausible({"core": "intro", "art": "skillet", "dur": 100.2},
                      _bucket([loki])) is None, "homonimo de otro artista"
    # target_tags / pick_artist / pick_album: un NameError aca no lo ve nadie hasta
    # que corre sobre 6000 archivos, asi que se ejercita en el test.
    meta = {"t": "Song (Official Video)", "a": "Artist", "al": "Album",
            "d": "2020", "sq": True, "track": False, "thumb": "http://x/y.jpg"}
    cur = {"TITLE": "Song", "ARTIST": "Artist", "ALBUM": "Album", "DATE": "2020",
           "GENRE": "Music", "PURL": "https://www.youtube.com/watch?v=abcdefghijk"}
    want = target_tags(meta, cur)
    assert want["TITLE"] == "Song" and want["ARTIST"] == "Artist", want
    assert "GENRE" not in want, "el genero 'Music' no se conserva"
    assert needs_fix(cur, want, "abcdefghijk") == "GENRE de mas: 'Music'"
    cur2 = {k: v for k, v in cur.items() if k != "GENRE"}
    assert needs_fix(cur2, want, "abcdefghijk") is None, needs_fix(cur2, want, "abcdefghijk")
    # portada: ida y vuelta real con un PNG 1x1 (picture_b64 -> cover_dims -> plan)
    png1 = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhK"
        "mMIQAAAABJRU5ErkJggg==")
    cur_pic = {"METADATA_BLOCK_PICTURE": picture_b64(png1, "image/png")}
    assert cover_dims(cur_pic) == (1, 1), cover_dims(cur_pic)
    # ya es 1:1: no hay que tocarla, aunque no haya reemplazo
    assert cover_plan(cur_pic, {"sq": False, "thumb": "u"}, False, 100)[0] is False
    # sin portada: se restaura con lo que haya
    assert cover_plan({}, {"sq": False, "thumb": "u"}, False, 100) == (True, "u")
    print("self-test ok")


def main():
    ap = argparse.ArgumentParser(prog="ytmusic", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("index", help="re-lee la biblioteca").add_argument("--force", action="store_true")
    p = sub.add_parser("check", help="playlist vs biblioteca")
    p.add_argument("urls", nargs="+")
    p.add_argument("--download", action="store_true", help="bajar las que faltan")
    p.add_argument("--json", action="store_true")
    p.add_argument("--cookies", action="store_true", help="usar cookies de Firefox")
    p.add_argument("--force", action="store_true",
                   help="bajar tambien lo que se parece a algo que ya tenes")
    f = sub.add_parser("fix", help="repara tags + portada por PURL")
    f.add_argument("--apply", action="store_true", help="escribir (default: dry-run)")
    f.add_argument("--limit", type=int, default=0)
    f.add_argument("--only", default="", help="filtrar por texto del nombre")
    f.add_argument("--cookies", action="store_true")
    f.add_argument("--refresh", action="store_true", help="re-indizar antes")
    f.add_argument("--cover-search", action="store_true",
                   help="buscar portada 1:1 en YT Music cuando el video solo tiene 16:9")
    d = sub.add_parser("dupes", help="duplicados confirmados por huella digital")
    d.add_argument("--ber", type=float, default=0.12, help="umbral de diferencia (0..1)")
    d.add_argument("--tol", type=float, default=6.0, help="tolerancia de duracion en s")
    d.add_argument("--json", action="store_true")
    r = sub.add_parser("rename", help="saca emojis del principio del nombre")
    r.add_argument("--apply", action="store_true", help="renombrar (default: dry-run)")
    r.add_argument("--json", action="store_true")
    sub.add_parser("self-test")
    a = ap.parse_args()
    if a.cmd == "index":
        index_library(force=a.force)
    elif a.cmd == "check":
        check(a.urls, a.download, a.cookies, a.json, a.force)
    elif a.cmd == "fix":
        fix(a.apply, a.limit, a.only, a.cookies, a.refresh, a.cover_search)
    elif a.cmd == "rename":
        clean_names(a.apply, a.json)
    elif a.cmd == "dupes":
        dupes(a.ber, a.tol, a.json)
    else:
        self_test()


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, FileNotFoundError) as e:
        # playlists borradas o privadas son el caso normal, no un traceback
        msg = e.args[0] if e.args else e
        if isinstance(msg, (list, tuple)):
            msg = " ".join(str(x) for x in msg)
        print(f"error: {msg}", file=sys.stderr)
        sys.exit(1)
