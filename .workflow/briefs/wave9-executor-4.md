# Brief: Wave 9 · Executor 4

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

En `modules/apps/kitty.nix`, ampliar el `symbol_map` para cubrir el bloque
**`U+2B00-U+2BFF`**, que hoy queda fuera y hace que esos símbolos caigan a una
fuente monocroma.

Estado actual:
```
symbol_map = "U+1F300-U+1FAFF,U+2600-U+27BF,U+2190-U+21FF Noto Color Emoji";
```

Causa raíz verificada (no re-descubrir): `kitty --debug-font-fallback` confirma
que `symbol_map` ya carga `NotoColorEmoji`; el problema son los rangos no
mapeados. El prompt `p10k` usa `U+2B50` (estrella, bloque `U+2B00–U+2BFF`), que
no está en los rangos → cae a la fuente monocroma de fontconfig. Añade
`U+2B00-U+2BFF` a la lista (no quites los rangos existentes) y actualiza el
comentario para nombrar el bloque de la estrella.

No cambies nada más de `kitty.nix` en este commit.

Nota (no es tarea, para el reporte): el smear de kitty es del **caret de texto** y
por-ventana; al cambiar de split se pierde. Es una limitación de kitty upstream,
no configurable aquí.

## Definition of done

- `symbol_map` incluye `U+2B00-U+2BFF` además de los rangos actuales.
- El verify command pasa.

## Files you own

- `modules/apps/kitty.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `modules/apps/shell.nix`,
  `home/**`, `hosts/**`, `assets/**`, `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- Módulo home-side; no hay activations.

## Read first

- `modules/apps/kitty.nix` (bloque `settings.symbol_map` y su comentario).
- `kitty --help` / `kitty --debug-font-fallback`:
  `printf '\U00002B50\n' | kitty --debug-font-fallback --config "$HOME/.config/kitty/kitty.conf"`
  → debe listar `NotoColorEmoji` en "Symbol map fonts".

## Verify command

```bash
nix flake check --no-build && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.programs.kitty.settings.symbol_map' | grep -q 'U+2B00'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- Un commit (el tema del smear NO es código en este brief; solo repórtalo).
- Commit ONLY `modules/apps/kitty.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave9-executor-4`. Nunca a
  `main` ni a otra rama.

## Report back

- Diff, salida del verify y salida de `--debug-font-fallback` con `U+2B50`.
