# Brief: Wave 4 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/desktop/caelestia.nix`, agregar una acción al launcher que restaure
el esquema `cyberpunk` (el humano lo cambió por accidente desde `>scheme` y
quedó en `dynamic`).

En `launcher.actions`, junto a las acciones existentes (busca `name = "Settings"`
o `name = "Clipboard"`), agrega:
```nix
{
  name = "Cyberpunk";
  icon = "palette";
  description = "Volver al esquema cyberpunk";
  command = [ "caelestia" "scheme" "set" "-n" "cyberpunk" ];
}
```
No dupliques la acción `Scheme` existente; solo agregas `Cyberpunk`. No toques
nada más.

## Definition of done

- La lista `launcher.actions` del seed incluye una acción `Cyberpunk` con el
  comando `caelestia scheme set -n cyberpunk`.
- El verify command pasa. Solo `modules/desktop/caelestia.nix` modificado.

## Files you own

- `modules/desktop/caelestia.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/hyprland-home.nix`,
  `modules/apps/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo **system-side**: recibe el `lib` plano de nixpkgs, sin `lib.hm.dag`
  (aquí no hay activations igual).

## Read first

- `modules/desktop/caelestia.nix` → `launcher.actions` (~líneas 365–475).
- `.workflow/plan.md` → Wave 4 T3 y el hallazgo del cambio de esquema.

## Verify command

```bash
nix flake check --no-build && nix build --no-link --print-out-paths '.#nixosConfigurations.pc.config.modules.desktop.caelestia.shellJsonPath' | xargs jq -e '[.launcher.actions[].name] | index("Cyberpunk") != null'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(caelestia): accion de launcher para volver al esquema cyberpunk`.
- Commit ONLY `modules/desktop/caelestia.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave4-executor-3` tras el
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff, salida del verify y recordatorio de que el humano debe borrar
  `~/.config/caelestia/shell.json` para adoptar el seed nuevo.
