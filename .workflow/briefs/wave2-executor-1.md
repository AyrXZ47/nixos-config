# Brief: Wave 2 · Executor 1

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Arreglar **F1** de la auditoría de la ola 1 (bloqueante): el esquema
`cyberpunk` del overlay quedó en la ruta equivocada.

En `flake.nix`, dentro de `caelestiaCyberpunkSchemeOverlay`, la ruta debe ser
`schemes/cyberpunk/default/dark.txt` (con **subdirectorio de flavour**
`default`), NO `schemes/cyberpunk/dark.txt`. `caelestia-cli` exige
`schemes/<nombre>/<flavour>/<modo>.txt`; sin el subdirectorio,
`get_scheme_flavours("cyberpunk")` devuelve `[]` y `caelestia scheme set -n
cyberpunk` crashea con `IndexError`.

Cambios exactos:
- `mkdir -p "$scheme_dir/cyberpunk"` → `mkdir -p "$scheme_dir/cyberpunk/default"`
- `cat > "$scheme_dir/cyberpunk/dark.txt"` → `cat > "$scheme_dir/cyberpunk/default/dark.txt"`

El CONTENIDO de `dark.txt` no cambia (es el que ya está en `flake.nix`).

No toques nada más de `flake.nix`.

## Definition of done

- El overlay escribe `…/data/schemes/cyberpunk/default/dark.txt`.
- `caelestia scheme list` lista `cyberpunk` con flavour `default` y
  `primary == ff0066` (verify fuerte; NO basta un `ls`).
- El verify command pasa. Solo `flake.nix` modificado.

## Files you own

- `flake.nix`

## Files forbidden

- `flake.lock`, `modules/**`, `hosts/**`, `home/**`, `.workflow/**` (salvo leer).

## Read first

- `flake.nix` → `caelestiaCyberpunkSchemeOverlay` (busca `cyberpunk`).
- `.workflow/audits/wave1.md` → F1 (reproducción y fix propuesto).
- `.workflow/briefs/wave1-executor-3.md` → contenido del `dark.txt`.

## Verify command

```bash
nix flake check --no-build && P=$(nix build --no-link --print-out-paths '.#nixosConfigurations.pc.pkgs.caelestia-cli') && XDG_STATE_HOME=$(mktemp -d) XDG_CACHE_HOME=$(mktemp -d) "$P/bin/caelestia" scheme list | jq -e '.cyberpunk.default.primary == "ff0066"'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line
  (`fix:`, `feat:`, `chore:`, `docs:`, `refactor:`, `test:`, `perf:`,
  `style:`, `build:`, `ci:`, `revert:`, optional `(scope)`). Under ~72 chars.
  No AI attribution, no trailers. En español.
- One commit.
- Commit ONLY `flake.nix`.
- BRANCH ISOLATION (mandatory): commit and push ONLY to your own worktree
  branch — `git push origin wave2-executor-1` — after the commit. Never push
  to `main` or another branch; never merge, rebase, or fast-forward anyone
  else's branch.

## Report back

- Diff exacto de las 2 líneas, salida del verify, y confirmar que el `primary`
  del esquema es `ff0066`.
