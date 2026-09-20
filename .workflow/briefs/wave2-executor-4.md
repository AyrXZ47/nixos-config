# Brief: Wave 2 · Executor 4

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/caelestia.nix`, dos cosas:

1. **Apagar el toast nativo del cambio de layout (#2)**: en `utilities.toasts`,
   poner `kbLayoutChanged = false`. El `notify-send` real que lo sustituye lo
   agrega executor-2 en `switch-layout.sh` (otro archivo). No toques
   `capsLockChanged` ni `numLockChanged` (esos viven en C++ y se re-posicionan
   en la ola 3).
2. **Reproducibilidad de la paleta en todos los hosts**: agregar un activation
   idempotente que aplique el esquema `cyberpunk` si no está activo. En
   `home-manager.users.yovick`, junto a `home.activation.caelestiaSeedConfig`:
   ```nix
   home.activation.caelestiaCyberpunkScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
     if command -v caelestia >/dev/null 2>&1; then
       cur=$(caelestia scheme get -n 2>/dev/null || true)
       if [ "$cur" != "cyberpunk" ]; then
         caelestia scheme set -n cyberpunk >/dev/null 2>&1 || true
       fi
     fi
   '';
   ```
   `caelestia scheme get -n` imprime solo el nombre. El `|| true` final es
   deliberado: el primer boot puede no tener el shell/CLI listo y no debe
   romper el switch. `ponytail:` comenta que re-aplica la paleta fija a
   propósito (si el humano quisiera volver a esquemas dinámicos, se quita).

No toques `shellConfig` más allá de `kbLayoutChanged`, ni `cli.json`.

## Definition of done

- `utilities.toasts.kbLayoutChanged == false` en el seed.
- Existe `home.activation.caelestiaCyberpunkScheme` que aplica
  `caelestia scheme set -n cyberpunk` con guarda idempotente.
- El verify command pasa. Solo `modules/desktop/caelestia.nix` modificado.

## Files you own

- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/hyprland-home.nix`,
  `modules/apps/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Read first

- `modules/desktop/caelestia.nix`: `utilities.toasts` (~líneas 560–575),
  `home.activation.caelestiaSeedConfig` (~líneas 707–721).
- `.workflow/plan.md` → Wave 2 T4 y hallazgo de reproducibilidad.

## Verify command

```bash
nix flake check --no-build \
  && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '.utilities.toasts.kbLayoutChanged==false' \
  && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.activation.caelestiaCyberpunkScheme.data' | grep -q 'scheme set -n cyberpunk'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit por cambio lógico.
- Commit ONLY `modules/desktop/caelestia.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave2-executor-4` tras cada
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y confirmar que el activation no corre en
  caso de fallo del CLI (guarda `command -v`).
