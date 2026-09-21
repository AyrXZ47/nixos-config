# Brief: Wave 8 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `flake.nix` (bloque que `substituteInPlace` inserta en
`modules/bar/components/OsIcon.qml`), dejar la bolita del logo **simétrica con
las pills** de la barra.

Hoy el círculo es `root.height` (~17 px) con color
`Colours.palette.m3surfaceContainerHigh`; el humano lo ve como "un signo de
admiración" porque es más chico que las pills y de otro color. Debe quedar:
- color `Colours.tPalette.m3surfaceContainer` (el mismo de la pill de
  `StatusIcons.qml`);
- **diámetro = grosor/ancho de las pills** = `Tokens.sizes.bar.innerWidth`
  (mismo token que usan `Workspaces.qml`/`StatusIcons.qml`), con `radius: width / 2`.

Bloque objetivo:
```qml
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: Math.round(Tokens.sizes.bar.innerWidth)
        implicitHeight: Math.round(Tokens.sizes.bar.innerWidth)
        radius: width / 2
        color: Colours.tPalette.m3surfaceContainer
    }
```
Ajusta si `Tokens.sizes.bar.innerWidth` no existe con ese nombre (mira cómo lo
usa `Workspaces.qml`). No hardcodees hex.

## Definition of done

- El `OsIcon.qml` construido usa `Colours.tPalette.m3surfaceContainer` y el
  círculo mide `Tokens.sizes.bar.innerWidth` (o el token real de las pills).
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `flake.nix` no es módulo.

## Read first

- `flake.nix` → el `substituteInPlace` de `OsIcon.qml`.
- `modules/bar/components/StatusIcons.qml` y `.../workspaces/Workspaces.qml`
  (token de ancho de las pills).
- `.workflow/plan.md` → Wave 8 T3.

## Verify command

```bash
nix flake check --no-build && S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-shell') && grep -q 'Colours.tPalette.m3surfaceContainer' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml" && grep -q 'Tokens.sizes.bar.innerWidth' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `fix(caelestia): bolita del logo simetrica con las pills`.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave8-executor-3`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y el token final usado para el diámetro.
