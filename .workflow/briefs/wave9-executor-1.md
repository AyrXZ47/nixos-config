# Brief: Wave 9 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `flake.nix`, dentro de `caelestiaDedupeOverlay` (`caelestia-shell.overrideAttrs`
→ `postPatch`), añadir sustituciones `substituteInPlace ... --replace-fail` para
que Caelestia trate el **UPS/nobreak** (`UPowerDeviceType.Ups`) como una batería
de laptop y muestre **watts** en el panel performance.

Contexto verificado (no re-descubrir): Quickshell define
`isLaptopBattery == (type == Battery && powerSupply)` en C++ (compilado); el
nobreak CPS LX1100G3 lo expone UPower como `Type=Ups`, así que el `BatteryTank`
y el icono de batería nunca se activan. Los archivos QML **no están parcheados**
hoy; su contenido en el store es idéntico al upstream. Watts =
`UPowerDevice.changeRate` (= UPower `EnergyRate`, positivo cargando, negativo
descargando).

Sustituciones (usar contextos únicos por archivo; `--replace-fail` ya falla
ruidosamente si upstream cambia):

1. `modules/dashboard/Performance.qml` — dos ocurrencias:
   - `!(UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery)`
     → `!((UPower.displayDevice.isLaptopBattery || UPower.displayDevice.type === UPowerDeviceType.Ups) && Config.dashboard.performance.showBattery)`
   - `active: UPower.displayDevice.isLaptopBattery && Config.dashboard.performance.showBattery`
     → `active: (UPower.displayDevice.isLaptopBattery || UPower.displayDevice.type === UPowerDeviceType.Ups) && Config.dashboard.performance.showBattery`
2. `modules/bar/components/status/BatteryStatus.qml`:
   `if (!UPower.displayDevice.isLaptopBattery) {` →
   `if (!(UPower.displayDevice.isLaptopBattery || UPower.displayDevice.type === UPowerDeviceType.Ups)) {`
3. `modules/bar/popouts/Battery.qml` — dos contextos únicos:
   - `text: UPower.displayDevice.isLaptopBattery ? qsTr("Remaining:` → prefijo con
     `(UPower.displayDevice.isLaptopBattery || UPower.displayDevice.type === UPowerDeviceType.Ups)`
   - `text: UPower.displayDevice.isLaptopBattery ? qsTr("Time` → igual
4. `modules/lock/Fetch.qml`:
   `const hasBatt = UPower.displayDevice.isLaptopBattery;` →
   `const hasBatt = UPower.displayDevice.isLaptopBattery || UPower.displayDevice.type === UPowerDeviceType.Ups;`
5. `modules/dashboard/performance/BatteryTank.qml`: insertar un `StyledText` de
   watts justo antes del `StyledText` del porcentaje. Reemplazar el bloque
   ```
               StyledText {
                   text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                   color: contents.accentColour
                   font: Tokens.font.headline.medium
               }
   ```
   por el mismo bloque **precedido** de:
   ```
               StyledText {
                   visible: Math.abs(UPower.displayDevice.changeRate) > 0.05
                   text: `${Math.abs(UPower.displayDevice.changeRate).toFixed(1)} W`
                   color: contents.subTextColour
                   font: Tokens.font.body.small
               }
   ```
   (respeta la indentación real del upstream, 12 espacios; si no coincide, `--replace-fail` falla → ajústala leyendo el archivo).

No inventes un helper QML ni toques `quickshell` (es C++ compilado).

## Definition of done

- `flake.nix` con las 5 sustituciones nuevas en `caelestiaDedupeOverlay` (ningún otro overlay tocado).
- `caelestia-shell` construido contiene `UPowerDeviceType.Ups` en `Performance.qml`,
  `BatteryStatus.qml`, `popouts/Battery.qml` y `lock/Fetch.qml`, y `changeRate` en
  `BatteryTank.qml`.
- El verify command pasa.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `home/**`, `hosts/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- No hace falta activation; el overlay se aplica en el build del paquete.
- `flake.lock` no se toca.

## Read first

- `flake.nix` → `caelestiaDedupeOverlay` (patrón `postPatch`/`substituteInPlace` existente).
- `.workflow/plan.md` → "Wave 9" y sus hallazgos de investigación.
- Fuente QML upstream (sin parchear):
  `/nix/store/xxdfj76gyjcgg7pyxjkzdm97zjz1kxq2-caelestia-shell-2.4.0/share/caelestia-shell/modules/...`
  (Performance.qml, bar/components/status/BatteryStatus.qml, bar/popouts/Battery.qml,
  lock/Fetch.qml, dashboard/performance/BatteryTank.qml).

## Verify command

```bash
nix flake check --no-build && out="$(nix build --no-link --print-out-paths .#nixosConfigurations.pc.pkgs.caelestia-shell)" && grep -q 'UPowerDeviceType.Ups' "$out/share/caelestia-shell/modules/dashboard/Performance.qml" && grep -q 'UPowerDeviceType.Ups' "$out/share/caelestia-shell/modules/bar/components/status/BatteryStatus.qml" && grep -q 'UPowerDeviceType.Ups' "$out/share/caelestia-shell/modules/bar/popouts/Battery.qml" && grep -q 'UPowerDeviceType.Ups' "$out/share/caelestia-shell/modules/lock/Fetch.qml" && grep -q 'changeRate' "$out/share/caelestia-shell/modules/dashboard/performance/BatteryTank.qml"
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por tarea.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave9-executor-1`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y cualquier sustitución que no matcheó (no la fuerces:
  repórtala).
