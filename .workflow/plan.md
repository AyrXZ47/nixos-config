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
  binario, y no existe bridge mantenido. El humano lo **descartó** (2026-09-20).
- **#5 Celsius**: existe `services.useFahrenheit` y
  `services.useFahrenheitPerformance`, ambos con default por locale
  (`QLocale().measurementSystem()`); en su locale pueden quedar en imperial. Se
  fuerzan `false` en el seed. La temperatura de CPU/GPU siempre es °C.
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
  (`notifications/Wrapper` anclado `top`+`right`). Decisión del humano
  (2026-09-20): **absolutamente todo** debe verse como notificación nativa de
  Caelestia (zona superior derecha y estilo de `notifications/Content.qml`).
  Los eventos del cambio de layout se pueden emitir con `notify-send` real
  (desactivando el toast nativo y re-agregando el aviso en `switch-layout.sh`);
  caps lock no tiene fuente de evento externa (vive en C++), así que su toast
  se re-posiciona/re-estiliza en la zona de notificaciones.
- **#4 paleta Wayle** (recuperada de la config HM generada,
  `/nix/store/xk9lwgp2zwa18zad8yzimqs044kvnzy7-hm_wayleconfig.toml`):
  `bg #0a0a12 · surface #141428 · elevated #1e1e3a · fg #d4d4f0 ·
  fg-muted #8888aa · primary #ff0066 · red #ff0040 · yellow #ffcc00 ·
  green #00ff88 · blue #00aaff`. Caelestia solo acepta esquemas de su lista fija
  (o `dynamic`); `scheme_data_dir` es read-only dentro del paquete
  `caelestia-cli` → se añade un esquema `cyberpunk` por overlay. **F1**: la
  ruta correcta es `schemes/cyberpunk/default/dark.txt` (con subdirectorio de
  flavour); la original sin `default/` crashea el CLI.
- **#5 animaciones**: las transiciones entre workspaces las da **Hyprland**
  (`hl.animation({ leaf = "workspaces", ... })`), no Caelestia. Estilos válidos
  en 0.56: `slide`, `slidevert`, `fade`, `slidefade`, `slidefadevert` (admiten
  porcentaje, p.ej. `slidefade 20%`). Caelestia solo aporta la animación del
  indicador de la barra (`activeTrail` + morph de las shapes). El "bounce
  fuerte" viejo era `hl.curve("bounce", { {0.05, 1.8}, {0.2, 1.0} })` +
  `slidevert`; hoy hay `standard`. El humano probó con el selector y eligió la
  definitiva: **`slidefadevert` + `overshot`** (se fija en la ola 3).
- **Monitor actual**: `HDMI-A-2` 1920x1080 con modo **100 Hz** disponible. El
  `highrr` ya está en el repo (ola 2), pero en runtime el monitor todavía marca
  60 Hz porque (a) Hyprland no recarga la config tras el rebuild — hace falta
  `hyprctl reload` o re-loguear, y (b) estaba **espejando** la salida
  `HEADLESS-TABLET` del cast VNC (`mirrorOf = 1`). Cerrando wayvnc + reload
  debería quedar en 100 Hz. Bug raíz del espejo: `monitor-mirror.sh` elegía el
  primario por `max_by(área × Hz)` y la salida headless (1920x1200) le ganaba al
  monitor físico → espejaba el físico contra la tablet.
- **Cast VNC (#nuevo)**: el humano lo quiere fuera. `modules/apps/vnc.nix`
  (paquete `wayvnc` + comando `cast-tablet`), sus binds
  (`SUPER+ALT+D`, `SUPER+ALT+SHIFT+D`) y su import en `home/default.nix` se
  borran. Miracast (`gnome-network-displays`, `modules/apps/miracast.nix`) se
  queda. `SUPER+D` pasa a ser el toggle espejo/extender de pantallas físicas/TV.
- **OSD "monita" (#nuevo)**: el gif que anima en el panel de media del dashboard
  es `modules/dashboard/dash/Media.qml` → `AnimatedImage` con
  `source: Config.paths.mediaGif` (hoy `assets/bongocat.gif`). El humano
  confirmó 2026-09-20: **el bongocat se queda**, no hay tarea.
- **Icono del workspace activo en gris (#nuevo)**: `ActiveIndicator.qml` dibuja
  la píldora del workspace activo y encima un `Colouriser` (un `MultiEffect` con
  `colorization: 1`, `colorizationColor: m3onPrimary`) que **recolorea todo el
  contenido del mask** para dar contraste. Con los glifos Material era invisible;
  con los iconos reales, el icono del workspace activo se aplana a un solo color
  (se ve gris). Fix ola 5: `colorization: 0` y `brightness: 0` en ese
  `Colouriser` (sigue redibujando el contenido sobre la píldora, pero sin
  recolorear).
- **Logo NixOS del bar (#nuevo)**: `modules/bar/components/OsIcon.qml`
  renderiza `ColouredIcon { source: SysInfo.osLogo; colour: Colours.palette.m3tertiary }`
  → lo **recolorea** al color del esquema (hoy verde `00ff88`). El humano lo
  quiere azul NixOS (`#5277c3`). Parche QML: `colour: "#5277c3"` (o quitar el
  recoloreo). Va en la ola 4.
- **mpvpaper duplicado/parpadeo (#nuevo)**: el 2026-09-20 había **dos**
  procesos `mpvpaper` (`.mpvpaper-wrapp`) con wallpapers distintos. Causa:
  `wallpaper-set.sh` lanza el fondo, luego `caelestia wallpaper -f` y luego
  `caelestia scheme set` disparan el `postHook` → `caelestia-wallpaper.sh` hasta
  3 veces; el `pkill -x .mpvpaper-wrapp` no gana la carrera. Fix ola 4:
  `wallpaper-set.sh` solo lanza el fondo; `caelestia-wallpaper.sh` idempotente
  (si ya corre el mismo wallpaper, salir).
- **Shell vieja en runtime (#nuevo)**: tras un `rebuild`, Hyprland sigue con la
  instancia de quickshell del store **anterior** (PID viejo, config `5m8m…`)
  mientras `caelestia-shell` en PATH ya es la nueva (`vbcm3v0…`). Por eso el IPC
  (`caelestia shell lock …`) devuelve **exit 255** y SUPER+L no bloquea: no hay
  que "arreglar" nada, hay que **reiniciar la shell**. Ola 4 agrega el helper
  `caelestia-restart.sh`.
- **Auto-espejo al arrancar (#nuevo)**: `hl.on("monitor.added", … monitor-mirror.sh mirror)`
  espeja al detectar monitores → "pantallas locas" al boot. Ola 4 lo quita y
  hace `monitor-mirror.sh` no-op con <2 salidas físicas; el toggle `SUPER+D`
  queda manual.
- **`shell.json` ausente → defaults (#nuevo, 2026-09-20)**: el humano borró
  `~/.config/caelestia/shell.json` para adoptar `terminal=kitty` y reinició la
  shell SIN rebuild. La siembra del seed solo corre en `home-manager switch`, así
  que la shell arrancó con **defaults** (solo el esquema/tema sigue, porque vive
  en `scheme.json`). Fix sin rebuild:
  `cp "$(nix build --no-link --print-out-paths .#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath)" ~/.config/caelestia/shell.json`.
  Lección: borrar `shell.json` **exige** un rebuild (o el `cp` de arriba).
- **Splits de kitty rechazados (#nuevo)**: la ola 5 dejó `hyprdev`/`netrunner`
  usando `kitty @ launch --location=vsplit/hsplit`. El humano los rechaza: quiere
  **ventanas kitty independientes tileadas** (para ver el wallpaper por los gaps),
  con dedupe a **un icono** en la barra de Caelestia. La ola 6 revierte a
  ventanas independientes (clase por defecto `kitty` → el dedupe de
  `Workspace.qml` las colapsa y `getAppIcon("kitty")` da el icono real).
- **Restart de Caelestia**: `caelestia shell -k` mata el shell y
  `caelestia shell -d` lo relanza (equivalente a `wayle panel restart`). El
  shell ya recarga `shell.json`/`scheme.json` en caliente, así que normalmente
  no hace falta reiniciar.

## Waves

| Wave | Focus | Status |
|------|-------|--------|
| 1 | Config Caelestia + bugs (SUPER+L, OSD brillo, idle/suspend, Celsius) + paleta cyberpunk | rejected (F1) → fixeada en ola 2 |
| 2 | Fix F1 (esquema) + monitor `highrr` + animaciones de workspace + NeoCyberVim + layout nativo | audited · APPROVED |
| 3 | Animación final (`slidefadevert`+`overshot`), fuera cast VNC, espejo arreglado, nvim transparente | integrated (sin auditar — excepción humana) |
| 4 | Logo azul, notificaciones nativas, iconos reales, mpvpaper dedupe, espejo con 2+ monitores | integrated · audit APPROVED WITH EXCEPTIONS · **HOTFIX F3 (shell no carga)** |
| 5 | Color del icono activo + migración a kitty (config + hyprdev/netrunner + binds) | audited · APPROVED WITH EXCEPTIONS |
| 6 | hyprdev/netrunner a ventanas kitty independientes, bolita del logo Nix, MPRIS falso de Mixxx | planned |
| 7 | Mixxx MPRIS real — DESCARTADO por el humano (evidencia en hallazgo #9); la ola 6 es el "engaño" aceptado | done |

> Status legend: planned → in-flight → integrated → audited → done.
> Update after each step, by whoever ran the step.

---

## Wave 1 — RECHAZADA por auditoría (F1), fix en ola 2

> Audit: `.workflow/audits/wave1.md`. Integración, build, seguridad y los puntos
> #1 (figuritas), #4a (transparencia), #5 (Celsius), #8 (OSD de brillo), #11a
> (trail) y #12 (SUPER+L) están bien y verificados en vivo. **Bloqueante F1**:
> el esquema del overlay quedó en `schemes/<nombre>/dark.txt` en vez de
> `schemes/<nombre>/<flavour>/dark.txt` → `caelestia scheme set -n cyberpunk`
> crashea con `IndexError` y la paleta (#4) no se aplica. F2 (`|| true` en
> `wallpaper-set.sh`) lo enmascaraba. El fix va en la ola 2.

---

## Wave 2 — AUDITADA / APROBADA (F1 cerrado)

> Audit: `.workflow/audits/wave2.md` (APPROVED). Merges `b618fda`, `792bff3`,
> `1b47fee`, `7fb5cfa` en `main`; `nix flake check` completo pasa; los 4 verify
> pasan; F1 cerrado con la verificación fuerte. H1–H4 informativos (validación
> visual del humano, allowlist opcional en `workspace-anim.sh`, worktrees sin
> retirar, plan desactualizado). Runtime confirmado 2026-09-20: `caelestia
> scheme get -n` → `cyberpunk`.

### Nota de proceso (desviación aceptada de executor-4)

El brief pedía `lib.hm.dag.entryAfter` para el activation en
`modules/desktop/caelestia.nix`, pero ese módulo es **system-side** (importado
por `hosts/*/configuration.nix`): recibe el `lib` plano de nixpkgs, sin `.hm`.
El executor usó la forma correcta y consistente con `caelestiaSeedConfig`:
`home.activation.<nombre> = { after = [ "writeBoundary" ]; before = [ ]; data = …; };`.
Desviación **aceptada**. `_template.md` documenta ahora la diferencia.

---

## Wave 3 — INTEGRADA (sin auditar, excepción autorizada por el humano)

> El humano cerró la ola 3 y pidió avanzar más rápido, saltándose la auditoría.
> **Excepción explícita registrada** (regla: la siguiente ola empieza solo tras
> auditoría o excepción registrada). Verificado en el árbol por el planner:
> animación `slidefadevert` + `overshot`, `SUPER+D` bindeado, `modules/apps/vnc.nix`
> borrado, `NeoCyberVim` transparente. **Riesgo aceptado**: sin verify/audit no
> hay evidencia de `nix flake check` tras el merge. Si algo se rompe, la ola 4
> lo va a exponer.

---

## HOTFIX F3 (bloqueante de arranque) — `Image.implicitHeight` es read-only

> Detectado en runtime 2026-09-20: al reiniciar la shell, quickshell falla con
> `Type Workspace unavailable: Invalid property assignment: "implicitHeight" is a
> read-only property` (cadena `Drawers → ContentWindow → Bar → Workspaces →
> Workspace`). La shell NO carga. La auditoría de la ola 4 fue
> `APPROVED WITH EXCEPTIONS` pero solo grepeó el QML construido, **nunca lo
> cargó**: `nix flake check`/build no detectan errores de binding en QML.

Causa: el parche de iconos reales en `flake.nix` genera
`Image { … implicitWidth: …; implicitHeight: … }`. En Qt, `Image.implicitWidth/Height`
son **read-only** (dependen de `sourceSize`).

Fix (2 líneas en `flake.nix`, bloque del `substituteInPlace` de iconos reales):
sustituir las dos líneas `implicitWidth`/`implicitHeight` por
```qml
                                sourceSize: Qt.size(Math.round(Tokens.font.icon.small.pointSize * 1.33), Math.round(Tokens.font.icon.small.pointSize * 1.33))
```
Tras el fix y rebuild: `~/.config/hypr/scripts/caelestia-restart.sh` y verificar
que la shell carga (sin `Failed to load configuration`).

**Lección (obligatoria para toda ola con parches QML)**: el gate de auditoría
debe incluir un **smoke test de carga del shell**:
`pkill -f 'quickshell.*caelestia-shell'; caelestia shell -d 2>&1 | grep -qi 'Failed to load configuration' && FAIL`.
Actualizado en `.workflow/audit-checklist.md`.

---

## Wave 4 (current) — logo azul, notificaciones nativas, mpvpaper dedupe, espejo con 2+ monitores

Tres ejecutores, archivos disjuntos. Nadie toca `flake.lock`.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `flake.nix` | executor-1 |
| `modules/desktop/hyprland-home.nix` | executor-2 |
| `modules/desktop/caelestia.nix` | executor-3 |

### Tasks

- [ ] T1 (flake.nix, parches QML del overlay): **logo NixOS azul real**
      (`OsIcon.qml` recolorea con `m3tertiary`; usar `#5277c3`); **notificaciones
      nativas** (re-anclar/re-estilizar `Toasts` arriba-derecha y estilo de
      `notifications/Notification.qml`, que arrastra caps lock/num lock);
      **iconos reales** de apps en `Workspace.qml`; **animación del indicador**
      (`workspace-bounce` de Wayle) → brief: `.workflow/briefs/wave4-executor-1.md`
- [ ] T2 (hyprland-home.nix): quitar el auto-espejo de
      `hl.on("monitor.added", … mirror)` (causa las "pantallas locas" al
      arrancar); `monitor-mirror.sh` no-op con <2 salidas físicas;
      dedupe/simplificar mpvpaper (`wallpaper-set.sh` solo lanza el fondo;
      `caelestia-wallpaper.sh` idempotente); helper `caelestia-restart.sh`
      → brief: `.workflow/briefs/wave4-executor-2.md`
- [ ] T3 (caelestia.nix): acción de launcher `Cyberpunk` que re-aplica
      `caelestia scheme set -n cyberpunk` (el humano cambió el esquema por
      accidente y quiere un regreso de un clic) → brief:
      `.workflow/briefs/wave4-executor-3.md`

### Integration plan

- Orden de merge: executor-2 (scripts) → executor-1 (QML) → executor-3
  (launcher). Disjuntos.
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel
  ```
- Pasos del humano: `sudo nixos-rebuild switch --flake .#pc`, luego:
  1. `caelestia-restart.sh` (o `pkill -f 'quickshell.*caelestia-shell'; caelestia shell -d`) — **la shell en runtime es una instancia vieja del store anterior; hasta reiniciarla, el IPC (SUPER+L, lock, etc.) falla con exit 255**.
  2. `hyprctl output remove HEADLESS-TABLET` (resto del cast) y `hyprctl reload`.
  3. `caelestia scheme set -n cyberpunk` (quedó en `dynamic` por el cambio manual).

### Audit gate

- Auditor: `nix flake check`; diff = solo los 3 archivos del mapa; `OsIcon.qml`
  sin `m3tertiary`; `monitor.added` sin auto-`mirror`; un solo `mpvpaper` tras
  cambiar wallpaper; `HEADLESS` excluido de `monitor-mirror.sh`; verify de cada
  brief.

---

## Wave 5 (current) — color del icono activo + migración a kitty

Cuatro ejecutores, archivos disjuntos. Nadie toca `flake.lock`.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `flake.nix` | executor-1 |
| `modules/apps/kitty.nix` (nuevo) + `home/default.nix` | executor-2 |
| `modules/apps/shell.nix` | executor-3 |
| `modules/desktop/hyprland-home.nix` + `modules/desktop/caelestia.nix` | executor-4 |

### Tasks

- [ ] T1: (flake.nix) **fix del color del icono en el workspace activo**: el
      `Colouriser` de `ActiveIndicator.qml` aplana todo el contenido del mask a
      `m3onPrimary`, así que el icono real pierde su color. Parchear el
      `Colouriser` con `colorization: 0` y `brightness: 0` (sigue redibujando el
      mask sobre la píldora, pero sin recolorear). → brief:
      `.workflow/briefs/wave5-executor-1.md`
- [ ] T2: (kitty) nuevo `modules/apps/kitty.nix` + import en `home/default.nix`:
      paleta cyberpunk, fondo translúcido (~0.66), JetBrains Mono Nerd Font,
      `cursor_trail`/`cursor_trail_decay` para el smear. wezterm se queda
      instalado como fallback. → brief: `.workflow/briefs/wave5-executor-2.md`
- [ ] T3: (shell.nix) migrar `dev()`, `hyprdev()` y `netrunner()` de wezterm a
      kitty (`kitty @ launch`): hyprdev con la geometría pedida (opencode
      arriba-derecha ~75%×65%, nvim arriba-izquierda, pipes-rs abajo-izquierda,
      libre abajo-derecha) con fallback a 4 ventanas tileadas; netrunner
      autónomo (btop+nvtop, flotante). → brief:
      `.workflow/briefs/wave5-executor-3.md`
- [ ] T4: (binds + terminal) `SUPER+Backspace`/`SUPER+N`/`time-to-work.sh` →
      kitty; window rule de vidrio para `class = "kitty"`; `general.apps.terminal
      = [ "kitty" ]`. → brief: `.workflow/briefs/wave5-executor-4.md`

### Integration plan

- Orden de merge: executor-2 (config kitty) → executor-3 (funciones) →
  executor-4 (binds/terminal) → executor-1 (icon fix, independiente).
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel
  ```
- Pasos del humano: `sudo nixos-rebuild switch --flake .#pc`,
  `~/.config/hypr/scripts/caelestia-restart.sh`, y borrar
  `~/.config/caelestia/shell.json` (para adoptar `terminal = kitty`). Probar
  `hyprdev`, `SUPER+N`, `SUPER+Backspace`, el smear y el color del icono activo.

### Audit gate

- `nix flake check`; diff = los archivos del mapa; **smoke test de carga de la
  shell (obligatorio: la ola toca QML, ver `audit-checklist.md`)**; kitty
  presente en `general.apps.terminal`; sin `wezterm` en binds/scripts (salvo
  `modules/apps/wezterm.nix`); verify de cada brief.

## Wave 6 (current) — kitty independiente, bolita del logo, MPRIS falso de Mixxx

Cinco ejecutores, archivos disjuntos. Nadie toca `flake.lock`.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `modules/apps/shell.nix` | executor-1 |
| `modules/desktop/hyprland-home.nix` + `modules/desktop/caelestia.nix` | executor-2 |
| `flake.nix` | executor-3 |
| `modules/apps/mixxx-mpris.nix` (nuevo) + `home/default.nix` | executor-4 |
| `modules/apps/kitty.nix` + `assets/kitty-cyberpunk.conf` (nuevo) | executor-5 |
| `modules/apps/neovim.nix` + `assets/nvim/NeoCyberVim/**` (nuevo) | executor-6 |

### Tasks

- [ ] T1 (shell.nix): **revertir los splits de kitty**. `hyprdev` debe lanzar
      **4 ventanas kitty independientes** (nvim, opencode, free, pipes-rs),
      tileadas por Hyprland (así se ve el wallpaper por los gaps); `netrunner`
      **2 ventanas independientes** (btop, nvtop), flotantes. Sin `kitty @
      launch --location`. Clase por defecto (`kitty`) para que el dedupe de
      Caelestia las colapse a UN icono. → brief: `.workflow/briefs/wave6-executor-1.md`
- [ ] T2 (hyprland-home.nix + caelestia.nix): bind `SUPER+N` → `zsh -ic
      netrunner`; quitar la window rule `netrunner-float`; `defaultPlayer =
      "Mixxx"`; **cliphist a 20 items**; **`caelestia-restart.sh` self-heal**
      (si falta `shell.json`, copiarlo de `~/.config/caelestia/shell.default.json`)
      y exponer ese default con `xdg.configFile."caelestia/shell.default.json".source
      = shellJsonPath`. → brief: `.workflow/briefs/wave6-executor-2.md`
- [ ] T3 (flake.nix): **bolita de relleno tras el logo Nix** del bar (el
      snowflake "casi no se ve"): en `OsIcon.qml`, círculo de fondo
      (`Rectangle`, `radius = width/2`, color `m3surfaceContainerHigh`) detrás
      del icono. → brief: `.workflow/briefs/wave6-executor-3.md`
- [ ] T4 (nuevo `mixxx-mpris`): **MPRIS falso de Mixxx** (el "engaño"). Servicio
      de usuario que publica `org.mpris.MediaPlayer2.mixxx` para que Caelestia
      muestre el logo de Mixxx + bongocat cuando suene audio de Mixxx. Detecta si
      hay un stream de Mixxx sonando (`pw-dump`, solo lectura) y ajusta
      `PlaybackStatus`; `Metadata` con `mpris:artUrl` = icono de Mixxx. → brief:
      `.workflow/briefs/wave6-executor-4.md`
- [ ] T5 (kitty.nix + asset): **tema `kitty-cyberpunk`** de
      johndrews (vendorizado como `assets/kitty-cyberpunk.conf`, MIT, con
      atribución) incluido con `include` en `extraConfig`; **keybindings de
      kitty** para usarlo como su wezterm: `ctrl+page_up/down` →
      `previous_window`/`next_window`, `ctrl+shift+alt+percent` →
      `launch --location=vsplit --cwd=current`, `ctrl+shift+alt+quotedbl` →
      `launch --location=hsplit --cwd=current`, `enabled_layouts = "splits"`.
      → brief: `.workflow/briefs/wave6-executor-5.md`
- [ ] T6 (neovim.nix + asset): **vendorizar NeoCyberVim** para que el tema no
      dependa de GitHub. Clonar `DonJulve/NeoCyberVim` dentro de
      `assets/nvim/NeoCyberVim/` (sin `.git`), y en `modules/apps/neovim.nix`
      cargar el plugin desde esa ruta (`dir = "${../../assets/nvim/NeoCyberVim}"`
      en el spec de Lazy) en vez del repo de GitHub, conservando
      `theme = "NeoCyberVim"` y `opts = { transparent = true }`. Deja un
      comentario con el upstream y la licencia. → brief:
      `.workflow/briefs/wave6-executor-6.md`

### Integration plan

- Orden: executor-1 (funciones) → executor-2 (reglas/restart) → executor-3 (QML)
  → executor-4 (servicio MPRIS) → executor-5 (kitty keys/tema) → executor-6
  (vendor NeoCyberVim). Disjuntos.
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel
  ```
- Pasos del humano: `sudo nixos-rebuild switch --flake .#pc`,
  `~/.config/hypr/scripts/caelestia-restart.sh` (ya self-healing). Probar
  `hyprdev` (4 ventanas independientes + 1 icono), `SUPER+N`, el logo con la
  bolita, las keybinds de kitty, y con Mixxx sonando el logo + bongocat.

### Audit gate

- `nix flake check`; diff = archivos del mapa; sin `--location=` en `shell.nix`
  (no splits); **smoke test de carga de shell** (toca QML); el servicio MPRIS
  registra el bus (`busctl --user list | grep mixxx`) sin Mixxx abierto no debe
  romper; verify de cada brief.

## Wave 7 — Mixxx MPRIS real (DESCARTADO)

El humano descartó el soporte MPRIS nativo real (evidencia del hallazgo #9).
La ola 6 implementa el "engaño" que él mismo pidió.

---

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-09-20 | Proyecto nuevo (personalización Caelestia); el plan de ollama/vídeo se archiva en `.workflow/plan-archive-ollama-video.md` | El proyecto anterior está cerrado; el plan rodante pasa a este |
| 2026-09-20 | #9 Mixxx: NO construir bridge MPRIS; recomendar descartar | Verificado: Mixxx 2.5.6 no expone MPRIS (sin bus name, sin strings) y no hay bridge mantenido |
| 2026-09-20 | #8 y #12 se arreglan con la sintaxis correcta de IPC (`caelestia shell <target> <func>`, no `ipc call`) | El subcomando `ipc call` del CLI duplica el prefijo y da "Target not found" |
| 2026-09-20 | #4 paleta: esquema `cyberpunk` por overlay a `caelestia-cli` (no se puede escribir un esquema de usuario) | `scheme_data_dir` vive read-only dentro del paquete |
| 2026-09-20 | #13: sin auto-lock; watchdog que suspende si la sesión lleva 5 min bloqueada | Caelestia no soporta timeouts condicionados al lock |
| 2026-09-20 | #13: `pc`/`laptop` no tienen swap en disco (solo zram); el humano ACEPTA `suspend` puro y NO quiere swap | Verificado: `swapDevices = []` + `zramSwap` en `amd-common.nix`. El watchdog usa `systemctl suspend` |
| 2026-09-20 | #9 Mixxx: DESCARTADO definitivamente por el humano | No hay MPRIS ni bridge; no se construye |
| 2026-09-20 | #6 kitty: MIGRAR (confirmado). Requisitos: tema cyberpunk, `cursor_trail` (smear), hyprdev con geometría fija vía splits de kitty, SUPER+N autónomo; fallback = comportarse como wezterm | Recuperado el palette de Wayle y `workspace-bounce`; kitty soporta cursor trail nativo y splits con `--bias` |
| 2026-09-20 | #2 notificaciones: TODO debe verse como notificación nativa de Caelestia. Toasts re-posicionados/re-estilizados arriba-derecha; kb layout pasa a `notify-send` real; caps/num lock se quedan como toast re-posicionado (viven en C++) | No hay fuente de evento externa para caps lock; el resto se puede hacer nativo |
| 2026-09-20 | #5: el humano borra `~/.config/caelestia/shell.json` para adoptar el seed (solo tenía tema + Celsius). Se fuerzan `useFahrenheit=false` y `useFahrenheitPerformance=false` | Defaults por locale podían quedar en imperial |
| 2026-09-20 | **F1 (auditoría ola 1)**: el esquema va en `schemes/cyberpunk/default/dark.txt`, no `cyberpunk/dark.txt`; verify fuerte (ejecutar `caelestia scheme list`), no `ls` | `get_scheme_flavours()` lista directorios; sin `default/` da `IndexError` |
| 2026-09-20 | **F2**: quitar el `\|\| true` del `scheme set -n cyberpunk` en `wallpaper-set.sh` | Enmascaraba F1 en runtime |
| 2026-09-20 | Monitor: catch-all a `mode = "highrr"` y borrar el rule muerto `DP-1 @170`; el monitor real es `HDMI-A-2` @100 | `hyprctl monitors`: 60 Hz actual, 100 Hz disponible |
| 2026-09-20 | Animaciones de workspace: se restauran con bounce suave + script de prueba en vivo (Hyprland, no Caelestia) | El humano quiere probar los estilos y elegir; la barra solo da `activeTrail`/morph |
| 2026-09-20 | #6 neovim: tema `NeoCyberVim` (DonJulve) reemplaza a `cyberneon` | Petición del humano |
| 2026-09-20 | P3 (auditoría): audits/briefs del proyecto viejo renombrados a `ollama-*` | Evitar colisión de nombres con las olas 2/3 de este proyecto |
| 2026-09-20 | Reproducibilidad: la config es igual en `pc`/`laptop`/`vm` (importan caelestia + hyprland); `server` no. El estado aplicado del esquema se automatiza con un activation idempotente | El seed de `shell.json` y los esquemas son estado de usuario |
| 2026-09-20 | Ola 2: `audited · APPROVED` (`.workflow/audits/wave2.md`); F1 cerrado. H1–H4 informativos | `nix flake check` completo + los 4 verify + reproducción en vivo |
| 2026-09-20 | Desviación de executor-4 ACEPTADA: en módulos **system-side** no existe `lib.hm`; el activation usa `{ after; before; data; }` (forma de `caelestiaSeedConfig`) | `modules/desktop/caelestia.nix` recibe el `lib` plano de nixpkgs |
| 2026-09-20 | Animación de workspace DEFINITIVA: `style = "slidefadevert"`, `bezier = "overshot"` | El humano la eligió probando con `SUPER+ALT+A` |
| 2026-09-20 | Quitar TODO el cast por VNC (`wayvnc`, `cast-tablet`, sus binds y el import); se queda Miracast/gnome-network-displays. `SUPER+D` = toggle espejo/extender | El humano no usa el cast VNC; causaba el bug de espejo (el físico espejaba la salida headless) |
| 2026-09-20 | `monitor-mirror.sh`: elegir el primario por monitor **enfocado**, no por área×Hz, y saltar salidas `HEADLESS-*` | La salida headless 1920x1200 ganaba en área y el físico terminaba espejándola |
| 2026-09-20 | Neovim: `opts = { transparent = true }` en NeoCyberVim | El fondo del tema opacaba el texto sobre la terminal translúcida |
| 2026-09-20 | OSD "monita" = `paths.mediaGif` (bongocat) en el dashboard media; reemplazable por otro GIF. Pendiente: el humano elige el asset | `modules/dashboard/dash/Media.qml` usa `Config.paths.mediaGif` |
| 2026-09-20 | Ola 3: integrada **sin auditar**, excepción explícita autorizada por el humano ("avanzar más rápido") | Verificado en árbol por el planner; riesgo de no tener evidencia de `nix flake check` aceptado |
| 2026-09-20 | Logo del bar: `OsIcon.qml` recolorea el PNG NixOS a `m3tertiary`; se parchea a `#5277c3` (azul NixOS) | El humano lo quiere con su color original |
| 2026-09-20 | SUPER+L roto = shell vieja en runtime (config `5m8m…` vs binario nuevo `vbcm3v0…`); fix = reiniciar la shell, no el código | `caelestia shell lock …` → exit 255 "No running instances" |
| 2026-09-20 | mpvpaper duplicado: simplificar `wallpaper-set.sh` (solo fondo) + idempotencia en `caelestia-wallpaper.sh` | 3 postHooks por cambio de wallpaper + `pkill` que perdía la carrera |
| 2026-09-20 | Quitar el auto-espejo de `monitor.added`; `monitor-mirror.sh` no-op con <2 salidas físicas | Al arrancar espejaba todo y volvía locas las pantallas |
| 2026-09-20 | Acción de launcher `Cyberpunk` para restaurar el esquema tras un cambio accidental | El humano cambió a `dynamic` desde `>scheme` |
| 2026-09-20 | Ola 4 integrada: merges `3a2341a`, `2b2b77b`, `0d4a44c` en `main`; `nix flake check` + build del toplevel de `pc` pasan | Integración limpia (archivos disjuntos); pendiente auditoría |
| 2026-09-20 | Ola 4 auditada: APPROVED WITH EXCEPTIONS (`.workflow/audits/wave4.md`), excepción = validación visual del humano | Build/integridad/disciplina OK |
| 2026-09-20 | **F3**: el parche de iconos reales usó `Image.implicitWidth/Height` (read-only) → la shell NO carga. Hotfix: `sourceSize: Qt.size(N,N)` | La auditoría solo grepeó el QML construido; nunca lo cargó. Se añade smoke test de carga al checklist |
| 2026-09-20 | Fix F3 aplicado (`694b588`), shell verificada arriba. Ola 5 arranca: color del icono activo + kitty | El `Colouriser` de `ActiveIndicator.qml` aplana los iconos reales; se apaga la colorización |
| 2026-09-20 | `caelestia-restart.sh` re-siembra `shell.json` desde `shell.default.json` si falta; se expone el seed como `xdg.configFile` | Borrar `shell.json` + restart sin rebuild dejaba la shell en defaults (sin blur/cava/launcher) |
| 2026-09-20 | cliphist `max-items` 6 → 20 | El humano perdió contexto con solo 6 |
| 2026-09-20 | Temas vendorizados en el repo: `assets/kitty-cyberpunk.conf` y `assets/nvim/NeoCyberVim/` | El humano teme que upstream borre los repos; el repo debe ser reproducible sin depender de GitHub |
| 2026-09-20 | Kitty: tema `johndrews/kitty-cyberpunk` + keybinds wezterm-like (`ctrl+page_up/down`, splits `ctrl+shift+alt+percent/quotedbl`) | Reproducible sin fetch en runtime; el tema es MIT |
| 2026-09-20 | MPRIS falso de Mixxx es SOLO lectura (`pw-dump`) para lo visual; NO se enruta audio ni se parchea Mixxx | El humano quiere solo el logo + bongocat, sin control |
