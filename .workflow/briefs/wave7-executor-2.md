# Brief: Wave 7 · Executor 2

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Corregir la bolita de fondo del logo Nix en `flake.nix` (el bloque que
`substituteInPlace` inserta en `modules/bar/components/OsIcon.qml`). Hoy es:

```qml
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: root.height
        implicitHeight: root.height
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHigh
    }
```

El humano no lo quiso así: (a) el color debe ser el MISMO de la pill de los
status icons (internet/bluetooth/batería), que en
`modules/bar/components/StatusIcons.qml` es
`Colours.tPalette.m3surfaceContainer`; y (b) necesita **más padding**: el
snowflake apenas se ve. Cambia a:

```qml
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: Math.round(root.height * 1.6)
        implicitHeight: Math.round(root.height * 1.6)
        radius: width / 2
        color: Colours.tPalette.m3surfaceContainer
    }
```

Si `* 1.6` desborda la altura de la barra (míralo contra
`Tokens.sizes.bar.innerWidth`), usa `Math.round(Tokens.sizes.bar.innerWidth - Tokens.padding.small)`
como las pills de workspaces. `tPalette` aplica la capa de transparencia (mismo
look que la pill de status icons); no hardcodees `#50366a`.

## Definition of done

- El `OsIcon.qml` construido usa `Colours.tPalette.m3surfaceContainer` (no
  `m3surfaceContainerHigh`) y el círculo es más grande que el logo.
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `flake.nix` no es módulo.

## Read first

- `flake.nix` → el `substituteInPlace` de `OsIcon.qml` (busca
  `radius: width / 2`).
- `modules/bar/components/StatusIcons.qml` (color de la pill:
  `Colours.tPalette.m3surfaceContainer`).
- `.workflow/plan.md` → Wave 7 T2.

## Verify command

```bash
nix flake check --no-build && S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-shell') && grep -q 'Colours.tPalette.m3surfaceContainer' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml" && ! grep -q 'm3surfaceContainerHigh' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `fix(caelestia): color y padding de la bolita del logo Nix`.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave7-executor-2`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y el tamaño final del círculo (para que el humano
  valide).
