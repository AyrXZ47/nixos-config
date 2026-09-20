# Brief: Wave 3 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Hacer transparente el fondo de Neovim con el tema `NeoCyberVim`, en
`modules/apps/neovim.nix`.

El plugin `NeoCyberVim` trae el tema con fondo opaco, lo que deja un "cuadro"
de fondo detrás del texto sobre la terminal translúcida. Expone
`require('NeoCyberVim').setup({ transparent = true })`, y LazyVim ya llama
`setup(opts)` por el `opts` del plugin.

Cambio: en `pluginsDir.".config/nvim/lua/plugins/theme.lua"`, donde hoy está
`opts = {}`, poner `opts = { transparent = true }`. Nada más.

Si al evaluar/arrancar ves que hace falta algo extra (p. ej. `vim.o.winblend`
o un `overrides`), NO lo inventes: repórtalo al planner. El objetivo es
exactamente "sin cuadro de fondo, solo el texto".

## Definition of done

- El plugin `NeoCyberVim` se configura con `transparent = true`.
- El verify command pasa. Solo `modules/apps/neovim.nix` modificado.

## Files you own

- `modules/apps/neovim.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `home/**`, `hosts/**`,
  `.workflow/**` (salvo leer).

## Notas de scope (Nix)

- `modules/apps/neovim.nix` es home-side; aquí no hay activations.

## Read first

- `modules/apps/neovim.nix`: plugin `theme.lua` (líneas ~7–17).
- `https://github.com/DonJulve/NeoCyberVim` (README: opción `transparent`).

## Verify command

```bash
nix flake check --no-build && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.file.".config/nvim/lua/plugins/theme.lua".text' | grep -q 'transparent = true'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `style(nvim): fondo transparente en NeoCyberVim`.
- Commit ONLY `modules/apps/neovim.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave3-executor-3` tras el
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff, salida del verify y confirmación de que `opts` quedó como
  `{ transparent = true }`.
