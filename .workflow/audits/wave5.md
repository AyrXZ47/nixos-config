# Audit — Wave 5 (color del icono activo + migración a kitty)

> Auditor: sesión fresca, árbol integrado `main` @ `4aa711c`. Evidencia = comandos
> ejecutados en esta sesión; sin comando, el check no cuenta.
> Wave 5: T1 `flake.nix` (executor-1), T2 `modules/apps/kitty.nix` +
> `home/default.nix` (executor-2), T3 `modules/apps/shell.nix` (executor-3),
> T4 `modules/desktop/hyprland-home.nix` + `modules/desktop/caelestia.nix`
> (executor-4). La ola toca QML del overlay → smoke test de carga obligatorio.

## Verdict

**APPROVED WITH EXCEPTIONS** — build, integridad, disciplina, seguridad y los 4
verify pasan; el smoke test de carga de shell (el que faltó en la ola 4) **pasa**.
La única excepción es la validación visual/runtime por el humano (geometría real
de los splits de `hyprdev`/`dev`, `netrunner` flotante, smear del cursor, vidrio
de kitty, color del icono del workspace activo). Owner: V (próximo login). No
bloquea el arranque de la ola 6.

## 1. Integration integrity

- [x] Merges de la ola presentes en `main` (`git log --oneline --graph -25`):
  - `2fee094 merge: wave 5 wave5-executor-2`
  - `b023604 merge: wave 5 wave5-executor-3`
  - `72e5d1e merge: wave 5 wave5-executor-4`
  - `4aa711c merge: wave 5 wave5-executor-1`
- [x] `git status -sb` → `## main...origin/main`, limpio; `git stash list` vacío.
- [x] `main == origin/main`: `git rev-parse main origin/main` → ambos
      `4aa711c2069a7cc9ad14e7722d8706d9bcdfed8e`; `git rev-list --left-right
      --count origin/main...main` → `0	0`.
- [x] Ownership map respetado. `git diff --stat 2e03b0b..<rama>` por ejecutor:
  - `wave5-executor-1` → solo `flake.nix` (+10).
  - `wave5-executor-2` → `home/default.nix` (+1), `modules/apps/kitty.nix` (+50).
  - `wave5-executor-3` → solo `modules/apps/shell.nix` (+78 −105).
  - `wave5-executor-4` → `modules/desktop/caelestia.nix` (1), `modules/desktop/hyprland-home.nix` (+10 −3).
- [x] `flake.lock` intacto: `git diff --name-only 2e03b0b..main -- flake.lock` →
      vacío.
- [x] Ramas aisladas empujadas: `git ls-remote --heads origin` →
      `wave5-executor-{1,2,3,4}` con sus SHAs.
- [x] Sin marcadores de conflicto (`<<<<<<<`) en los archivos de la ola.

## 2. Build & tests

- [x] `nix flake check` (completo) → `all checks passed!` (exit 0).
- [x] `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel`
      → exit 0.
- [x] Verify T1 → `E1 PASS` (build `caelestia-shell` + `grep 'colorization: 0'`
      en `ActiveIndicator.qml`).
- [x] Verify T2 → `E2 PASS` (`programs.kitty.enable == true`; `settings` con
      `cursor_trail`, `background_opacity`, `allow_remote_control`).
- [x] Verify T3 → `E3 PASS` (`initContent` con `kitty @ launch`; sin
      `wezterm cli split-pane`).
- [x] Verify T4 → `E4 PASS` (`extraConfig` con `exec_cmd("kitty")` y
      `kitty-glass`; `shellJsonPath` → `.general.apps.terminal == ["kitty"]`).
- [x] **Smoke test de carga de shell (obligatorio) → PASS.**
      `pkill -x quickshell; caelestia shell -d` → log: `Configuration Loaded`,
      proceso `quickshell -p /nix/store/wdavf52…-caelestia-shell-2.4.0/share/caelestia-shell`
      vivo; `caelestia shell -l` sin `Failed to load configuration`.
- [x] Shell funcional por IPC: `caelestia shell drawers list` →
      `bar osd session launcher dashboard utilities sidebar`.

### Contenido real del shell construido (`wdavf52…-caelestia-shell-2.4.0`)

- [x] `ActiveIndicator.qml` → `55: colorizationColor: …m3onPrimary`,
      `56: colorization: 0`, `57: brightness: 0` (patch T1 aplicado; el
      redibujado del mask se conserva).
- [x] El store construido es exactamente el que corre en runtime
      (`readlink -f $(command -v caelestia-shell)` → `wdavf52…`); no hay shell
      vieja tras el merge.
- [x] Nota de método (F3): correr `quickshell -p <store>/share/caelestia-shell`
      crudo da `module "Caelestia.Config" is not installed` — falso negativo: el
      wrapper `caelestia-shell` inyecta `NIXPKGS_QT6_QML_IMPORT_PATH`
      (`caelestia-qml-plugin`, `caelestia-m3shapes`). El smoke test válido es
      `caelestia shell -d` + `caelestia shell -l` (o el wrapper), no `quickshell`
      a pelo. Conviene precisarlo en `audit-checklist.md`.

### Mecanismo runtime de kitty (validado en ventana efímera, se autocierra)

- [x] `kitty @ goto-layout --match "window_id:$KITTY_WINDOW_ID" splits` → OK.
- [x] `kitty @ launch --location=vsplit --bias=45 --next-to "id:N"` → OK.
- [x] `kitty @ launch --location=hsplit --bias=20 --next-to "id:N"` → OK.
- [x] `kitty @ send-text … 'line1\r'` → `cat` recibió `b'line1\n'` (el `\r` se
      interpreta como CR: el `'nvim\r'` de `dev()` funciona).
- [x] `kitty @ launch --type=os-window --var "hyprdev=TEST" …` +
      `kitty @ close-window --match "var:hyprdev=TEST"` → OK (fallback de
      `hyprdev` válido).
- [x] `kitty.conf` generado (`xdg.configFile."kitty/kitty.conf".source`): paleta
      16 colores, `background_opacity 0.66`, `cursor_trail 1`,
      `cursor_trail_decay 0.1 0.3`, `allow_remote_control yes`.

### Audit gate del plan (ola 5)

- [x] `general.apps.terminal = [ "kitty" ]` (`modules/desktop/caelestia.nix:68`).
- [x] Sin `wezterm` en binds/scripts: `grep -ri wezterm` fuera de
      `modules/apps/wezterm.nix` → solo comentarios y la regla `wezterm-glass`
      (que el brief pide conservar) + el regex de `windowIcons` en
      `caelestia.nix` (no es bind/script).
- [x] Sin `$WEZTERM_PANE` en el árbol (solo en briefs).

## 3. Scope discipline (ponytail)

- [x] Sin dependencias nuevas; `flake.lock` sin cambios. kitty es la dep pedida.
- [x] Sin abstracciones/boilerplate fuera de los briefs.
- [x] Diffs mínimos: T1 +10 líneas (extiende el overlay existente); T2 +50 (un
      módulo nuevo pedido); T3 **neto −27** (borra el watcher de wezterm y
      simplifica); T4 +10 −3.
- [x] Hunks de T3 confinados a `netrunner`/`dev`/`hyprdev` (líneas ~55–152); no
      toca `SecDesk`, `yt_url`, `estabilizar_clips`, etc.
- [x] No aplican `ponytail:` nuevos: el fallback de `hyprdev` y el cierre de
      sesión están documentados en comentarios.

## 4. Security

Auditoría ligera (el plan declara que esto NO se distribuye; sin `security-audit`).

- [x] Sin secretos commiteados: scan
      `password|secret|token|api[_-]?key|PRIVATE KEY|ghp_|sk-` en el diff de la
      ola → sin hallazgos.
- [x] Trust boundary: los cambios son config declarativa; los únicos datos
      externos son el directorio opcional de `dev`/`hyprdev` (`$1` → `cd "$repo"`,
      con `|| return 1`) y los ids de ventana de kitty (`$KITTY_WINDOW_ID`).
- [x] Sin licencias nuevas (sin deps nuevas).
- [x] `allow_remote_control = "yes"` es necesario para que `kitty @ launch`
      funcione desde las funciones zsh (programas que corren dentro de kitty);
      ver H5.

## 5. Handoff

- [x] Este informe escrito en `.workflow/audits/wave5.md`.
- [ ] Decision log de `plan.md` + re-planificación de la ola 6 → a cargo del
      planner (no del auditor). La ola 6 (Mixxx MPRIS) está DESCARTADA por el
      humano; la siguiente ola es re-planificación libre.
- [ ] Validación visual por V (excepción, ver H1).

## Findings

- **H1 (excepción — validación visual/runtime por V):** la geometría real de los
  4 splits de `hyprdev` (opencode ~75%×65%, nvim/pipes/free), el `netrunner`
  flotante, el smear del cursor, el vidrio de kitty y el color del icono del
  workspace activo son visuales. Se validó el **mecanismo** (API de kitty,
  `send-text \r`, `--var`, carga del shell), no el resultado en pantalla.
- **H2 (informativo):** `main` arrastra 4 commits de neovim (`6d2224c`, `d4606c6`,
  `933ed82`, `0f246f9`) entre el commit del plan de la ola 5 y los merges. No
  violan el ownership map (ninguna rama `wave5-executor-*` los toca); son trabajo
  directo en `main` fuera del flujo de la ola. El diff base→main los incluye.
- **H3 (informativo):** `windowIcons` en `caelestia.nix` no tiene entrada para
  `kitty` ni `netrunner`; dependen de `Icons.getAppIcon(clase)`. Bajo riesgo
  (kitty trae icono de tema) y el brief no lo pedía; revisar visualmente si el
  icono sale genérico.
- **H4 (informativo):** `dev()`/`hyprdev()` ahora cierran la ventana kitty que
  los invoca (`close-window --match id:$KITTY_WINDOW_ID`) y la sesión vive en la
  ventana nueva; desaparece el watcher de cierre en cadena del wezterm viejo.
  Cambio de comportamiento permitido por el brief y reportado por el ejecutor.
- **H5 (informativo):** `allow_remote_control = "yes"` deja que cualquier proceso
  local que alcance el socket controle kitty (`send-text`/`get-text`). Es el
  valor que exige el caso de uso (funciones que corren dentro de kitty); en una
  máquina monousuario el riesgo es bajo.

## Nota para la ola siguiente

La ola 5 queda aprobada con la única excepción de la validación visual de V.
Pasos de runtime del plan: `sudo nixos-rebuild switch --flake .#pc`,
`~/.config/hypr/scripts/caelestia-restart.sh`, borrar
`~/.config/caelestia/shell.json` (para adoptar `terminal = kitty`), y probar
`hyprdev`, `SUPER+N`, `SUPER+Backspace`, el smear y el color del icono activo.
La ola 6 (Mixxx MPRIS) está descartada; el planner decide la siguiente.
