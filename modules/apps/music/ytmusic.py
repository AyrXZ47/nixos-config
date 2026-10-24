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
import difflib
import json
import os
import re
import shutil
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
FEAT = re.compile(r"\b(?:feat|ft|featuring|with)\.?\s+(.+)$", re.I)
TAIL_NOISE = re.compile(
    r"\s*[\(\[]\s*(official\s*(music\s*)?video|official\s*audio|oficial|official|"
    r"lyric\s*video|lyrics?|visuali[sz]er|audio|hd|hq|4k)\s*[\)\]]\s*$", re.I)
FEAT_IN = re.compile(r"\b(?:feat|ft|featuring|with)\.?\s+[^\)\]]*$", re.I)


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
        for p in re.findall(r"[\(\[]([^\)\]]*)[\)\]]", t) + FEAT.findall(t):
            p = FEAT_IN.sub(" ", _acc(p).lower())
            p = NOISE.sub(" ", p)
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
    """'Canal - Titulo.opus' -> (canal, titulo). Es el template de yt-dlp."""
    stem = re.sub(r"\.opus$", "", fn, flags=re.I)
    up, _, vt = stem.partition(" - ")
    return (up, vt) if vt else ("", stem)


def similar(a, b):
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    return difflib.SequenceMatcher(None, a, b).ratio()


def same_song(a, b, tol=3.0):
    """a y b son dicts con core/art/ver/dur."""
    if abs(a["dur"] - b["dur"]) > tol or a["dur"] <= 20:
        return 0.0
    if a["ver"] != b["ver"]:
        return 0.0
    t = 1.0 if a["core"] == b["core"] else similar(a["core"], b["core"])
    if t < 0.92 or similar(a["art"], b["art"]) < 0.6:
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
        row["core"] = core(row["t"] or vt)
        row["art"] = core(up)
        row["ver"] = sorted(versions(row["t"], vt, up))
        files[p.name] = row
        seen += 1
    INDEX.write_text(json.dumps(files, ensure_ascii=False))
    print(f"indice: {len(files)} archivos ({seen} re-leidos, {len(files)-seen} del cache)")
    return files


def load_index(rebuild=False):
    if rebuild or not INDEX.exists():
        return index_library(force=rebuild)
    return json.loads(INDEX.read_text())


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
    return d.get("entries") or []


def download(urls, cookies=False):
    args = YDL + CLIENTS + [
        "--ignore-errors", "--no-overwrites", "--extract-audio",
        "--audio-format", "opus", "--embed-metadata", "--embed-thumbnail",
        "--js-runtimes", "node", "--sleep-requests", "1",
        "--sleep-interval", "3", "--max-sleep-interval", "8",
        "-o", "%(uploader)s - %(title)s.%(ext)s", "--newline",
    ]
    if cookies:
        args += ["--cookies-from-browser", "firefox"]
    done = 0
    for i, u in enumerate(urls, 1):
        print(f"[{i}/{len(urls)}] {u}", flush=True)
        r = subprocess.run(args + [u], cwd=str(MUSIC))
        done += r.returncode == 0
    return done


# --- check ----------------------------------------------------------------

def entry_key(e):
    title = e.get("title") or ""
    artist = e.get("channel") or e.get("uploader") or ""
    return {"core": core(title), "art": core(artist), "ver": sorted(versions(title)),
            "dur": float(e.get("duration") or 0)}


def check(urls, do_download=False, cookies=False, as_json=False):
    lib = load_index()
    rows = list(lib.values())
    entries = []
    for u in urls:
        got = playlist_entries(u, cookies=cookies)
        print(f"{u}: {len(got)} temas", file=sys.stderr)
        entries += got

    # duplicados dentro de las mismas playlists
    uniq, dropped = [], 0
    for e in entries:
        k = entry_key(e)
        if any(same_song(k, entry_key(x)) > 0 for x in uniq):
            dropped += 1
            continue
        uniq.append(e)

    tienen, faltan = [], []
    for e in uniq:
        k = entry_key(e)
        hit = None
        for r in rows:
            if same_song(k, r) > 0:
                hit = r
                break
        (tienen if hit else faltan).append((e, hit))

    if as_json:
        print(json.dumps({"total": len(uniq), "duplicadas": dropped,
                          "tengo": [{"id": e.get("id"), "title": e.get("title"),
                                     "local": h["t"] or h["vt"]} for e, h in tienen],
                          "faltan": [{"id": e.get("id"), "title": e.get("title"),
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
                print(f"  {str(e.get('duration') or '?'):>5}s  {e.get('title','')[:52]:52}"
                      f" | {(e.get('channel') or e.get('uploader') or '')[:24]:24}"
                      f" | https://music.youtube.com/watch?v={e.get('id')}")

    if do_download and faltan:
        urls_ok = [f"https://music.youtube.com/watch?v={e.get('id')}" for e, _ in faltan]
        print(f"\ndescargando {len(urls_ok)} temas en {MUSIC} ...", flush=True)
        ok = download(urls_ok, cookies=cookies)
        print(f"descargados {ok}/{len(urls_ok)}")
    return faltan


# --- fix ------------------------------------------------------------------

KEEP = {"TITLE", "ARTIST", "ALBUM", "DATE", "GENRE", "PURL", "DESCRIPTION",
        "ENCODER", "METADATA_BLOCK_PICTURE"}


def fetch_meta(yid, cookies=False):
    cache = json.loads(META.read_text()) if META.exists() else {}
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
    out = {"t": clean_title(d.get("track") or d.get("title") or ""),
           "a": artist,
           "al": (d.get("album") or "").strip(),
           "d": year,
           "sq": bool(square),
           "thumb": best["url"] if best else ""}
    cache[yid] = out
    META.parent.mkdir(parents=True, exist_ok=True)
    META.write_text(json.dumps(cache, ensure_ascii=False))
    return out


def fetch_image(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = r.read(2 << 20)
    mime = "image/png" if data[:8] == b"\x89PNG\r\n\x1a\n" else "image/jpeg"
    return data, mime


def picture_b64(data, mime):
    from mutagen.flac import Picture
    w = h = 0
    if mime == "image/png":
        import struct
        k = data.find(b"\x89PNG\r\n\x1a\n")
        w, h = struct.unpack(">II", data[k + 16:k + 24])
    else:
        import struct
        i = 2
        while i < len(data) - 9:
            if data[i] != 0xFF:
                i += 1
                continue
            mk = data[i + 1]
            if mk in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", data[i + 5:i + 9])
                break
            if mk in (0xD8, 0xD9) or 0xD0 <= mk <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack(">H", data[i + 2:i + 4])[0]
    p = Picture()
    p.data, p.mime, p.type, p.width, p.height, p.depth = data, mime, 3, w, h, 24
    return base64.b64encode(p.write()).decode()


def target_tags(meta, cur):
    out = {"TITLE": meta["t"], "ARTIST": meta["a"]}
    if meta["al"]:
        out["ALBUM"] = meta["al"]
    if meta["d"]:
        out["DATE"] = meta["d"]
    g = (cur.get("GENRE") or "").strip()
    if g and g.lower() not in ("music", "música"):
        out["GENRE"] = g
    return out


def needs_fix(cur, want, yid):
    if cur.get("PURL", "").find(yid) < 0:
        return "falta PURL"
    for k, v in want.items():
        if (cur.get(k) or "") != v:
            return f"{k}: {cur.get(k,'')!r} -> {v!r}"
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
        keep = {k: v for k, v in old.items()
                if k.upper() in ("PURL", "DESCRIPTION", "ENCODER")}
        f.clear()
        for k, v in list(keep.items()) + list(want.items()):
            f[k] = v
        if pic_b64:
            f["METADATA_BLOCK_PICTURE"] = [pic_b64]
        f.save()
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    os.replace(tmp, path)


def fix(do_apply=False, limit=0, only="", cookies=False, refresh=False):
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
            want = target_tags(meta, cur)
            why = needs_fix(cur, want, r["yid"])
            if not why:
                stats["ok"] += 1
                continue
            if not meta["sq"]:
                stats["sin-artista"] += 1
            pic = ""
            if meta["thumb"]:
                try:
                    data, mime = fetch_image(meta["thumb"])
                    pic = picture_b64(data, mime)
                except Exception:
                    pic = ""
            print(f"[{i}/{len(todo)}] {name[:70]}\n        {why}", flush=True)
            if do_apply:
                apply_fix(path, want, pic)
            stats["cambio"] += 1
        except Exception as e:
            stats["error"] += 1
            print(f"[{i}/{len(todo)}] ERROR {name[:60]}: {e}", file=sys.stderr)
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
    assert clean_title("Song (Official Music Video)") == "Song"
    assert clean_title("Song (Radio Edit)") == "Song (Radio Edit)"
    assert split_name("Spinnin' Records - ZHU - Faded.opus") == ("Spinnin' Records",
                                                                "ZHU - Faded")
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
    f = sub.add_parser("fix", help="repara tags + portada por PURL")
    f.add_argument("--apply", action="store_true", help="escribir (default: dry-run)")
    f.add_argument("--limit", type=int, default=0)
    f.add_argument("--only", default="", help="filtrar por texto del nombre")
    f.add_argument("--cookies", action="store_true")
    f.add_argument("--refresh", action="store_true", help="re-indizar antes")
    sub.add_parser("self-test")
    a = ap.parse_args()
    if a.cmd == "index":
        index_library(force=a.force)
    elif a.cmd == "check":
        check(a.urls, a.download, a.cookies, a.json)
    elif a.cmd == "fix":
        fix(a.apply, a.limit, a.only, a.cookies, a.refresh)
    else:
        self_test()


if __name__ == "__main__":
    main()
