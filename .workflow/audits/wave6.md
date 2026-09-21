# Audit — Wave 6 (kitty independiente, bolita del logo, MPRIS falso de Mixxx)

> Auditor: sesión fresca, árbol integrado `main` @ `da6892d`. Evidencia = comandos
> ejecutados en esta sesión; sin comando, el check no cuenta.
>
> Wave 6: T1 `modules/apps/shell.nix` (executor-1), T2 `hyprland-home.nix` +
> `caelestia.nix` (executor-2), T3 `flake.nix` (executor-3), T4
> `modules/apps/mixxx-mpris.nix` + `home/default.nix` (executor-4), T5
> `kitty.nix` + `assets/kitty-cyberpunk.conf` (executor-5), T6 `neovim.nix` +
> `assets/nvim/NeoCyberVim/**` (executor-6).
>
> La ola toca QML del overlay (`OsIcon.qml` en `flake.nix`) → smoke test de carga
> obligatorio.

## Verdict

**APPROVED WITH EXCEPTIONS** — integridad, `nix flake check` completo, build del
toplevel, disciplina ponytail, seguridad y smoke test de carga pasan. Los 6
verify se corrieron; **5 pasan** y **el verify del brief 4 es inválido de origen**
(referencia a un path que no existe en este Home Manager) — el feature en cambio
está correcto y verificado en runtime. Excepción E1 abajo; no bloquea nada.

## 1. Integration integrity

- [x] Ramas mergeadas: `git merge-base --is-ancestor origin/wave6-executor-N main`
      → `MERGED` para N=1..6. Merges en `main`: `ae408a3`, `5f5f66d`, `bc0dbd5`,
      `65a8ffa`, `fb8d11b`, `da6892d`.
- [x] `git status --porcelain` → vacío; `git stash list` → vacío.
- [x] `main == origin/main`: `git rev-parse main origin/main` → ambos
      `da6892d4cf255df0dc5f988a87fad4eb9252bd76`; `git rev-list --left-right
      --count origin/main...main` → `0	0`.
- [x] Ownership map respetado — `git diff --stat fd91089 origin/wave6-executor-N`:
  - executor-1 → solo `modules/apps/shell.nix` (+33 −90).
  - executor-2 → `modules/desktop/caelestia.nix` (+12 −1),
    `modules/desktop/hyprland-home.nix` (+27 −9).
  - executor-3 → solo `flake.nix` (+22).
  - executor-4 → `home/default.nix` (+1), `modules/apps/mixxx-mpris.nix` (+231).
  - executor-5 → `assets/kitty-cyberpunk.conf` (+75), `modules/apps/kitty.nix`
    (+12 −23).
  - executor-6 → `modules/apps/neovim.nix` (+9 −5),
    `assets/nvim/NeoCyberVim/**` (15 archivos).
  Ningún archivo fuera del mapa; ningún archivo del mapa quedó sin tocar.
- [x] `flake.lock` intacto: `git diff --name-only fd91089..main -- flake.lock` →
      vacío.
- [x] Ramas remotas empujadas con el SHA del commit de la ola:
      `git ls-remote --heads origin 'wave6-executor-*'` → 6 ramas
      (`aba7c34`, `7a846df`, `1fe1d42`, `9418594`, `866fae`, `f3f2e5a`).
- [x] Sin marcadores de conflicto (`^<<<<<<<`/`^>>>>>>>`) en los archivos de la ola.

## 2. Build & tests

- [x] `nix flake check` (completo, con build) → `all checks passed!` (exit 0).
- [x] `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel`
      → exit 0.
- [x] **Smoke test de carga de shell → PASS.** La shell construida desde `main`
      es `nix build --no-link --print-out-paths
      '.#nixosConfigurations.pc.pkgs.caelestia-shell'` →
      `/nix/store/5j66h26l4f98nm0vayxldxgal9hvzhs4-caelestia-shell-2.4.0`, que es
      **exactamente la que corría en runtime**. Al matarla y relanzar con
      `caelestia shell -d`, el log dice `Configuration Loaded`; sin
      `Failed to load configuration`; sin errores de `OsIcon`/`Rectangle`/
      `Cannot assign`/`read-only`. (Detalle de método: invocar `quickshell -p`
      crudo da `module "Caelestia.Config" is not installed` — falso negativo; el
      test válido es `caelestia shell -d`, ya anotado en `wave5.md`.)
- [x] `OsIcon.qml` del store construido contiene la bolita (patch T3):
      `25: implicitWidth: root.height`, `26: implicitHeight: root.height`,
      `27: radius: width / 2`, `28: color: Colours.palette.m3surfaceContainerHigh`,
      seguida del `Loader` original.
- [x] Verify T1 → PASS: en `zsh.initContent` no hay `--location=` ni `kitty @`
      (grep vacío) y sí hay `kitty`; `netrunner()` y `hyprdev()` definidos (sin
      `dev()`).
- [x] Verify T2 → PASS: `zsh -ic netrunner` presente, `netrunner-float` ausente,
      `cliphist/config` → `max-items 20`, `caelestia-restart.sh` contiene
      `shell.default.json`, `shellJsonPath` → `.services.defaultPlayer ==
      "Mixxx"`.
- [x] Verify T3 → PASS (build + `grep 'radius: width / 2'`).
- [ ] **Verify T4 → FAIL por comando inválido, feature OK.** Ver E1.
- [x] Verify T5 → PASS: `keybindings` con `ctrl+page_up/down` y
      `ctrl+shift+alt+percent/quotedbl`; `settings.enabled_layouts == "splits"`;
      el `extraConfig` termina en `include /nix/store/…-kitty-cyberpunk.conf`; las
      claves de `settings` ya no incluyen `background`/`foreground`/`colorN`/
      `cursor`/`selection_*`.
- [x] Verify T6 → PASS: existe `colors/NeoCyberVim.lua`, no hay
      `assets/nvim/NeoCyberVim/.git`, y `theme.lua` carga
      `dir = "/nix/store/…-NeoCyberVim"` con `name = "NeoCyberVim"` y
      `opts = { transparent = true }`.

### Mecanismo runtime validado (evidencia adicional)

- [x] `hyprctl -j clients` emite `"class": "kitty"` (con espacio) → el poll
      `grep -c '"class": "kitty"'` de `hyprdev()` casa (contó 2 ventanas kitty en
      la sesión). El poll usa `want = base + 4`.
- [x] `shell.nix`: `netrunner` lanza 2 `setsid kitty …` (btop, nvtop); `hyprdev`
      lanza 4 (nvim, opencode, libres, pipes-rs); sin `$KITTY_WINDOW_ID`.
- [x] MPRIS falso vivo: `systemctl --user status mixxx-mpris` → `active
      (running)`, `ExecStart=/nix/store/27bx…-mixxx-mpris/bin/mixxx-mpris`;
      `busctl --user list | grep mixxx` → `org.mpris.MediaPlayer2.mixxx`;
      `get-property … PlaybackStatus` → `"Playing"`; `Metadata` →
      `mpris:trackid /org/mpris/MediaPlayer2/mixxx`, `xesam:title "Mixxx"`,
      `mpris:artUrl file:///run/current-system/sw/share/icons/hicolor/256x256/apps/mixxx.png`
      (ruta existe → symlink al store de mixxx).
- [x] `~/.config/caelestia/shell.default.json` existe (symlink a
      `home-manager-files`); `~/.config/hypr/scripts/caelestia-restart.sh` en
      runtime contiene el self-heal (`shell.default.json`).

## 3. Scope discipline (ponytail)

- [x] Sin dependencias nuevas más allá de las pedidas: `pydbus`/`pygobject3` +
      `writers.writePython3Bin` (todo del brief); assets vendorizados (sin
      `fetchurl` en runtime); `flake.lock` sin cambios.
- [x] Diffs mínimos: T1 es **neto −57** (borra el aparato de splits y el
      fallback); T5 **neto −11** (quita los 16 colores duplicados de `settings`);
      T2 +29 −9; T3 +22 (extiende el overlay existente).
- [x] `ponytail:` presente donde toca: `mixxx-mpris.nix` documenta el techo
      (heurística PipeWire, sin metadatos de pista, métodos no-op).
- [x] El módulo MPRIS (231 líneas) es lo pedido por el brief (introspección
      D-Bus explícita para pydbus); no hay abstracción extra.

## 4. Security

Auditoría ligera (el plan declara que esto NO se distribuye; sin `security-audit`).

- [x] Sin secretos commiteados: scan de
      `BEGIN … PRIVATE KEY|api[_-]?key|secret|token|password` sobre los 26
      archivos de la ola → sin coincidencias.
- [x] Trust boundary: el único dato externo nuevo es `pw-dump` (JSON de PipeWire,
      solo lectura) en `mixxx-mpris`; el parseo está envuelto en `try/except` y el
      peor caso es `[]` → `Stopped`. Los scripts de shell tratan `$1` como
      directorio opcional.
- [x] Licencias: `assets/kitty-cyberpunk.conf` trae cabecera `license: MIT`;
      `assets/nvim/NeoCyberVim/LICENSE` = MIT. `pydbus` (LGPL-2.1) es dependencia
      de runtime, no se distribuye. Compatible con `LICENSE-SOFTWARE`.
- [x] Asset vendorizado fiel: `assets/kitty-cyberpunk.conf` (75 líneas) es
      **byte-idéntico** al `cyberpunk.conf` de
      `johndrews/kitty-cyberpunk@main` (traído y comparado en esta sesión).

## 5. Handoff

- [x] Este informe escrito en `.workflow/audits/wave6.md`.
- [ ] Decision log de `plan.md` + re-planificación → a cargo del planner (el
      auditor no escribe fuera de `.workflow/audits/`).
- [ ] Validación visual por V (bolita del logo, 4 ventanas de `hyprdev` con
      gaps, keybinds de kitty, logo+bongocat con Mixxx sonando).

## Findings

- **E1 (excepción — verify del brief 4 inválido, owner: planner):** el comando de
  verificación usa `…systemd.user.services.mixxx-mpris.enable`, atributo que **no
  existe** en este Home Manager (los services exponen solo `Install`/`Service`/
  `Unit`; comprobado con el control `…services.mpd.enable` → mismo error), y el
  fallback `nix eval --raw …Service.ExecStart` falla porque `ExecStart` es una
  **lista** (`cannot coerce a list to a string`). Por tanto el verify **no puede
  pasar tal cual** y el ejecutor no pudo haberlo corrido. El feature sí está
  correcto: `nix eval --json …services.mixxx-mpris` muestra `ExecStart =
  ["/nix/store/…/bin/mixxx-mpris"]`, `Install.WantedBy =
  ["graphical-session.target"]`, y el servicio está vivo en runtime (ver §2).
  Acción: corregir el verify del brief (p.ej. `nix eval --json
  …services.mixxx-mpris.Service.ExecStart | jq -e '.[0] | test("mixxx-mpris")'`).
- **H1 (informativo):** el tema de kitty (`johndrews/kitty-cyberpunk`) trae una
  paleta distinta a la del esquema Wayle/Caelestia (`foreground #FF0055`,
  `background #120B10`). Es exactamente lo pedido en T5, pero conviene que V lo
  sepa: kitty ya no comparte la paleta `#0a0a12/#ff0066` del resto.
- **H2 (informativo):** comentario obsoleto en `modules/apps/kitty.nix:26-27`
  ("Control remoto … lo usa hyprdev") — tras T1 `hyprdev` ya no usa `kitty @`.
  El brief pedía conservar `allow_remote_control`, así que se deja; el comentario
  se puede actualizar en el próximo pase.
- **H3 (informativo):** el encabezado de la Wave 6 en `plan.md` dice "Cinco
  ejecutores" pero el mapa y las tareas listan **6**. Corregir al re-planificar.
- **H4 (informativo):** la rama "sin Mixxx → Stopped" de `mixxx-mpris` no se pudo
  probar en vivo (Mixxx estaba corriendo, PID `.mixxx-wrapped`); la rama con Mixxx
  sí (devuelve `Playing`). El camino sin nodos es trivial (`states == []` →
  `Stopped`) y el script publica el bus antes del primer poll.
- **H5 (informativo):** `dev()` se eliminó (permitido por el brief, punto 3); solo
  quedan `netrunner()` y `hyprdev()`.

## Nota para la ola siguiente

La ola 6 no tiene bloqueantes funcionales. Estado runtime confirmado: la shell
construida desde `main` (`5j66h26…`) es la que corre y carga; `mixxx-mpris` está
`active`; `shell.default.json` y el self-heal de `caelestia-restart.sh` están
aplicados. Lo único pendiente es (a) corregir el verify del brief 4 (E1), (b) la
validación visual de V, y (c) que el planner actualice el decision log y el
conteo de ejecutores (H3). La Wave 7 (Mixxx MPRIS real) está descartada.
