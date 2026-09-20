# Brief: Wave 1 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Ajustar el seed de `shell.json` en `modules/desktop/caelestia.nix`
(`shellConfig`), sin tocar nada más:

1. **Figuritas de vuelta (#1)**: en `bar.workspaces`, poner
   `displayType = "shapes"` (hoy `"text"`). Dejar `label`, `occupiedLabel` y
   `activeLabel` en `""` como están.
2. **Transparencia ~66% (#4a)**: en `appearance.transparency`, `base = 0.34`
   (hoy 0.85) y `layers = 0.5` (hoy 0.4), con `enabled = true` intacto.
3. **Indicador fluido (#11a)**: en `bar.workspaces`, `activeTrail = true`
   (hoy `false`).
4. **Sin auto-lock (#13)**: en `general.idle.timeouts`, ELIMINAR la entrada de
   `lock` (timeout 300) y la de `suspendThenHibernate` (timeout 1800). Dejar
   SOLO la de `dpms off`/`dpms on` a 600. `lockBeforeSleep` y los flags de
   `inhibitWhenAudio` se quedan como están.
5. **Celsius siempre (#5)**: en `services`, agregar explícitos
   `useFahrenheit = false` y `useFahrenheitPerformance = false` (hoy se
   adivinan por locale). No toques `weatherLocation` ni `showWeather`.

No toques `cli.json`, ni la lista de acciones del launcher, ni los `paths`, ni
`utilities`. Las notificaciones nativas, los iconos reales y la animación de
workspace van en la ola 2.

## Definition of done

- `displayType == "shapes"`, `transparency.base == 0.34`,
  `transparency.layers == 0.5`, `activeTrail == true`.
- `services.useFahrenheit == false` y `services.useFahrenheitPerformance == false`.
- Ningún timeout de idle con `idleAction == "lock"` ni con
  `"suspendThenHibernate"`; queda el de `dpms off`.
- El verify command pasa.
- Solo `modules/desktop/caelestia.nix` fue modificado.

## Files you own

- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/hyprland-home.nix`,
  `modules/desktop/hyprland.nix`, `home/**`, `hosts/**`, `.workflow/**`
  (salvo leer).

## Read first

- `modules/desktop/caelestia.nix` (líneas 39–57 transparencia; 168–231
  workspaces; 76–98 idle).
- `.workflow/plan.md` → "Hallazgos" (#1, #4, #11, #13).
- Esquema del shell (read-only, para el enum): `BarWorkspaceDisplay = Shapes |
  Text` en
  `/nix/store/5m8m2319p0g98vqchapc9xqpzkf8xgkc-caelestia-shell-2.4.0/share/caelestia-shell/modules/bar/components/workspaces/Workspace.qml`.

## Verify command

```bash
nix flake check --no-build && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '.bar.workspaces.displayType=="shapes" and .appearance.transparency.base==0.34 and .appearance.transparency.layers==0.5 and .bar.workspaces.activeTrail==true and .services.useFahrenheit==false and .services.useFahrenheitPerformance==false and ([.general.idle.timeouts[].idleAction] | index("lock") | not) and ([.general.idle.timeouts[].idleAction] | index("suspendThenHibernate") | not)'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers. En español, estilo del repo.
- One logical change per commit. One commit per task.
- Commit ONLY your owned files.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave1-executor-1` — after each commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch.

## Report back

- Diff resumido (`git diff --stat`), salida del verify, y una nota de que el
  humano debe borrar `~/.config/caelestia/shell.json` y reconstruir para que el
  seed nuevo se aplique (el archivo del usuario manda tras la primera siembra).
