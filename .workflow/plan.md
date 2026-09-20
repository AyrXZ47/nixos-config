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
  `source: Config.paths.mediaGif` (hoy `assets/bongocat.gif`). Se puede cambiar
  por cualquier otro GIF/asset con `paths.mediaGif`; no hay opción de apagarlo
  sin parche. Pendiente: el humano elige el reemplazo.
- **Restart de Caelestia**: `caelestia shell -k` mata el shell y
  `caelestia shell -d` lo relanza (equivalente a `wayle panel restart`). El
  shell ya recarga `shell.json`/`scheme.json` en caliente, así que normalmente
  no hace falta reiniciar.

## Waves

| Wave | Focus | Status |
|------|-------|--------|
| 1 | Config Caelestia + bugs (SUPER+L, OSD brillo, idle/suspend, Celsius) + paleta cyberpunk | rejected (F1) → fixeada en ola 2 |
| 2 | Fix F1 (esquema) + monitor `highrr` + animaciones de workspace + NeoCyberVim + layout nativo | audited · APPROVED |
| 3 | Animación final (`slidefadevert`+`overshot`), fuera cast VNC, espejo arreglado, nvim transparente | planned |
| 4 | Parches QML del overlay: notificaciones nativas, iconos reales, animación del indicador | pending |
| 5 | Kitty (confirmado por el humano) + hyprdev/netrunner + limpieza | pending |
| 6 | Mixxx MPRIS — DESCARTADO por el humano (evidencia en hallazgo #9) | done |

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

## Wave 3 (current) — animación final, fuera VNC/cast, espejo arreglado, nvim transparente

Tres ejecutores, archivos disjuntos. Nadie toca `flake.lock`.

### File ownership map

| File/glob | Owner |
|-----------|-------|
| `modules/desktop/hyprland-home.nix` | executor-1 |
| `modules/apps/vnc.nix` (borrar) + `home/default.nix` | executor-2 |
| `modules/apps/neovim.nix` | executor-3 |

### Tasks

- [ ] T1: animación FINAL `slidefadevert` + `overshot`; quitar los binds de
      cast (`SUPER+ALT+D` / `SUPER+ALT+SHIFT+D`); bind `SUPER+D` (dejando
      `SUPER+SHIFT+D`) al toggle espejo/extender; arreglar el primario de
      `monitor-mirror.sh` (bug real: elegía por área×Hz y espejaba el monitor
      físico contra la salida headless del cast); allowlist de `style`/`curve`
      en `workspace-anim.sh` (H2) → brief: `.workflow/briefs/wave3-executor-1.md`
- [ ] T2: borrar `modules/apps/vnc.nix` y su import en `home/default.nix` (se
      retira TODO el cast por VNC; Miracast/gnome-network-displays se queda)
      → brief: `.workflow/briefs/wave3-executor-2.md`
- [ ] T3: neovim transparente — `opts = { transparent = true }` en NeoCyberVim
      → brief: `.workflow/briefs/wave3-executor-3.md`

### Integration plan

- Orden de merge: executor-1 (quita los binds a `cast-tablet`) → executor-2
  (borra el módulo) → executor-3. Disjuntos.
- Comandos en el árbol integrado:
  ```bash
  nix flake check
  nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel
  ```
- Pasos del humano: `sudo nixos-rebuild switch --flake .#pc`, luego
  **`hyprctl reload`** (el `highrr`/100 Hz solo aplica al recargar la config de
  Hyprland o al re-loguear) y cerrar la sesión de `wayvnc` si sigue viva
  (`pkill -x wayvnc`). Validar: `hyprctl monitors` → 100 Hz; `SUPER+D` alterna
  espejo/extender; `nvim` sin cuadro de fondo.

### Audit gate

- Auditor: `nix flake check`; diff = solo los 3 archivos del mapa
  (`home/default.nix` incluido); `cast-tablet`/`wayvnc` ausentes del árbol y de
  los binds; `monitor-mirror.sh` sin `max_by(... refreshRate)`; verify de cada
  brief.

---

## Wave 4 (next) — parches QML del overlay

> Gate: ola 2 integrada y auditada. Un solo ejecutor (`flake.nix`), porque los
> tres parches viven en el mismo overlay.

- **Notificaciones nativas (#2)**: el humano quiere que TODO se vea como
  notificación de Caelestia (arriba-derecha, estilo de
  `notifications/Content.qml`).
  - `Panels.qml`: re-anclar `Toasts.Toasts` a la zona superior derecha,
    apilados bajo las notificaciones.
  - `ToastItem.qml`: re-estilizar para que coincida con la tarjeta de
    notificación nativa.
  - Caps lock / num lock: viven en C++ (no hay fuente de evento externa) → se
    quedan como toast, pero re-posicionado/re-estilizado en la zona nativa.
- **Iconos reales de apps (#10)**: `Workspace.qml` usa `MaterialIcon` con
  `Icons.getAppCategoryIcon` (glifo monocromo). Parche para usar
  `Icons.getAppIcon` (icono real del `.desktop` vía `Quickshell.iconPath`) con
  `CachingIconImage`/`Image` de fallback al glifo.
- **Animación del indicador (#11b)**: portar el `workspace-bounce` de Wayle
  (recuperado del `styles/index.scss` de HM) al indicador/iconos de
  `Workspace.qml`, o exponer una curva más expresiva. Validar con el humano.

## Wave 5 — kitty (confirmado por el humano)

> Gate: ola 2 integrada. Un ejecutor (o dos: `modules/apps/kitty.nix` +
> `modules/apps/shell.nix`/`hyprland-home.nix`; a decidir al planificar la ola).

El humano ya decidió migrar de wezterm a kitty (2026-09-20). Alcance acordado:

- **Tema cyberpunk**: kitty acepta colores propios; generar una paleta a partir
  de `#0a0a12/#141428/#1e1e3a/#d4d4f0/#ff0066/#00aaff` (misma de Wayle),
  paridad con `color_scheme = "Cyberdyne"` de wezterm, fuente JetBrains Mono
  Nerd Font, fondo translúcido (~0.4 como wezterm o 0.66 como el resto) y
  `cursor_trail`/`cursor_trail_decay` para el **smear cursor** entre terminales
  (kitty lo trae nativo).
- **hyprdev con geometría fija**: hoy son 4 ventanas wezterm tileadas por
  dwindle. Con kitty se puede hacer UN panel con splits exactos vía
  `kitty @ launch --location=... --bias=N`: opencode arriba-derecha (~75%
  ancho × 65% alto), nvim arriba-izquierda, pipes-rs abajo-izquierda, terminal
  libre abajo-derecha. Fallback aceptado por el humano: comportarse como el
  wezterm actual (4 ventanas tileadas).
- **SUPER+N (netrunner)**: que lance sus terminales flotantes de forma
  autónoma, igual que hyprdev (hoy exige un `WEZTERM_PANE` activo).
- Actualizar `general.apps.terminal`, binds (`SUPER+Backspace`, `SUPER+N`) y los
  scripts que abren `wezterm`. Mover `programs.wezterm`/`hyprdev`/`netrunner` a
  kitty; decidir si se retira wezterm o se deja instalado.
- Limpieza final: retirar comentarios muertos de rofi, cerrar `#3/#5/#7/#8/#9/
  #12/#13` en el decision log.

## Wave 6 — Mixxx MPRIS (DESCARTADO)

El humano descartó el soporte de Mixxx en el menú de media (2026-09-20) tras
la evidencia del hallazgo #9: Mixxx 2.5.6 no expone MPRIS y no hay bridge
mantenido. No se planifica.

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
