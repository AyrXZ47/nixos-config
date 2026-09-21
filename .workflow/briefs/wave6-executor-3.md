# Brief: Wave 6 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `flake.nix` (dentro del `postPatch` de `caelestiaDedupeOverlay`), poner una
**bolita de relleno detrás del logo Nix** de la barra: el snowflake "casi no se
ve" y el humano quiere un círculo de fondo que lo haga resaltar.

En `modules/bar/components/OsIcon.qml` el logo se dibuja con:
```qml
    Loader {
        asynchronous: true
        anchors.centerIn: parent
        sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
    }
```
Inserta ANTES de ese `Loader` un círculo de fondo:
```qml
    Rectangle {
        anchors.centerIn: parent
        implicitWidth: root.height
        implicitHeight: root.height
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHigh
    }
```
(`Colours` ya está importado vía `qs.services`; `Rectangle` es de `QtQuick`.)
Usa `substituteInPlace ... --replace-fail` con el bloque del `Loader` como
ancla (multilínea con indentación exacta de 4 espacios). Ajusta el color si el
contraste con el azul `#5277c3` queda mal; no toques otras sustituciones.

## Definition of done

- El `caelestia-shell` construido tiene el `Rectangle` (círculo) delante del
  `Loader` en `OsIcon.qml`.
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `flake.nix` no es módulo.

## Read first

- `flake.nix` → `caelestiaDedupeOverlay` (busca `OsIcon.qml`).
- `OsIcon.qml` en el store de `caelestia-shell`.
- `.workflow/plan.md` → Wave 6 T3.

## Verify command

```bash
nix flake check --no-build && S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-shell') && grep -q 'radius: width / 2' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(caelestia): fondo circular detras del logo Nix del bar`.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave6-executor-3`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y aviso de que la auditoría debe cargar la shell
  (smoke test; toca QML).
