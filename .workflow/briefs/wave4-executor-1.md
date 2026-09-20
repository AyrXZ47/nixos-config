# Brief: Wave 4 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Parches QML del shell en el overlay de `flake.nix` (extiende el `postPatch` de
`caelestiaDedupeOverlay`, o añade otro overlay). El ejecutor YA tiene un
`substituteInPlace` de `Workspace.qml` ahí; agrega los demás. **Un commit por
parche**; si alguno no se puede lograr, commitea los que sí y repórtalo.

Archivos fuente (read-only, en
`/nix/store/5m8m2319p0g98vqchapc9xqpzkf8xgkc-caelestia-shell-2.4.0/share/caelestia-shell/`):

1. **Logo NixOS azul** — `modules/bar/components/OsIcon.qml`: hoy
   `colour: Colours.palette.m3tertiary` (lo tiñe del color del esquema).
   Sustituir por `colour: "#5277c3"` (azul NixOS original).
2. **Notificaciones nativas (todo arriba-derecha)** — `modules/drawers/Panels.qml`:
   el bloque `Toasts.Toasts` está anclado abajo. Sustituir las dos anclas:
   - `anchors.bottom: sidebar.visible ? parent.bottom : utilities.top` →
     `anchors.top: notifications.bottom`
   - `anchors.right: sidebar.left` → `anchors.right: parent.right`
   (deja `anchors.margins`). Y en `modules/utilities/toasts/ToastItem.qml`,
   cambiar el color por defecto `return Colours.palette.m3surface;` →
   `return Colours.tPalette.m3surfaceContainer;` (mismo que
   `notifications/Notification.qml`). Caps lock / num lock son toasts: con esto
   ya salen en la zona y estilo de las notificaciones.
3. **Iconos reales de apps** — `modules/bar/components/workspaces/Workspace.qml`:
   dentro del `Repeater` de `windows`, hoy hay un `MaterialIcon` con
   `text: Icons.getAppCategoryIcon(...)`. Reemplazar ESE bloque (multilínea) por
   un `Image` con `source: Icons.getAppIcon(modelData.lastIpcObject.class, "")`
   y `fillMode: Image.PreserveAspectFit`, dimensionado como el icono actual
   (~`Math.round(Tokens.font.icon.small.pointSize * 1.33)` en
   `implicitWidth`/`implicitHeight`). Si `Icons.getAppIcon` no resuelve, el
   icono sale vacío; aceptable (los apps normales tienen `.desktop`).
4. **(Mejor esfuerzo) Animación del indicador** — portar el `workspace-bounce`
   de Wayle a `Workspace.qml`: que el icono/columna de `windows` haga un bounce
   (escala con overshoot) cuando el workspace pasa a `focused`. Es visual: si no
   queda bien, déjalo fuera y repórtalo.
5. **Filtro de dedupe**: el parche existente de dedupe filtra por
   `Icons.getAppCategoryIcon`; si cambias a iconos reales, el dedupe debe seguir
   funcionando (puede usar la misma clave `class`). No rompas el dedupe.

## Definition of done

- El `caelestia-shell` construido tiene `colour: "#5277c3"` en `OsIcon.qml`,
  `anchors.top: notifications.bottom` en `Panels.qml`, `getAppIcon` en
  `Workspace.qml`, y el color de toast nuevo.
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `flake.nix` no es un módulo; aquí no hay activations.

## Read first

- `flake.nix` → `caelestiaDedupeOverlay` (~líneas 424–460).
- Los QML fuente en el store de `caelestia-shell` (rutas de arriba).
- `.workflow/plan.md` → hallazgos de logo/notificaciones/#10/#11b y Wave 4 T1.

## Verify command

```bash
nix flake check --no-build && S=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-shell') && grep -q 'colour: "#5277c3"' "$S/share/caelestia-shell/modules/bar/components/OsIcon.qml" && grep -q 'anchors.top: notifications.bottom' "$S/share/caelestia-shell/modules/drawers/Panels.qml" && grep -q 'getAppIcon' "$S/share/caelestia-shell/modules/bar/components/workspaces/Workspace.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por parche (logo, notificaciones, iconos, animación).
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave4-executor-1` tras cada
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y qué parches quedaron fuera (si alguno) con
  el motivo. Nota: el humano debe validar visualmente.
