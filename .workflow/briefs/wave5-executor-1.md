# Brief: Wave 5 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `flake.nix` (dentro del `postPatch` de `caelestiaDedupeOverlay` que ya
parchea QML), apagar el recoloreo del indicador de workspace activo.

El problema: `modules/bar/components/workspaces/ActiveIndicator.qml` dibuja un
`Colouriser` (un `MultiEffect` con `colorization: 1`) sobre el contenido del
workspace activo para recolorearlo a `m3onPrimary`. Con iconos reales, el icono
del workspace activo se aplana a un color. Hay que mantener el redibujado del
contenido sobre la píldora, pero SIN recolorear.

Añade una sustitución más en el `postPatch`:
```
substituteInPlace modules/bar/components/workspaces/ActiveIndicator.qml \
  --replace-fail \
'        colorizationColor: Colours.palette.m3onPrimary' \
'        colorizationColor: Colours.palette.m3onPrimary
        colorization: 0
        brightness: 0'
```
(El string de reemplazo lleva saltos de línea reales e indentación de 8
espacios.) No toques nada más del archivo ni de `flake.nix`.

## Definition of done

- El `caelestia-shell` construido tiene `colorization: 0` en
  `ActiveIndicator.qml`.
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Read first

- `flake.nix` → `caelestiaDedupeOverlay` (~líneas 424–495; ya hay varias
  sustituciones QML).
- `ActiveIndicator.qml` en el store de `caelestia-shell`.
- `.workflow/plan.md` → hallazgo "Icono del workspace activo en gris".

## Verify command

```bash
nix flake check --no-build && S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-shell') && grep -q 'colorization: 0' "$S/share/caelestia-shell/modules/bar/components/workspaces/ActiveIndicator.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave5-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify. **Importante**: la auditoría debe cargar la shell
  (smoke test) porque esto toca QML; avisa en el reporte.
