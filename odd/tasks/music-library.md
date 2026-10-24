# Biblioteca de musica: comparar contra YT Music y reparar metadatos

Herramienta `ytmusic` (check/fix) para la carpeta plana `~/Sync/My Music` (6219 `.opus`
de yt-dlp). Sustituye el trabajo manual de cruzar la playlist "pendientes" contra la
biblioteca y deshace el dano de Picard/MusicBrainz sin re-descargar audio.

## Specs

S1. Version de estudio, no video: "si en mi carpeta la versión que tengo dice cosas
como oficial video, se elimina y busco la canción pura en ytm, no el video oficial".

S2. Los remixes/lives/radio edits se respetan: "en la electrónica si dejo radio edit
porque luego los original mix me parecen con mucho bloatware". Una comparacion nunca
debe tratar dos versiones distintas como la misma cancion.

S3. Sin versiones censuradas: "odio las versiones sensuradas [...] las canciones
suenan todas entre cortadas". Politica acordada: si ya esta en la playlist, se
reemplaza (ver S5) en lugar de detectar censura localmente.

S4. Se elimina el archivo lateral de descargas: "no me gusta el .txt que genera el
script de ytdlp [...] bloquea la descarga". Reemplazo: `--no-overwrites`, que solo
saltea si ese archivo exacto ya existe.

S5. Politica de reemplazo: "si ya la tengo el 90% de las veces vale la pena eliminarla
y volver a descargarla".

S6. Alcance autorizado: reparar tags por PURL, crear `ytcheck` con commit, y descargar
las canciones faltantes.

S7. Nivel de escucha: "que no queme bocinas, que no sature canal, que no se escuche
bajito" (biblioteca real: mediana -8.6 LUFS, rango -19.2 a -4.8).

## Tasks

| ID | Spec | Ruta | Commit |
|----|------|------|--------|
| T1 | S1-S7 | Documento ODD | `docs(music): especificar ytmusic` |
| T2 | S1-S5 | `modules/apps/music/ytmusic.py` (index/check/fix/self-test) | `feat(music): ytmusic` |
| T3 | S4 | `modules/apps/shell.nix`: `ytlist` con `--no-overwrites` + paquete `ytmusic` | idem T2 |
| T4 | - | `nix flake check` + commit | idem T2 |
| T5 | S1, S7 | `ytmusic fix` sobre los 6026 archivos con PURL | (sin commit: datos) |
| T6 | S3, S5 | `ytmusic check <playlist> --download` | (sin commit: datos) |
| T7 | S6 | Las 2 playlists publicas del Liked Music (9239 temas) | (sin commit: datos) |

## Log

L1. Pedido original (resumen; las specs de arriba citan textual las frases que
mandan): quiere deduplicar la carpeta, comparar contra la playlist "pendientes"
(`PLSPoy2-eRK2Y`), saber si lo que tiene es version censurada, y deshacer el dano de
Picard (portadas de compilacion, titulos/artistas revueltos, titulos en japones).
Usa `ytlist`/`ytsong` con yt-dlp; escucha en Mixxx con AutoDJ aleatorio.

L2. Decisiones del usuario: "si, lanza el PURL!", "SI, ytcheck + commit", "Si descarga
las canciones, me ahorrarías mucho tiempo encargandote tú".

L3. Evidencia de la auditoria (read-only, 2026-10-23): 6026/6219 con `PURL`; 4831 con
tags MusicBrainz; 295 forzados a `Various Artists`; 2682 con `GENRE=Music`; 466 con
artist de tag != canal; 1308 portadas 16:9; 193 sin tags; 18 grupos de duplicados
reales (0.3%); playlist "pendientes": 76 temas, 11 ya estan, 65 faltan.

L4. Evidencia Mixxx: la base esta sincronizada (6023/6219 titulos iguales al tag
actual), asi que "borrar y reimportar" no arregla nada: el problema son los tags.
`[Soundcard] Samplerate 44100` contra PipeWire a 48000 y opus de 48000 = doble
resample. ReplayGain LUFS v2 activo con `InitialDefaultBoost -6`.
