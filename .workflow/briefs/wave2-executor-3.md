# Brief: Wave 2 · Executor 3

> Copy this template per executor. The planner fills every section. The
> executor never touches a file it doesn't own, even "obviously". Deviations
> go back to the planner via the decision log in `.workflow/plan.md`.

## Task

Cambiar el tema de Neovim de `cyberneon` a **`NeoCyberVim`**
(https://github.com/DonJulve/NeoCyberVim), en `modules/apps/neovim.nix`.

Cambios exactos:
- `let theme = "cyberneon";` → `let theme = "NeoCyberVim";`
- En `pluginsDir.".config/nvim/lua/plugins/theme.lua"`, el plugin pasa de
  `"followLemmi/cyberneon.nvim"` a `"DonJulve/NeoCyberVim"` con
  `name = "NeoCyberVim"`, `lazy = false`, `priority = 1000` (o 20000) y
  `opts = {}`.
- No toques `install.colorscheme` ni `vim.cmd.colorscheme("${theme}")`: ya usan
  la variable `theme`, así que heredan el cambio.
- Elimina cualquier referencia restante a `cyberneon`.

El plugin expone el colorscheme `NeoCyberVim`
(`:colorscheme NeoCyberVim` / `require('NeoCyberVim')`); con `theme =
"NeoCyberVim"` LazyVim lo carga y lo activa.

## Definition of done

- `theme == "NeoCyberVim"` y el plugin es `DonJulve/NeoCyberVim`.
- Cero referencias a `cyberneon` en el archivo.
- El verify command pasa. Solo `modules/apps/neovim.nix` modificado.

## Files you own

- `modules/apps/neovim.nix`

## Files forbidden

- `flake.nix`, `flake.lock`, `modules/desktop/**`, `home/**`, `hosts/**`,
  `.workflow/**` (salvo leer).

## Read first

- `modules/apps/neovim.nix`: línea 4 (`theme`), 7–17 (plugin `theme.lua`),
  255 (`install.colorscheme`), 274 (`vim.cmd.colorscheme`).
- `.workflow/plan.md` → Wave 2 T3.

## Verify command

```bash
nix flake check --no-build && nix eval --raw '.#nixosConfigurations.pc.config.home-manager.users.yovick.home.file.".config/nvim/lua/plugins/theme.lua".text' | grep -q 'DonJulve/NeoCyberVim'
```

## Commit

- MANDATORY: conventional commits, short summary, imperative, one line. Under
  ~72 chars. No AI attribution, no trailers. En español.
- One commit: `feat(nvim): tema NeoCyberVim en vez de cyberneon`.
- Commit ONLY `modules/apps/neovim.nix`.
- BRANCH ISOLATION (mandatory): `git push origin wave2-executor-3` tras el
  commit. Nunca a `main` ni a otra rama.

## Report back

- Diff resumido, salida del verify, y si `opts` vacío basta o hizo falta algún
  ajuste (p. ej. `transparent`) — repórtalo, no lo inventes.
