# Brief: Wave 9 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/caelestia.nix`, dentro de `shellConfig.bar.workspaces`,
**eliminar la línea `workspaceIcons = [ ];`** (línea ~177). Es una opción que no
existe en el esquema de Caelestia (el nombre real es `windowIcons`), así que el
shell emite `WARN caelestia.settings: Unknown option "bar.workspaces.workspaceIcons"`
en cada arranque (hallazgo H1 de `.workflow/audits/wave8.md`).

Opcional (mismo archivo, mismo commit o uno aparte): en el bloque `windowIcons`
que ya existe (~línea 207), las entradas `hyprdev.*` y `^(org\.wezfurlong\.wezterm)$`
están **muertas**: las ventanas de `hyprdev`/`netrunner` hoy tienen clase `kitty`
(el título guarda `hyprdev-<runid>`), y el icono real lo resuelve el parche QML
`getAppIcon`. Se pueden borrar; **conserva la entrada `steam`** (esa clase sí
existe y no tiene icono por otra vía). Si dudas, deja las entradas muertas y solo
haz la eliminación de `workspaceIcons`.

NO toques `specialWorkspaceIcons` (esa opción sí es válida) ni el parche QML de
`flake.nix`.

## Definition of done

- El JSON de `shellJsonPath` ya no contiene la clave `workspaceIcons`.
- `windowIcons` sigue presente (no romper la config de iconos).
- El verify command pasa.

## Files you own

- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/apps/**`, `modules/desktop/hyprland*.nix`,
  `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo **system-side** (importado por `hosts/*/configuration.nix`): `lib` es el
  plano de nixpkgs, **no** existe `lib.hm.dag`. No se necesita activation.

## Read first

- `modules/desktop/caelestia.nix` → bloque `bar.workspaces` (~líneas 157–221).
- `.workflow/audits/wave8.md` §5 H1.
- Esquema real (grep de la shell): `Icons.qml` usa
  `GlobalConfig.bar.workspaces.windowIcons`; `workspaceIcons` no aparece en la
  fuente de `caelestia-shell`.

## Verify command

```bash
nix flake check --no-build && j="$(nix eval --raw .#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath)" && ! grep -q 'workspaceIcons' "$j" && grep -q 'windowIcons' "$j"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit lógico (si borras las entradas muertas, commit aparte).
- Commit ONLY `modules/desktop/caelestia.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave9-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y si quitaste las entradas muertas de `windowIcons`.
