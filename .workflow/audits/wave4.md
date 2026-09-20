# Audit — Wave 4 (logo azul, notificaciones nativas, mpvpaper dedupe, espejo, launcher Cyberpunk)

> Auditor: sesión fresca, árbol integrado `main` @ `0121b85`. Evidencia = comandos
> ejecutados en esta sesión; sin comando, el check no cuenta.
> Wave 4: T1 `flake.nix` (executor-1), T2 `modules/desktop/hyprland-home.nix`
> (executor-2), T3 `modules/desktop/caelestia.nix` (executor-3).

## Verdict

**APPROVED WITH EXCEPTIONS** — build/tests/integridad/disciplina OK. La única
excepción es validación visual en vivo por el humano (zona/estilo de
notificaciones, logo azul, feel del bounce) y la reproducción del gate
"un solo mpvpaper tras cambiar wallpaper", que no es verificable headless.
Owner de las excepciones: V (validación al próximo login). No bloquean el arranque
de la ola 5.

## 1. Integration integrity

- [x] Merges de la ola presentes en `main`:
  - `git log --oneline -6` →
    `0121b85 docs(plan): ola 4 integrada...`, `0d4a44c merge: wave 4 wave4-executor-3`,
    `2b2b77b merge: wave 4 wave4-executor-1`, `3a2341a merge: wave 4 wave4-executor-2`.
- [x] `git status -sb` → `## main...origin/main`, limpio; `git stash list` vacío.
- [x] `main == origin/main` (`git rev-parse HEAD origin/main` → ambos
      `0121b8560da5...`; `git rev-list --left-right --count` → `0 0`).
- [x] Ownership map respetado. Solo 4 archivos cambiados en el diff de la ola
      (`git diff --name-only d5cee23..0121b85`): `flake.nix`,
      `modules/desktop/hyprland-home.nix`, `modules/desktop/caelestia.nix`,
      `.workflow/plan.md` (plan/planner). `flake.lock` intacto.
  - `git diff --stat d5cee23..wave4-executor-1` → solo `flake.nix`.
  - `git diff --stat d5cee23..wave4-executor-2` → solo `modules/desktop/hyprland-home.nix`.
  - `git diff --stat d5cee23..wave4-executor-3` → solo `modules/desktop/caelestia.nix`.
- [x] Ramas aisladas empujadas: `git ls-remote --heads origin 'wave4*'` →
      `wave4-executor-1`, `-2`, `-3` presentes con sus SHAs.
- [x] Sin marcadores de conflicto (`grep '<<<<<<<'` en los 3 archivos → sin matches).

## 2. Build & tests

- [x] `nix flake check` → `all checks passed!` (exit 0).
- [x] `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel`
      → exit 0.
- [x] Verify T1 (`nix flake check --no-build` + build `caelestia-shell` + 3 greps)
      → `VERIFY1_EXIT:0`.
- [x] Verify T2 (eval extraConfig sin `monitor.added`; `monitor-mirror.sh` con
      `-lt 2`; `caelestia-wallpaper.sh` con `grep -qF`; `wallpaper-set.sh` sin
      `caelestia wallpaper`; `caelestia-restart.sh` con `pkill`) → `VERIFY2_EXIT:0`.
- [x] Verify T3 (`shellJsonPath` + `jq index("Cyberpunk") != null`) →
      `VERIFY3_EXIT:0`.

### Contenido real del shell construido (`a6bydz...-caelestia-shell-2.4.0`)

- [x] Logo: `grep 'colour:' OsIcon.qml` → `44: colour: "#5277c3"`; `m3tertiary`
      ya no aparece (0 matches).
- [x] Toasts arriba-derecha: `Panels.qml` → `140: anchors.top: notifications.bottom`
      / `141: anchors.right: parent.right` (bloque `Toasts.Toasts`). La 2ª
      coincidencia de `notifications.bottom` (150) es del bloque `Sidebar` y ya
      existía en el original (no es artefacto del parche).
- [x] Toast estilo nativo: `ToastItem.qml` → `26: return Colours.tPalette.m3surfaceContainer;`.
- [x] Iconos reales: `Workspace.qml` → `173: source: Icons.getAppIcon(...)`,
      `Image` con `PreserveAspectFit`; `getAppIcon` existe en `utils/Icons.qml:102`.
- [x] Bounce: `Workspace.qml` → `Connections` `onFocusedChanged` + `SequentialAnimation`
      `id: bounce` con `target: windows`; `id: windows` existe (Loader, línea 120),
      `root.focused` es propiedad real → referencias resueltas, no es código muerto.
- [x] Dedupe preservado: la clave del filtro pasó de `Icons.getAppCategoryIcon(...)`
      a `w.lastIpcObject.class` (brief lo permite explícitamente) y el `Repeater`
      sigue filtrando antes del `slice`.
- [x] `monitor-mirror.sh`: `HEADLESS` excluido (`select(.name | startswith("HEADLESS") | not)`)
      y guarda `<2` antes del branch `mirror`.
- [x] `wallpaper-set.sh`: solo guarda fuente + llama a `caelestia-wallpaper.sh`
      (sin `ffmpeg`, sin `caelestia wallpaper`, sin `scheme set`).
- [x] `caelestia-wallpaper.sh`: guarda de idempotencia
      `pgrep -af 'mpvpaper' | grep -qF -- "$wall"` antes del `pkill -x .mpvpaper-wrapp`.
- [x] `caelestia-restart.sh`: existe y contiene `pkill -f 'quickshell.*caelestia-shell'`
      + `caelestia shell -d`.

## 3. Scope discipline (ponytail)

- [x] Sin dependencias nuevas; `flake.lock` sin cambios.
- [x] Sin abstracciones/boilerplate fuera de los briefs. T3 = 6 líneas; T2 neto
      −15 líneas (borra más de lo que añade); T1 extiende el overlay existente.
- [x] `ponytail:` presente donde aplica (overlay de versión, primario de espejo,
      `caelestia-restart`); ninguno introduce un techo nuevo sin nombrarlo.
- [x] Diff mínimo que satisface las tareas.

## 4. Security

Auditoría ligera (el plan declara que esto NO se distribuye; sin `security-audit`).

- [x] Sin secretos commiteados: scan `api[_-]?key|secret|token|password|PRIVATE KEY`
      en `*.nix` → solo referencias a `_1password-cli`, `libsecret`, comentarios y
      `initialPassword` (esperado) — nada real.
- [x] Trust boundary: `wallpaper-set.sh`/`caelestia-wallpaper.sh` validan
      `[ -n "$f" ] && [ -f "$f" ]`; `monitor-mirror.sh` opera sobre JSON de
      `hyprctl`, no input externo.
- [x] Sin licencias nuevas (sin deps nuevas).

## 5. Handoff

- [x] Este informe escrito en `.workflow/audits/wave4.md`.
- [x] Decision log actualizado por el planner (entrada "Ola 4 integrada: merges...").
- [ ] Plan de la ola 5 detallado (rolling) — ya existe la sección Wave 5 (kitty,
      confirmado). Queda a cargo del planner tras este audit.

## Findings (informativos, no bloqueantes)

- **H1 (excepción — validación en vivo por V):** el gate "un solo `mpvpaper` tras
  cambiar wallpaper" solo se puede confirmar en runtime con sesión gráfica; aquí
  se valida la lógica (idempotencia + `pkill -x`), no el proceso vivo.
- **H2 (excepción — validación visual por V):** posición/estilo de toasts
  arriba-derecha, azul del logo, iconos reales y feel del bounce son visuales;
  build y referencias QML OK, pero la percepción final la valida V.
- **H3 (informativo):** la ola 3 sigue sin auditar (excepción autorizada). Este
  `nix flake check` + build del toplevel cubren retroactivamente su integridad de
  build; su validación visual sigue pendiente igual que H2.
- **H4 (informativo):** los worktrees `wave4-executor-*` no se retiraron (mismo
  residuo que en olas previas). No afecta al árbol integrado.
- **H5 (informativo):** `caelestia-restart.sh` hace `sleep 0.5` fijo antes de
  relanzar; si el proceso tarda más en morir, el nuevo shell podría fallar y hay
  que reintentar. `ponytail:` aceptable, no bloqueante.

## Nota para la ola siguiente

La ola 5 (kitty) puede arrancar. Pasos de runtime ya documentados en el plan
(Wave 4 "Pasos del humano"): `sudo nixos-rebuild switch --flake .#pc`,
`caelestia-restart.sh`, `hyprctl reload`, `caelestia scheme set -n cyberpunk`.
