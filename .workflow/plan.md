# Plan rodante: personalización de Caelestia (proyecto 2026-09)

> Single source of truth for the work. Committed, survives any session.
> ONLY the next wave is detailed (rolling plan). When a session dies, a new
> instance resumes from this file — never from memory.
>
> El proyecto anterior (ollama 0.32.12 + límite de generaciones + editor de
> vídeo, olas 1–4) está cerrado y archivado en
> `.workflow/plan-archive-ollama-video.md`. Este plan arranca un proyecto
> nuevo: dejar Caelestia exactamente como lo quiere el humano.

## Goal

Dejar Caelestia como el humano lo quiere, con 13 puntos cerrados y verificados
en vivo: figuritas de workspace de vuelta, notificaciones migradas integradas
arriba-derecha como las nativas, rofi confirmado fuera, blur + 66% de
transparencia con la paleta cyberpunk de Wayle, más animaciones de workspace,
decisión sobre kitty, comandos de Caelestia documentados, OSD de brillo
conectado, mixxx en media (o descartado con evidencia), iconos reales de apps y
un indicador de workspace fluido. Se considera hecho cuando `nix flake check`
pasa, cada cambio tiene su verificación y el humano validó la parte visual.

## Stack & constraints

- NixOS flake (`nixos-unstable` pinneado; `nix flake check` es la única
  verificación automática del repo). Baseline 2026-09-20: `nix flake check`
  pasa y `main` == `origin/main`, árbol limpio.
- Caelestia = `caelestia-shell` 2.4.0 + `caelestia-cli` 1.1.2 + quickshell
  0.3.1 (todos de nixpkgs). El shell lee `~/.config/caelestia/shell.json`
  (sembrado una vez por `home.activation.caelestiaSeedConfig`; después manda el
  archivo del usuario) y `~/.local/state/caelestia/scheme.json` (lo escribe
  `caelestia-cli`).
- Los QML del shell son read-only en el store; los parches visuales van por
  overlay en `flake.nix` (`postPatch`/`substituteInPlace`), patrón ya usado por
  `caelestiaDedupeOverlay`.
- La config del CLI (`cli.json`) y los scripts del repo viven en
  `modules/desktop/caelestia.nix` y `modules/desktop/hyprland-home.nix`.
- **Trampa operativa**: `shell.json` es del usuario tras la primera siembra. Un
  cambio en el seed de `caelestia.nix` NO se aplica solo; el humano debe borrar
  `~/.config/caelestia/shell.json` y reconstruir (o aplicar lo mismo en Nexus).
  Los briefs lo asumen.
- Release gate: esto no se distribuye → auditoría ligera, sin `security-audit`.

## Hallazgos de la investigación (evidencia real, 2026-09-20)

Esta sección cierra los puntos que son consulta y documenta las causas raíz de
los bugs. Los ejecutores NO necesitan re-descubrirlo.

- **#3 rofi**: YA está fuera. `rofi` no existe en el sistema (`command -v rofi`
  → vacío), `programs.rofi.enable = false` (hyprland-home.nix) y no queda
  ningún archivo `rofi/*.rasi`; solo comentarios históricos. No hay trabajo.
- **#7 comandos de Caelestia** (los menús se despliegan por IPC; `caelestia
  shell <target> <func>` — el subcomando `ipc call` del CLI está ROTO, ver #12):
  - `caelestia shell drawers list` → `bar osd session launcher dashboard utilities sidebar`
  - `caelestia shell drawers toggle <drawer>` → abre/cierra launcher, dashboard,
    session, utilities, sidebar, osd, bar
  - `caelestia shell nexus open` → Ajustes del shell
  - `caelestia shell notifs toggleDnd` / `clear`
  - `caelestia shell mpris playPause|next|previous|stop|list`
  - `caelestia shell brightness set +10%` / `get`
  - `caelestia shell lock lock` / `unlock` / `isLocked`
  - `caelestia shell wallpaper set <ruta>` / `list`
  - `caelestia shell toaster info|success|warn|error "t" "m" "icon"`
  - `caelestia toggle <ws>`, `caelestia clipboard`, `caelestia emoji -p`,
    `caelestia scheme set -n <name>`, `caelestia screenshot`, `caelestia record`
  - Global shortcuts de Hyprland (`hl.dsp.global`): `caelestia:launcher`,
    `dashboard`, `session`, `utilities`, `sidebar`, `showall`, `nexus`, `lock`,
    `unlock`, `brightnessUp`, `brightnessDown`, `mediaToggle/Prev/Next/Stop`.
- **#8 OSD de brillo**: causa raíz = `brightness.sh` llama a `brightnessctl`/
  `ddcutil` DIRECTAMENTE, saltándose el servicio `Brightness` de Caelestia, que
  es quien dispara el OSD. Caelestia YA soporta panel interno (`brightnessctl`)
  y externo DDC/CI (`ddcutil`) en `services/Brightness.qml`. Fix = usar los
  global shortcuts `caelestia:brightnessUp/Down` y retirar `brightness.sh`.
- **#12 SUPER+L no bloquea**: causa raíz = el CLI espera `caelestia shell <target>
  <func>`, pero `lock.sh` y `wallpaper-set.sh` usan `caelestia shell ipc call
  <target> <func>` (el CLI vuelve a anteponer `ipc call` → "Target not found" y
  el script sale con `|| exit 0`). Fix = corregir la sintaxis en ambos scripts.
- **#9 mixxx en media**: NO es viable con configuración. Mixxx 2.5.6 no expone
  MPRIS: no hay bus `org.mpris.MediaPlayer2.mixxx` con Mixxx corriendo
  (`busctl --user list`), no hay strings `org.mpris`/`MediaPlayer2` en el
  binario, y no existe bridge mantenido. Opciones reales: (a) feature request
  upstream, (b) parche C++ a Mixxx (grande), (c) dejarlo. **Recomendación
  ponytail: no construirlo.** Decisión del humano pendiente.
- **#13 hibernación**: `pc` (y `laptop`) NO tienen swap en disco
  (`swapDevices = []`; solo `zramSwap`). La hibernación real (suspend-to-disk)
  no es posible sin un swapfile/partición con `resume=`. El watchdog
  implementará `systemctl suspend-then-hibernate` con caída a `suspend`; si el
  humano quiere hibernar de verdad, es una tarea de infraestructura aparte
  (swapfile + resume en kernel params). **Decisión pendiente del humano.**
- **#1 figuritas**: el enum es `BarWorkspaceDisplay = Shapes | Text` y el
  default upstream es `Shapes`; el repo lo puso en `text`. Revertir = `shapes`.
- **#5/#11 animaciones**: Hyprland soporta estilos `slide`, `slidevert`, `fade`,
  `slidefade`, `slidefadevert`, `outer` + curvas bezier (hoy: `slidevert` +
  curva `standard`). La barra de Caelestia tiene `activeTrail` (estela fluida del
  indicador al cambiar de workspace) y `shell-tokens.json` permite ajustar
  duraciones/curvas. El viejo Wayle tenía un `workspace-bounce` (SCSS) que
  Caelestia no trae; se puede portar como parche QML.
- **#2 notificaciones**: las "migradas de Wayle" son los **toasts** de Caelestia
  (C++: caps lock, cambio de layout, carga, etc.), que se pintan ABAJO-derecha
  (`Panels.qml`: `Toasts` anclado a `bottom: utilities.top`). Las notificaciones
  DBus (p. ej. "Modo espejo") se pintan ARRIBA-derecha
  (`notifications/Wrapper` anclado `top`+`right`). El humano quiere los toasts
  integrados arriba-derecha.
- **#4 paleta Wayle** (recuperada de la config HM generada,
  `/nix/store/xk9lwgp2zwa18zad8yzimqs044kvnzy7-hm_wayleconfig.toml`):
  `bg #0a0a12 · surface #141428 · elevated #1e1e3a · fg #d4d4f0 ·
  fg-muted #8888aa · primary #ff0066 · red #ff0040 · yellow #ffcc00 ·
  green #00ff88 · blue #00aaff`. Caelestia solo acepta esquemas de su lista fija
  (o `dynamic`); `scheme_data_dir` es read-only dentro del paquete
  `caelestia-cli` → se añade un esquema `cyberpunk` por overlay.

## Waves

| Wave | Focus | Status |
|------|-------|--------|
| 1 | Config Caelestia + bugs (SUPER+L, OSD brillo, idle) + paleta cyberpunk | planned |
| 2 | Parches QML del overlay: iconos reales, toasts arriba-derecha, animación workspace | pending |
| 3 | Kitty (gated por decisión del humano) + limpieza + validación en vivo | pending |
| 4 | (opcional) Mixxx MPRIS — NO recomendado (ver hallazgo #9) | pending |

> Status legend: planned → in-flight → integrated → audited → done.
> Update after each step, by whoever ran the step.

---

## Wave 1 (current)

Tres ejecutores, archivos disjuntos. Nadie toca `flake.lock`, ni
`modules/apps/*`, ni los scripts que no le toquen.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `modules/desktop/caelestia.nix` | executor-1 |
| `modules/desktop/hyprland-home.nix` | executor-2 |
| `flake.nix` | executor-3 |

### Tasks

- [ ] T1: `shell.json` seed — figuritas (`displayType=shapes`), transparencia
      0.34 + layers 0.5, `activeTrail=true`, idle sin auto-lock ni auto-hibernar
      → brief: `.workflow/briefs/wave1-executor-1.md`
- [ ] T2: fixes de `hyprland-home.nix` — IPC de lock (SUPER+L), binds de brillo
      a global shortcuts (OSD) + retiro de `brightness.sh`, `ignore_alpha` del
      blur a 0.3, watchdog lock→hibernar 5 min, re-aplicar esquema cyberpunk
      tras cambiar wallpaper → brief: `.workflow/briefs/wave1-executor-2.md`
- [ ] T3: overlay `caelestia-cli` con el esquema `cyberpunk` (paleta Wayle
      mapeada a claves M3) → brief: `.workflow/briefs/wave1-executor-3.md`

### Integration plan

- Orden de merge: **executor-3 (flake.nix) primero** (habilita el esquema
  `cyberpunk` que referencia executor-2), luego executor-1 y executor-2. Los
  tres son disjuntos; el orden solo evita una ventana en la que
  `caelestia scheme set -n cyberpunk` aún no exista.
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel
  ```
- Pasos del humano tras el commit (regla AGENTS.md: rebuild lo corre él):
  1. `rm ~/.config/caelestia/shell.json` (adoptar el seed nuevo; pierde ajustes
     hechos en Nexus) y `sudo nixos-rebuild switch --flake .#pc`.
  2. `caelestia scheme set -n cyberpunk` (una vez).
  3. Validar en vivo: SUPER+L bloquea; SUPER+F11/F12 y XF86 muestran el OSD;
     figuritas de vuelta; transparencia/blur; indicador con estela; paleta
     magenta/cian; toasts (esto último se pule en ola 2).

### Audit gate

- Auditor corre en el árbol integrado:
  - `nix flake check` pasa.
  - `git diff main..HEAD --stat` = solo `modules/desktop/caelestia.nix`,
    `modules/desktop/hyprland-home.nix`, `flake.nix` (+ `.workflow/`).
  - El verify de cada brief pasa.
  - Sin secretos; sin archivos fuera del mapa de propiedad.
  - `skills/security-audit` NO aplica (no se distribuye).

---

## Wave 2 (next) — parches QML del overlay

> Gate: ola 1 integrada y auditada. Un solo ejecutor (`flake.nix`), porque los
> tres parches viven en el mismo overlay.

- **Iconos reales de apps (#10)**: `Workspace.qml` usa `MaterialIcon` con
  `Icons.getAppCategoryIcon` (glifo monocromo). Parche para usar
  `Icons.getAppIcon` (icono real del `.desktop` vía `Quickshell.iconPath`) con
  `CachingIconImage`/`Image` de fallback al glifo.
- **Toasts arriba-derecha (#2)**: `Panels.qml` ancla `Toasts.Toasts` a
  `bottom: utilities.top`. Reposicionar a la zona superior derecha, apilados
  bajo las notificaciones, para que se vean integrados como los nativos.
- **Animación de workspace fluida (#11b)**: portar el `workspace-bounce` de
  Wayle (o una variante) al indicador/iconos de `Workspace.qml`, o exponer una
  curva más expresiva. Validar con el humano cuál le gusta.

## Wave 3 (next-next) — kitty + cierre

> Gate: decisión del humano sobre migrar a kitty (#6). Hasta entonces, no se
> escribe el brief.

- `kitty` como terminal (nuevo `modules/apps/kitty.nix` o sección en
  `home/default.nix`), mismo look del vidrio (0.66), fuente y colores
  cyberpunk; actualizar `general.apps.terminal`, binds (`SUPER+Backspace`,
  `SUPER+N`) y los scripts que abren `wezterm`. Alternativa ponytail: quedarse
  en wezterm (ya está afinado) y no migrar.
- Limpieza final: retirar comentarios muertos de rofi, cerrar `#3/#5/#7` en el
  decision log.

## Wave 4 (opcional) — Mixxx MPRIS

No recomendado (hallazgo #9). Solo si el humano insiste: parche C++ a Mixxx o
feature request upstream. No se planifica hasta que lo pida.

---

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-20 | Proyecto nuevo (personalización Caelestia); el plan de ollama/vídeo se archiva en `.workflow/plan-archive-ollama-video.md` | El proyecto anterior está cerrado; el plan rodante pasa a este |
| 2026-09-20 | #9 Mixxx: NO construir bridge MPRIS; recomendar descartar | Verificado: Mixxx 2.5.6 no expone MPRIS (sin bus name, sin strings) y no hay bridge mantenido |
| 2026-09-20 | #8 y #12 se arreglan con la sintaxis correcta de IPC (`caelestia shell <target> <func>`, no `ipc call`) | El subcomando `ipc call` del CLI duplica el prefijo y da "Target not found" |
| 2026-09-20 | #4 paleta: esquema `cyberpunk` por overlay a `caelestia-cli` (no se puede escribir un esquema de usuario) | `scheme_data_dir` vive read-only dentro del paquete |
| 2026-09-20 | #13: sin auto-lock; watchdog que hiberna si la sesión lleva 5 min bloqueada | Caelestia no soporta timeouts condicionados al lock |
| 2026-09-20 | #13: `pc`/`laptop` no pueden hibernar de verdad (sin swap en disco, solo zram) → el watchdog usa `suspend-then-hibernate` con fallback a `suspend`; hibernación real = tarea de infra pendiente de decisión | Verificado: `swapDevices = []` + `zramSwap` en `amd-common.nix` |
