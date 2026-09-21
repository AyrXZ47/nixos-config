# Auditoría — Ola 8 (hyprdev/netrunner kitty + emoji + bolita del logo)

- **Árbol auditado**: `main` @ `8cb26ea` (integrado; merges `eac1bb5`, `c25ad23`,
  `8cb26ea`).
- **Fecha**: 2026-09-20.
- **Alcance**: ola 8 (3 ejecutores) + ola 7 (pendiente, absorbida — ver §6).
- **Veredicto**: **APPROVED WITH EXCEPTIONS** (excepciones no bloqueantes, abajo).

Evidencia > narración: cada check es un comando ejecutado por el auditor sobre el
árbol integrado; se registra la salida.

---

## 1. Integridad de integración

- `git status --porcelain` → vacío (árbol limpio). `git stash list` → vacío.
- La ola 8 tocó **exactamente** los archivos del mapa de propiedad:

  ```
  $ git diff --name-only 9f43505..8cb26ea
  flake.nix
  modules/apps/kitty.nix
  modules/apps/shell.nix
  modules/desktop/hyprland-home.nix
  ```

  Mapa: `shell.nix` → E1; `kitty.nix` + `hyprland-home.nix` → E2; `flake.nix` → E3.
  Sin invasiones de territorio.
- `flake.lock` no tocado por la ola (`git diff --stat 9f43505..8cb26ea -- flake.lock`
  → vacío). Sin dependencias nuevas.
- Branch isolation OK: `git ls-remote --heads origin` contiene
  `wave8-executor-1/2/3` con los SHA de las ramas locales. Worktrees residuales:
  solo los de la ola 8.
- Todos los commits son conventional-commit en español, una línea.

## 2. Build & tests

| Check | Comando | Resultado |
|-------|---------|-----------|
| Flake check | `nix flake check` | `all checks passed!` (exit 0) |
| Toplevel pc | `nix build --no-link .#nixosConfigurations.pc.config.system.build.toplevel` | exit 0 |
| Verify E1 | `grep` sobre `...zsh.initContent` | sin `--cwd`; `exec btop` presente; `closewindow` **solo en un comentario** (ver E1) |
| Verify E2 | `nix eval --json ...kitty.settings \| jq -e '.symbol_map\|test("Noto Color Emoji")'` + grep comentario + grep bind | `true` / sin `lo usa hyprdev` / `zsh -ic netrunner` presente |
| Verify E3 | `grep` en `OsIcon.qml` construido | `Colours.tPalette.m3surfaceContainer` ✓ y `Tokens.sizes.bar.innerWidth` ✓ |
| Emoji | `fc-list \| grep -i 'color emoji'` | `Noto Color Emoji` instalada |

### Smoke test de carga de la shell (obligatorio: la ola toca QML)

```
$ caelestia shell -d   # tras reiniciar quickshell
INFO: Configuration Loaded
$ grep -i 'Failed to load configuration' /tmp/qs-start.log   # → sin coincidencias
$ caelestia shell drawers list   # → bar / osd / session
```

El store construido por el overlay (`xxdfj76…-caelestia-shell-2.4.0`) es **el
mismo** que ejecuta la shell viva; la shell arrancó y responde IPC. **PASS**.

### Verificación de mecanismos runtime de la ola 8

- **Cierre en cadena de `hyprdev`**: el watcher rastrea por título
  `hyprdev-<runid>-<rol>` vía `hyprctl -j clients`. Comprobado que `kitty -T`
  **conserva** el título incluso con `shell_integration = enabled` (dos ventanas
  de prueba, una con `sleep` y otra con `zsh` interactivo, mantuvieron
  `hyprdev-audit-*`; formato JSON `"title": "…"` confirmado). El mecanismo de
  rastreo es viable.
- **`netrunner` nvtop al lado**: `hyprctl dispatch 'hl.dsp.layout("preselect r")'`
  → `ok` (la forma Lua es válida en Hyprland 0.56.2 con la config actual).

## 3. Disciplina ponytail

- Sin dependencias nuevas, sin abstracciones ni boilerplate fuera de lo pedido;
  diffs mínimos (67/-30 en `shell.nix`, +6/-2, +2/-2).
- El código reutiliza patrones del repo (funciones zsh, parche QML por
  `substituteInPlace`, dispatch Lua) — sin capas nuevas.

### Hallazgo E1 (ola 8) — verify débil, no bloqueante

El verify del brief de E1 (`... | grep -q 'closewindow'`) pasa **por un
comentario**, no por el código: la línea 142 de `initContent` dice
"`hyprctl dispatch closewindow address:<a>` (legacy)…". El cierre en cadena real
se implementó con `kill` de los PID del `pidfile` + el PID de la invocadora. El
requisito **está** implementado (revisión de código + mecanismo de títulos
validado), pero el verify no lo probaría si el watcher desapareciera. Misma clase
de defecto que `E1` de la ola 6. **Excepción documentada**, no bloqueante.

## 4. Seguridad

- Sin secretos en el diff de la ola 8 (el único match de "token" es la palabra
  `Tokens` de QML).
- `initialPassword` (`modules/core/user.nix`) lee de
  `/etc/nixos-secrets/yovick-password` (solo root, no versionado); no hay
  credenciales en el repo (`git ls-files | grep -iE '\.env|credential|secret|\.pem|id_rsa'`
  → nada).
- Sin assets ni licencias nuevas en esta ola (el tema kitty MIT y NeoCyberVim ya
  venían de la ola 6). Release gate: no aplica (no se distribuye).

## 5. Findings informativos (H)

- **H1** — En cada arranque la shell emite
  `WARN caelestia.settings: Unknown option "bar.workspaces.workspaceIcons"`. El
  origen es el seed `modules/desktop/caelestia.nix:177` (`workspaceIcons = [ ]`),
  introducido por `a64bd5c` (ola anterior), **no** por la ola 8. La shell carga
  igual; opción ignorada. Recomendación: confirmar si debe ser `windowIcons` o
  eliminarla del seed.
- **H2** — El verify de la ola 7 E1 (`! grep -q 'kitty @' modules/apps/kitty.nix`)
  quedó **stale** tras la ola 8: el comentario reescrito ahora contiene el literal
  `` `kitty @` ``. No afecta funcionalidad (no hay uso activo de `kitty @`).
- **H3** — El smoke test del `audit-checklist.md` usa
  `pkill -f 'quickshell.*caelestia-shell'`, que se **auto-mata** si se ejecuta
  desde una shell cuya línea de comando contiene el patrón. Usar
  `pkill -f 'caelestia[-]shell'` o matar por PID.
- **H4** — Los worktrees de la ola 8 siguen presentes (patrón histórico ya
  reportado en la ola 2; no bloqueante).

## 6. Ola 7 (pendiente) — absorbida

La ola 7 no tenía auditoría. Sus dos commits están en `main` y **subsumidos** por
la ola 8:

- `3139acc` (`--cwd` → `-d`): reflejado en `shell.nix` actual (sin `--cwd`,
  `kitty -d` presente) y en `kitty.nix`.
- `525195a` (bolita: color `tPalette.m3surfaceContainer` + padding): el color
  sobrevive; el tamaño `root.height*1.6` fue reemplazado en la ola 8 por
  `Tokens.sizes.bar.innerWidth`.

Verify de la ola 7 sobre el árbol integrado: `W7-E2` pasa; `W7-E1` pasa salvo el
grep `'kitty @'` (H2). Se cierra la ola 7 como auditada (absorbida).

## 7. Excepciones (con owner)

| # | Excepción | Owner | Estado |
|---|-----------|-------|--------|
| E1 | Verify de E1 es un proxy débil (matchea comentario); el cierre en cadena está implementado | planner/executor | documentada, no bloqueante |
| E2 | Validación funcional en vivo de `hyprdev` (4 ventanas + cierre en cadena) y `netrunner` (nvtop al lado) por el humano | humano (V) | pendiente; no ejecutable por el auditor sin secuestrar su sesión (un `hyprdev` desde shell no-kitty haría `exec nvim` sobre la shell del auditor) |
| E3 | H1 (`workspaceIcons`), H2 (verify stale W7-E1) | planner | informativos, no bloqueantes |

## Veredicto

**APPROVED WITH EXCEPTIONS.** Build, integración, alcance, seguridad y smoke test
de carga de shell pasan; los mecanismos runtime de la ola 8 se validaron
empíricamente en lo posible sin interferir con la sesión del humano. Las
excepciones son la validación visual/funcional final (humano) y dos defectos de
calidad de verify/documentación, ninguno funcional.

## Handoff (para el planner)

- Registrar en el decision log de `.workflow/plan.md`: ola 8 auditada
  (APPROVED WITH EXCEPTIONS); ola 7 cerrada como absorbida.
- Endurecer el verify de `shell.nix` (E1) en la próxima ola que lo toque.
- Limpiar `workspaceIcons` del seed (`caelestia.nix:177`) y actualizar el
  `pkill` del `audit-checklist.md` (H3).
